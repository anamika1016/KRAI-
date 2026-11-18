class CcDashboardReport
  HEADERS = ["JJ Name", "CC Target", "CC Achievement", "Total OPG JJ Target", "Total OPG JJ Achievement",
    "OPG Training", "General Training/Meeting", "Input Demo INM", "Input Demo PM", "FFS Exposure"].freeze

  def initialize(targets:, vrps:, month:)
    @targets = targets
    @vrps = vrps
    @month = month
  end

  def rows
    @rows ||= begin
      # Calculate each month separately: the shared report deduplicates villages,
      # so passing all months together would lose recurring monthly targets.
      details = @targets.group_by { |target| target.month_name.to_s.strip.downcase }.flat_map do |month, targets|
        DemonstrationMethodReport.new(targets: targets, month: month).rows
      end.group_by { |row| row["vrp_id"].to_s }
      targets_by_jj = @targets.group_by(&:vrp_id)
      @vrps.map do |jj|
        entries = details.fetch(jj.id.to_s, [])
        total = ->(key) { entries.sum { |entry| entry[key].to_i } }
        opg = targets_by_jj.fetch(jj.id, [])
          .group_by { |target| [target.month_name, target.village_id] }
          .sum { |_key, targets| targets.map { |target| target.opg_training_target.to_i }.max.to_i }
        {
          "JJ Name" => jj.name, "Total OPG" => opg,
          "CC Target" => total.call("CC Target"),
          "Total OPG JJ Target" => opg,
          "Total OPG JJ Achievement" => total.call("OPG Achievement"),
          "CC Achievement" => total.call("CC Achievement"),
          "OPG Training" => "#{opg} / #{total.call('OPG Achievement')}",
          "General Training/Meeting" => "#{total.call('General Training/Meeting Target')} / #{total.call('General Training/Meeting Achievement')}",
          "Input Demo INM" => "#{total.call('Input Demo INM Target')} / #{total.call('Input Demo INM Achievement')}",
          "Input Demo PM" => "#{total.call('Input Demo PM Target')} / #{total.call('Input Demo PM Achievement')}",
          "FFS Exposure" => "#{total.call('FFS Target')} / #{total.call('FFS Achievement')}"
        }
      end
    end
  end

  def target
    rows.sum { |row| row["CC Target"] }
  end

  def achievement
    rows.sum { |row| row["CC Achievement"] }
  end

  def jj_target
    # OPG is an assigned village target, not the sum of training-method
    # targets. Use the dashboard's FCO/village deduplication so a village
    # mapped to multiple JJs (or months in All Months) is not counted twice.
    @jj_target ||= DemonstrationMethodReport.new(targets: @targets, month: @month)
      .summary.sum { |row| row["OPG Target"].to_i }
  end

  def jj_achievement
    rows.sum { |row| row["Total OPG JJ Achievement"] }
  end
end
