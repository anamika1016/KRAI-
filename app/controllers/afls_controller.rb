require "csv"
require "fileutils"
require "securerandom"

class AflsController < ApplicationController
  before_action :set_afl, only: [:destroy]

  PAGE_SIZE = 15
  REPORT_DIR = Rails.root.join("tmp", "afl_import_reports")

  def index
    @query = params[:q].to_s.strip
    @fco_filter = params[:fco_id].presence || params[:fcoc].presence
    @to_filter = params[:to_name].presence || params[:to].presence
    @ics_filter = params[:ics].presence || params[:ics_id].presence
    @month_filter = params[:month].presence
    @main_activity_filter = params[:main_activity].presence
    @sub_activity_filter = params[:sub_activity].presence
    @column_filters = Afl.column_filter_values(params[:col])
    @column_filter_operators = Afl.column_filter_values(params[:colop])
      .select { |_column, operator| Afl::COLUMN_FILTER_OPERATORS.include?(operator) }
    @summary_mode = params[:summary_mode].presence_in(%w[ics village farmer])
    @page = [params[:page].to_i, 1].max
    @page_size = PAGE_SIZE

    scoped_afls = Afl.search(@query).merge(Afl.column_filtered(@column_filters, @column_filter_operators))
    scoped_afls = apply_afl_filters(scoped_afls)
    scoped_afls = grouped_afl_scope(scoped_afls) if @summary_mode.present?
    @total_afls = @summary_mode.present? ? scoped_afls.length : scoped_afls.count
    @total_pages = [(@total_afls.to_f / @page_size).ceil, 1].max
    @page = [@page, @total_pages].min

    @afls = if @summary_mode.present?
      scoped_afls.slice((@page - 1) * @page_size, @page_size) || []
    else
      scoped_afls
        .select(Afl::LIST_COLUMNS)
        .order(Arel.sql("CASE WHEN farmer_name IS NULL OR farmer_name = '' THEN 1 ELSE 0 END ASC, farmer_name ASC, id ASC"))
        .offset((@page - 1) * @page_size)
        .limit(@page_size)
    end

    respond_to do |format|
      format.html
      format.xlsx do
        send_xlsx(
          headers: afl_export_headers,
          rows: afl_export_rows(scoped_afls),
          filename: "afl-#{@summary_mode.presence || "list"}-#{Time.current.strftime("%Y%m%d%H%M")}.xlsx",
          sheet_name: "AFL List"
        )
      end
    end
  end

  def import
    result = Afl.import(params[:file])
    total_rows = result[:imported] + result[:skipped].size
    notice = "#{result[:imported]} target mapping records uploaded successfully out of #{total_rows} Excel rows."
    notice += " #{result[:skipped].size} rows skipped." if result[:skipped].any?

    if result[:skipped].any?
      report_id = write_import_report(result[:skipped])
      redirect_to afls_path(report_id: report_id), notice: notice, alert: skipped_summary(result[:skipped])
    else
      redirect_to afls_path, notice: notice
    end
  rescue ArgumentError => e
    redirect_to afls_path, alert: e.message
  rescue CSV::MalformedCSVError => e
    redirect_to afls_path, alert: "Could not read this CSV file: #{e.message}. Please re-save it and try again."
  end

  def import_report
    report_path = REPORT_DIR.join("#{params[:id].to_s.gsub(/[^a-zA-Z0-9_-]/, "")}.csv")
    unless report_path.file?
      redirect_to afls_path, alert: "Target mapping import skipped report not found."
      return
    end

    send_file report_path, filename: "afl_skipped_rows_#{params[:id]}.csv", type: "text/csv"
  end

  def destroy
    @afl.destroy
    redirect_to afls_path(q: params[:q].presence, page: params[:page].presence), notice: "Target mapping record deleted successfully."
  end

  def bulk_destroy
    query = params[:q].to_s.strip
    @fco_filter = params[:fco_id].presence || params[:fcoc].presence
    @to_filter = params[:to_name].presence || params[:to].presence
    @ics_filter = params[:ics].presence || params[:ics_id].presence
    @month_filter = params[:month].presence
    @main_activity_filter = params[:main_activity].presence
    @sub_activity_filter = params[:sub_activity].presence
    # Deleting "everything matching" must mean what the screen is showing, so
    # the heading filters narrow this the same way they narrow the list.
    scoped_afls = apply_afl_filters(Afl.search(query).merge(Afl.column_filtered(params[:col], params[:colop])))
    destroyed_count = scoped_afls.count

    scoped_afls.find_each(&:destroy)

    redirect_to afls_path(q: query.presence), notice: "#{destroyed_count} target mapping record(s) deleted successfully."
  end

  private

  def set_afl
    @afl = Afl.find(params[:id])
  end

  def apply_afl_filters(scope)
    policy = ModulesController.new
    policy.request = request
    policy.instance_variable_set(:@current_app_user, current_app_user)
    scope = scope.merge(policy.send(:dashboard_visible_farmer_scope))
    @fco_filter = FcoDirectory.ids if @fco_filter.to_s.strip.casecmp("All FCO").zero?
    if @fco_filter.present?
      fco_values = afl_fco_filter_values(@fco_filter)
      scope = scope.where(
        "LOWER(BTRIM(COALESCE(fco, ''))) IN (:fco_values) OR LOWER(BTRIM(COALESCE(fco_id, ''))) IN (:fco_values)",
        fco_values: fco_values
      )
    end

    if @ics_filter.present?
      ics_values = afl_filter_values(@ics_filter)
      scope = scope.where(
        "LOWER(BTRIM(COALESCE(ics_name, ''))) IN (:ics_values) OR LOWER(BTRIM(COALESCE(ics_id, ''))) IN (:ics_values)",
        ics_values: ics_values
      )
    end

    # TO filter: same Condition 1/2 rule as the Dashboard Summary cards this
    # list is a drill-down for -- an ICS TO MAPPING match narrows to that TO's
    # ICS, no mapping yet leaves the FCO scope above untouched. Falls back to
    # the logged-in user's own Sub Office Name (Agronomist/CC auto-fill) when
    # no TO was explicitly chosen, same as the dashboard cards.
    effective_to_filter = @to_filter.presence || policy.send(:dashboard_user_sub_office_to_value)
    if effective_to_filter.present?
      to_ics_ids = policy.send(:dashboard_to_mapped_ics_ids, @fco_filter, effective_to_filter)
      if to_ics_ids.present?
        scope = scope.where("LOWER(BTRIM(COALESCE(ics_id, ''))) IN (:to_ics_ids)", to_ics_ids: to_ics_ids)
      end
    end

    if (village_filter = params[:village_id].presence)
      village_values = afl_filter_values(village_filter)
      scope = scope.where(
        "LOWER(BTRIM(COALESCE(village_name, ''))) IN (:v) OR LOWER(BTRIM(COALESCE(village_id, ''))) IN (:v)",
        v: village_values
      )
    end

    if @summary_mode.blank?
      target_farmer_ids = target_mapping_farmer_ids_for_filters
      scope = scope.where(id: target_farmer_ids) if target_farmer_ids
    end

    scope
  end

  def target_mapping_farmer_ids_for_filters
    return nil if @month_filter.blank? && @main_activity_filter.blank? && @sub_activity_filter.blank?

    target_scope = TargetMapping.all
    if @fco_filter.present?
      fco_values = afl_fco_filter_values(@fco_filter)
      target_scope = target_scope.where(
        "LOWER(BTRIM(COALESCE(fco_name, ''))) IN (:fco_values) OR LOWER(BTRIM(COALESCE(fco_id, ''))) IN (:fco_values)",
        fco_values: fco_values
      )
    end
    if @ics_filter.present?
      ics_values = afl_filter_values(@ics_filter)
      target_scope = target_scope.where(
        "LOWER(BTRIM(COALESCE(ics_name, ''))) IN (:ics_values) OR LOWER(BTRIM(COALESCE(ics_id, ''))) IN (:ics_values)",
        ics_values: ics_values
      )
    end
    target_scope = target_scope.where("LOWER(BTRIM(month_name)) = ?", @month_filter.to_s.strip.downcase) if @month_filter.present?
    target_scope = target_scope.where("LOWER(BTRIM(main_activity_name)) = ?", @main_activity_filter.to_s.strip.downcase) if @main_activity_filter.present?
    target_scope = target_scope.where("LOWER(BTRIM(activity_name)) = ?", @sub_activity_filter.to_s.strip.downcase) if @sub_activity_filter.present?

    target_scope.pluck(:afl_ids).flat_map { |ids| Array(ids) }.map(&:to_s).reject(&:blank?).uniq
  end

  def grouped_afl_scope(scope)
    case @summary_mode
    when "ics"
      # This must mirror `dashboard_total_afl_ics_count`: one row per ICS ID.
      # Imported AFL data may repeat the same ICS under several FPO IDs/names;
      # grouping by FPO made the drill-down show hundreds of rows for a card
      # that correctly showed only one ICS.
      scope.where.not(ics_id: [nil, ""])
        .group(Arel.sql("LOWER(BTRIM(ics_id))"))
        .order(Arel.sql("LOWER(BTRIM(ics_id))"))
        .pluck(
          Arel.sql("MIN(fco_id)"), Arel.sql("MIN(fco)"), Arel.sql("MIN(fpo_id)"), Arel.sql("MIN(fpo_name)"),
          Arel.sql("MIN(ics_id)"), Arel.sql("MIN(ics_name)"), Arel.sql("COUNT(DISTINCT id)")
        )
        .map { |fco_id, fco, fpo_id, fpo_name, ics_id, ics_name, farmer_count| grouped_afl_row(fco_id, fco, fpo_id, fpo_name, ics_id, ics_name, farmer_count) }
    when "village"
      # Same parity rule for the Village card: village ID, not FPO/ICS metadata,
      # determines one list row.
      scope.where.not(village_id: [nil, ""])
        .group(Arel.sql("LOWER(BTRIM(village_id))"))
        .order(Arel.sql("LOWER(BTRIM(village_id))"))
        .pluck(
          Arel.sql("MIN(fco_id)"), Arel.sql("MIN(fco)"), Arel.sql("MIN(fpo_id)"), Arel.sql("MIN(fpo_name)"),
          Arel.sql("MIN(ics_id)"), Arel.sql("MIN(ics_name)"), Arel.sql("MIN(village_id)"), Arel.sql("MIN(village_name)"),
          Arel.sql("COUNT(DISTINCT id)")
        )
        .map do |fco_id, fco, fpo_id, fpo_name, ics_id, ics_name, village_id, village_name, farmer_count|
          grouped_afl_row(fco_id, fco, fpo_id, fpo_name, ics_id, ics_name, farmer_count).merge(village_id: village_id, village_name: village_name)
        end
    when "farmer"
      # The dashboard "Total Farmer Count" card counts every AFL row with a
      # non-blank tracenet_no (COUNT(NULLIF(BTRIM(tracenet_no), ''))) — duplicates
      # included. So the drill-down list must show one row per such record and
      # must NOT group/deduplicate, otherwise the list total under-counts the
      # card (e.g. 11,456 vs 11,742). Use the same non-blank-tracenet predicate.
      scope.where("NULLIF(BTRIM(tracenet_no), '') IS NOT NULL")
        .order(:fco_id, :ics_id, :tracenet_no)
        .pluck(:fco_id, :fco, :fpo_id, :fpo_name, :ics_id, :ics_name, :village_id, :village_name, :tracenet_no, :farmer_name, :father_name)
        .map { |fco_id, fco, fpo_id, fpo_name, ics_id, ics_name, village_id, village_name, tracenet_no, farmer_name, father_name| { fco_id: fco_id, fco: fco, fpo_id: fpo_id, fpo_name: fpo_name, ics_id: ics_id, ics_name: ics_name, village_id: village_id, village_name: village_name, tracenet_no: tracenet_no, farmer_name: farmer_name, father_name: father_name } }
    else
      scope
    end
  end

  def grouped_afl_row(fco_id, fco, fpo_id, fpo_name, ics_id, ics_name, farmer_count)
    {
      fco_id: FcoDirectory.id_for(fco_id).presence || fco_id,
      fco: FcoDirectory.display_name_for(fco_id).presence || fco,
      fpo_id: fpo_id,
      fpo_name: fpo_name,
      ics_id: ics_id,
      ics_name: ics_name,
      farmer_count: farmer_count
    }
  end

  # The FCO filter arrives as whatever the dashboard dropdown held, which may be
  # an Office Setup office that reports on another FCO's rows ("Direct to HO" ->
  # 1095 Direct to HO). The summary card already counts through those aliases, so
  # the View List behind it has to match on them too or the two disagree. Only
  # the FCO filter resolves aliases -- ICS and village names keep plain matching.
  def afl_fco_filter_values(value)
    Array(value).flatten.flat_map do |entry|
      afl_filter_values(entry) + FcoDirectory.aliases_for(entry).map { |alias_value| alias_value.to_s.downcase }
    end.reject(&:blank?).uniq
  end

  def afl_filter_values(value)
    Array(value).flatten.flat_map do |entry|
      text = entry.to_s.strip
      next [] if text.blank?

      short_name = text.sub(/\Afco\s*-\s*c\s+/i, "").strip
      [text, short_name]
    end.map(&:downcase).reject(&:blank?).uniq
  end

  def afl_export_headers
    case @summary_mode
    when "ics"
      ["FCO ID", "FCO Name", "FPO ID", "FPO Name", "ICS ID", "ICS Name", "Farmer Count"]
    when "village"
      ["FCO ID", "FCO Name", "FPO ID", "FPO Name", "ICS ID", "ICS Name", "Village ID", "Village Name", "Farmer Count"]
    when "farmer"
      ["FCO ID", "FCO Name", "FPO ID", "FPO Name", "ICS ID", "ICS Name", "Village ID", "Village Name", "Tracenet No", "Farmer Name", "Father Name"]
    else
      ["ID", "Farm ID", "FCO ID", "FCO", "FPO ID", "FPO Name", "ICS ID", "ICS Name", "Village ID", "Village Name", "Farmer Name", "Father Name", "Tracenet No", "Total Farm Area", "Purchase Quantity Amount", "Estimate Quantity", "Purchase Quantity", "Purchase Date", "Mobile No", "Purchase Product", "Status"]
    end
  end

  def afl_export_rows(rows)
    case @summary_mode
    when "ics"
      rows.map { |row| [row[:fco_id], row[:fco], row[:fpo_id], row[:fpo_name], row[:ics_id], row[:ics_name], row[:farmer_count].to_i] }
    when "village"
      rows.map { |row| [row[:fco_id], row[:fco], row[:fpo_id], row[:fpo_name], row[:ics_id], row[:ics_name], row[:village_id], row[:village_name], row[:farmer_count].to_i] }
    when "farmer"
      rows.map { |row| [row[:fco_id], row[:fco], row[:fpo_id], row[:fpo_name], row[:ics_id], row[:ics_name], row[:village_id], row[:village_name], row[:tracenet_no], row[:farmer_name], row[:father_name]] }
    else
      rows.select(Afl::LIST_COLUMNS).order(:id).map do |afl|
        [
          afl.id, afl.farm_id, afl.fco_id, afl.fco, afl.fpo_id, afl.fpo_name, afl.ics_id, afl.ics_name,
          afl.village_id, afl.village_name, afl.farmer_name, afl.father_name, afl.tracenet_no,
          afl.total_farm_area, afl.purchase_quantity_amount, afl.estimate_quantity, afl.purchase_quantity,
          afl.purchase_date, afl.mobile_no, afl.purchase_product, afl.status
        ]
      end
    end
  end

  def write_import_report(skipped_rows)
    FileUtils.mkdir_p(REPORT_DIR)
    report_id = SecureRandom.hex(8)
    report_path = REPORT_DIR.join("#{report_id}.csv")

    CSV.open(report_path, "w") do |csv|
      csv << ["Row", "Reason", "Farm_ID", "Tracenet_No", "Longitude", "Lattitude", "Khasara_NO", "Farmer_Name", "Father_Name", "Village_ID", "Village_Name"]
      skipped_rows.each do |skipped_row|
        row = normalize_skipped_row(skipped_row)
        csv << [
          row[:row],
          row[:reason],
          row[:farm_id],
          row[:tracenet_no],
          row[:longitude],
          row[:lattitude],
          row[:khasara_no],
          row[:farmer_name],
          row[:father_name],
          row[:village_id],
          row[:village_name]
        ]
      end
    end

    report_id
  end

  def skipped_summary(skipped_rows)
    reason_counts = skipped_rows
      .map { |skipped_row| normalize_skipped_row(skipped_row)[:reason] }
      .tally
      .map { |reason, count| "#{count} #{reason}" }
      .join(" | ")

    "Skipped reason summary: #{reason_counts}"
  end

  def normalize_skipped_row(skipped_row)
    return skipped_row.symbolize_keys if skipped_row.respond_to?(:symbolize_keys)

    message = skipped_row.to_s
    {
      row: message[/\ARow (\d+):/, 1],
      reason: message.sub(/\ARow \d+:\s*/, "")
    }
  end
end
