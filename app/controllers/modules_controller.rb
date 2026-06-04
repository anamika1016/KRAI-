require "fileutils"
require "securerandom"
require "csv"

class ModulesController < ApplicationController
  helper_method :module_field_options, :module_select_field?, :static_field_options, :role_management_mappings,
                :access_control_role_mappings, :access_control_field_options,
                :location_hierarchy_mappings, :office_category_mappings

  DASHBOARD_CARDS = [
    ["Total VRP", "0", "Registered field resources"],
    ["Active VRP", "0", "Currently active"],
    ["Pending Approvals", "0", "Waiting for action"],
    ["Approved Bills", "0", "Cleared bill records"],
    ["Pending Payments", "0", "Finance queue"],
    ["Weekly Target Status", "0%", "Completion ratio"],
    ["Activity Progress", "0%", "Field activity progress"],
    ["Training Status", "0%", "Training completion"]
  ].freeze

  DASHBOARD_REPORTS = [
    "Monthly Bill Summary",
    "Weekly Activity Progress",
    "Approval Status Summary",
    "Payment Status Report"
  ].freeze

  MODULES = {
    "state-master" => {
      title: "State Master",
      group: "LG Master",
      purpose: "Location hierarchy maintain karne ke liye.",
      fields: ["State Name", "State Code", "Status"]
    },
    "district-master" => {
      title: "District Master",
      group: "LG Master",
      purpose: "District level location master maintain karne ke liye.",
      fields: ["State", "District Name", "District Code", "Status"]
    },
    "block-master" => {
      title: "Block Master",
      group: "LG Master",
      purpose: "Block level location master maintain karne ke liye.",
      fields: ["State", "District", "Block Name", "Block Code", "Status"]
    },
    "gram-panchayat-master" => {
      title: "Gram Panchayat Master",
      group: "LG Master",
      purpose: "Gram Panchayat master maintain karne ke liye.",
      fields: ["State", "District", "Block", "Gram Panchayat Name", "GP Code", "Status"]
    },
    "village-master" => {
      title: "Village Master",
      group: "LG Master",
      purpose: "Village master maintain karne ke liye.",
      fields: ["State", "District", "Block", "Gram Panchayat", "Village Name", "Village Code", "Status"]
    },
    "lg-directory-list" => {
      title: "All List",
      group: "LG Directory",
      purpose: "State, District, Block, GP, Village ek sath maintain karne ke liye.",
      fields: ["State", "State Code", "District", "Block", "Gram Panchayat", "GP Code", "Village", "Village Code", "Status"]
    },
    "stakeholder-master" => {
      title: "Stakeholder Master",
      group: "Masters",
      purpose: "Stakeholder name aur logo maintain karna.",
      fields: ["Stakeholder Name in English", "Stakeholder Name in Hindi", "Logo Upload", "Status"]
    },
    "stakeholder-profile" => {
      title: "Stakeholder Profile",
      group: "Masters",
      purpose: "Stakeholder profile aur logo details maintain karna.",
      fields: ["Stakeholder Name", "Profile Name", "CIN", "Phone Number", "Email", "Website", "Full Address", "Logo Upload", "Status"]
    },
    "training-material" => {
      title: "Training Material Master",
      group: "Masters",
      purpose: "Training documents/videos upload karna.",
      fields: ["Material Title", "VRP Type", "File Upload", "Upload Date", "Status"]
    },
    "bank-master" => {
      title: "Bank Master",
      group: "Masters",
      purpose: "Bank details maintain karna.",
      fields: ["Bank Name", "Branch Name", "IFSC Code", "Status"]
    },
    "month-master" => {
      title: "Month Master",
      group: "Masters",
      purpose: "Financial months maintain karna.",
      fields: ["Month Name", "Financial Year"]
    },
    "project-master" => {
      title: "Project Master",
      group: "Masters",
      purpose: "Project details maintain karna.",
      fields: ["Project Name", "Status"]
    },
    "activity-master" => {
      title: "Activity Master",
      group: "Activity Master",
      purpose: "All activities maintain karna.",
      fields: ["Activity Name", "Status"]
    },
    "office-category-add" => {
      title: "Office Category Add",
      group: "Office Management",
      purpose: "Office category aur office level maintain karne ke liye.",
      fields: ["Stakeholder Category", "Category Name", "Office Level", "Status"]
    },
    "add-vrp-type" => {
      title: "Add VRP Type",
      group: "Activity Setup",
      purpose: "VRP type add karne ke liye.",
      fields: ["VRP Type Name", "Status"]
    },
    "add-activity-group" => {
      title: "Main Activity",
      group: "Activity Setup",
      purpose: "Main activity add karne ke liye.",
      fields: ["Main Activity Name", "Status"]
    },
    "activity-group-list" => {
      title: "Main Activity List",
      group: "Activity Setup",
      purpose: "Saved main activities dekhne ke liye.",
      fields: ["Main Activity Name", "Status"]
    },
    "add-vrp-activity" => {
      title: "Sub Activity",
      group: "Activity Setup",
      purpose: "Sub activity add karne ke liye.",
      fields: ["Main Activity", "Sub Activity Name", "Unit", "Status"]
    },
    "vrp-activity-list" => {
      title: "Sub Activity List",
      group: "Activity Setup",
      purpose: "Saved sub activities dekhne ke liye.",
      fields: ["Main Activity", "Sub Activity Name", "Unit", "Status"]
    },
    "task-completion-indicator" => {
      title: "Task Completion Indicator",
      group: "Activity Setup",
      purpose: "Activity completion indicators maintain karne ke liye.",
      fields: ["Select Activity", "TCI Name", "Select Mandatory", "Status"]
    },
    "task-completion-indicator-list" => {
      title: "Task Completion Indicator List",
      group: "Activity Setup",
      purpose: "Saved task completion indicators dekhne ke liye.",
      fields: ["Select Activity", "TCI Name", "Select Mandatory", "Status"]
    },
    "task-indicator-master" => {
      title: "Task Indicator Master",
      group: "Task Indicator Master",
      purpose: "Activity ke behalf me tasks define karna.",
      fields: ["Activity", "Task Indicator Name", "Unit", "Status"]
    },
    "approval-master" => {
      title: "VRP Approval Form",
      group: "VRP Registration",
      purpose: "VRP registration aur bill approval ke approver maintain karne ke liye.",
      fields: ["Module Name", "Stakeholder Name", "Office", "Approval Level", "Approver (Approved By)", "Status", "VRP Name"]
    },
    "approval-list" => {
      title: "VRP Approval List",
      group: "VRP Registration",
      purpose: "Saved approval mappings dekhne ke liye.",
      fields: ["Module Name", "Stakeholder Name", "Office", "Approval Level", "Approver (Approved By)", "Status", "VRP Name"]
    },
    "ics-master" => {
      title: "ICS Master",
      group: "Masters",
      purpose: "ICS details maintain karne ke liye.",
      fields: ["ICS Name", "Status"]
    },
    "vrp-registration-list" => {
      title: "VRP Registration List",
      group: "VRP Registration",
      purpose: "Registered VRP records manage karne ke liye.",
      fields: ["Search", "Filter", "Export Excel/PDF", "Active/Inactive Status"],
      features: ["View VRP", "Edit VRP", "Delete VRP", "Approval Status", "Document Download"]
    },
    "vrp-bill-add" => {
      title: "Add VRP Bill",
      group: "VRP Bills",
      purpose: "VRP bill submit karne ke liye.",
      fields: ["Select VRP", "Select Financial Year", "Select Bill Month", "Select ICS", "Select Main Activity", "Grand Total", "Status"]
    },
    "vrp-bill-list" => {
      title: "VRP Bill List",
      group: "VRP Bills",
      purpose: "Bills aur payment status track karne ke liye.",
      fields: ["Select VRP", "Select Financial Year", "Select Bill Month", "Select ICS", "Select Main Activity", "Grand Total", "Status"]
    },
    "weekly-target-add" => {
      title: "Add Weekly Target",
      group: "Weekly Target Allocation",
      purpose: "VRP wise weekly target assign karne ke liye.",
      fields: ["Financial Year", "Month", "Week", "Select VRP", "Select VRP Type", "Select ICS", "State", "District", "Block", "Gram Panchayat", "Village", "Activity", "Task Indicator", "Target Quantity", "Unit", "Start Date", "End Date", "Priority", "Remarks", "Assigned By", "Assigned Date", "Status"]
    },
    "weekly-target-list" => {
      title: "Weekly Target List",
      group: "Weekly Target Allocation",
      purpose: "Weekly target records manage karne ke liye.",
      fields: ["View Target", "Edit Target", "Delete Target", "Approval Status", "Completion Status", "Export Excel/PDF"]
    },
    "weekly-progress-report" => {
      title: "Weekly Progress Report",
      group: "Weekly Target Allocation",
      purpose: "Target progress report dekhne ke liye.",
      fields: ["Completed Target", "Pending Target", "Overdue Target", "VRP Wise Progress", "Activity Wise Progress"]
    },
    "monthly-bill-summary" => {
      title: "Monthly Bill Summary",
      group: "Dashboard Reports",
      purpose: "Month wise bill amount, approval, aur payment summary.",
      fields: ["Financial Year", "Month", "Total Bills", "Approved Bills", "Pending Bills", "Paid Amount", "Status"]
    },
    "weekly-activity-progress" => {
      title: "Weekly Activity Progress",
      group: "Dashboard Reports",
      purpose: "Week wise activity aur target progress dekhne ke liye.",
      fields: ["Week", "VRP", "Activity", "Target", "Completed", "Pending", "Status"]
    },
    "approval-status-summary" => {
      title: "Approval Status Summary",
      group: "Dashboard Reports",
      purpose: "Module wise approval pending/approved/rejected status.",
      fields: ["Module Name", "L1 Status", "L2 Status", "Finance Status", "Pending With", "Status"]
    },
    "payment-status-report" => {
      title: "Payment Status Report",
      group: "Dashboard Reports",
      purpose: "Bill payment status aur finance queue report.",
      fields: ["VRP", "Bill Month", "Approved Amount", "Payment Status", "Transaction ID", "Payment Date"]
    },
    "new-user" => {
      title: "New User",
      group: "User Register",
      purpose: "System login user create karne ke liye.",
      fields: ["Stakeholder Category", "Stakeholder Role", "Role", "User Management Role", "Person Type", "State", "District", "Block", "Gram Panchayat", "Village", "Office", "Full Address", "Pincode", "First Name", "Last Name", "Gender", "Email", "Password", "Confirmed Password", "User Name", "Mobile No", "User Type", "Status"]
    },
    "all-user" => {
      title: "All User",
      group: "User Register",
      purpose: "Registered users dekhne ke liye.",
      fields: ["Stakeholder Category", "Stakeholder Role", "Role", "User Management Role", "Person Type", "State", "District", "Block", "Gram Panchayat", "Village", "Office", "Full Address", "Pincode", "First Name", "Last Name", "Gender", "Email", "Password", "Confirmed Password", "User Name", "Mobile No", "User Type", "Status"]
    },
    "stakeholder-role" => {
      title: "Stakeholder Person Type",
      group: "Stakeholder",
      purpose: "Stakeholder category wise stakeholder person type maintain karne ke liye.",
      fields: ["Stakeholder Category", "Stakeholder Role", "Status"]
    },
    # "role-management" => {
    #   title: "Resource Person Type",
    #   group: "Resource Person Type",
    #   purpose: "Resource person type maintain karne ke liye.",
    #   fields: ["Stakeholder Category", "Stakeholder Role", "Role", "Status"]
    # },
    "role-name" => {
      title: "Role",
      group: "Stakeholder",
      purpose: "Stakeholder category wise role maintain karne ke liye.",
      fields: ["Stakeholder Category", "Stakeholder Role", "Role Name", "Status"]
    },
    # "user-management-role" => {
    #   title: "User Management Person Type",
    #   group: "Resource Person Type",
    #   purpose: "Resource person type wise user management person type maintain karne ke liye.",
    #   fields: ["Stakeholder Category", "Stakeholder Role", "Role", "User Management Role", "Status"]
    # },
    # "person-type" => {
    #   title: "Person Type",
    #   group: "Resource Person Type",
    #   purpose: "User management person type wise person type maintain karne ke liye.",
    #   fields: ["Stakeholder Category", "Stakeholder Role", "Role", "User Management Role", "Person Type", "Status"]
    # },
    "access-control" => {
      title: "Access Control",
      group: "Resource Person Type",
      purpose: "Role wise module access dene ke liye.",
      fields: ["Stakeholder", "Stakeholder Role", "Role Name", "Module Name", "Sub Module Name", "Can View", "Can Create", "Can Edit", "Can Delete", "Status"]
    },
    "access-control-list" => {
      title: "Access Control List",
      group: "Resource Person Type",
      purpose: "Saved access control records dekhne ke liye.",
      fields: ["Stakeholder", "Stakeholder Role", "Role Name", "Module Name", "Sub Module Name", "Status"]
    }
  }.freeze

  RECORD_SOURCE_SLUGS = {
    "activity-group-list" => "add-activity-group",
    "vrp-activity-list" => "add-vrp-activity",
    "task-completion-indicator-list" => "task-completion-indicator",
    "approval-list" => "approval-master",
    "access-control-list" => "access-control",
    "vrp-bill-list" => "vrp-bill-add",
    "all-user" => "new-user"
  }.freeze

  def dashboard
    @dashboard_cards = dashboard_cards
    @dashboard_reports = dashboard_reports
    @dashboard_generated_at = Time.current
  end

  def show
    load_module!
    redirect_to users_path and return if @slug == "all-user"
    redirect_to new_user_path and return if @slug == "new-user"

    @records = module_records
    prepare_lg_directory_data if @slug == "lg-directory-list"
    prepare_vrp_bill_data if @slug == "vrp-bill-add"
  end

  def edit
    load_module!
    @record = ModuleRecord.find(params[:id])
    @records = module_records
    prepare_vrp_bill_data if @slug == "vrp-bill-add"
    render :show
  end

  def create
    load_module!

    if record_source_slug == "approval-master" && approval_channel_params?
      create_approval_channel
      return
    end

    record = ModuleRecord.new(
      module_slug: record_source_slug,
      data: normalized_module_data
    )

    unless valid_module_data?(record.data)
      @records = module_records
      flash.now[:alert] = "Password and Confirmed Password must match."
      render :show, status: :unprocessable_entity
      return
    end

    if duplicate_access_control_record?(record.data)
      @records = module_records
      flash.now[:alert] = "Access control for this stakeholder and role already exists."
      render :show, status: :unprocessable_entity
      return
    end

    if record.save
      sync_vrp_master_record(record)
      redirect_to module_path(record_source_slug == "vrp-bill-add" ? "vrp-bill-list" : @slug), notice: "#{@module[:title]} saved successfully."
    else
      @records = module_records
      flash.now[:alert] = record.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  def update
    load_module!
    record = ModuleRecord.find(params[:id])
    previous_data = record.data.dup

    next_data = record.data.merge(normalized_module_data)

    unless valid_module_data?(next_data)
      @record = record
      @records = module_records
      flash.now[:alert] = "Password and Confirmed Password must match."
      render :show, status: :unprocessable_entity
      return
    end

    if duplicate_access_control_record?(next_data, except_id: record.id)
      @record = record
      @records = module_records
      flash.now[:alert] = "Access control for this stakeholder and role already exists."
      render :show, status: :unprocessable_entity
      return
    end

    if record.update(data: next_data)
      sync_stakeholder_name_change(previous_data, next_data)
      sync_vrp_master_record(record)
      redirect_to module_path(record_source_slug == "vrp-bill-add" ? "vrp-bill-list" : @slug), notice: "#{@module[:title]} updated successfully."
    else
      @record = record
      @records = module_records
      flash.now[:alert] = record.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    load_module!
    ModuleRecord.find(params[:id]).destroy
    if request.format.turbo_stream? || request.xhr?
      head :no_content
    else
      redirect_to module_path(@slug), notice: "#{@module[:title]} deleted successfully."
    end
  end

  def toggle_status
    load_module!
    record = ModuleRecord.find(params[:id])
    current_status = record.data["status"].presence || "Active"
    next_status = current_status == "Active" ? "Inactive" : "Active"

    if record.update(data: record.data.merge("status" => next_status))
      sync_vrp_master_record(record)
    end
    redirect_to module_path(@slug), notice: "Status changed to #{next_status}."
  end

  def import
    load_module!
    redirect_to module_path(@slug), alert: "Import is available only for LG Directory All List." and return unless @slug == "lg-directory-list"

    result = LgDirectoryImporter.import(params[:file])
    counts = lg_directory_import_notice_counts(result[:counts])
    notice = "LG Directory uploaded successfully. #{result[:imported]} records created"
    notice = "#{notice} (#{counts})" if counts.present?

    redirect_to module_path(@slug), notice: "#{notice}."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to module_path(@slug), alert: e.message
  end

  def export
    load_module!
    redirect_to module_path(@slug), alert: "Export is available only for LG Directory All List." and return unless @slug == "lg-directory-list"

    prepare_lg_directory_data
    send_data lg_directory_csv(@lg_directory_rows),
      filename: "lg_directory_all_list_#{Date.current}.csv",
      type: "text/csv"
  end

  def bulk_update
    load_module!
    redirect_to module_path(@slug), alert: "Bulk action is available only for LG Directory All List." and return unless @slug == "lg-directory-list"

    selected_records = lg_directory_selected_records
    redirect_to module_path(@slug), alert: "Please select at least one LG Directory row." and return if selected_records.blank?

    case params[:bulk_action]
    when "edit"
      redirect_to module_path(@slug), alert: "Please select one row only for edit." and return unless selected_records.one?

      redirect_to edit_module_record_path(selected_records.first.module_slug, selected_records.first)
    when "active", "inactive"
      next_status = params[:bulk_action] == "active" ? "Active" : "Inactive"
      selected_records.each { |record| record.update!(data: record.data.merge("status" => next_status)) }
      redirect_to module_path(@slug), notice: "#{selected_records.size} LG Directory row(s) marked #{next_status}."
    when "delete"
      selected_records.each(&:destroy!)
      redirect_to module_path(@slug), notice: "#{selected_records.size} LG Directory row(s) deleted."
    else
      redirect_to module_path(@slug), alert: "Please choose a valid action."
    end
  end

  def set_status
    load_module!
    record = ModuleRecord.find(params[:id])
    next_status = params[:status].presence_in(["Active", "Inactive"]) || "Active"

    if record.update(data: record.data.merge("status" => next_status))
      sync_vrp_master_record(record)
      redirect_to module_path(@slug), notice: "Status changed to #{next_status}."
    else
      redirect_to module_path(@slug), alert: record.errors.full_messages.to_sentence
    end
  end

  private

  def dashboard_cards
    vrps = dashboard_vrps
    bills = module_records_for_dashboard("vrp-bill-add")
    targets = module_records_for_dashboard("weekly-target-add")
    activities = module_records_for_dashboard("add-vrp-activity")
    training = module_records_for_dashboard("training-material")
    approved_vrps = vrps.count { |vrp| vrp.status.to_i == 55 || vrp_approval_complete?(vrp) }
    pending_approvals = vrps.count { |vrp| vrp_approval_pending?(vrp) }
    pending_payments = bills.count { |record| bill_payment_status(record).casecmp("Pending").zero? }

    [
      ["Total Registered VRP", vrps.size, "All VRP records saved in registration"],
      ["Final Approved VRP", approved_vrps, "VRP records with final approval"],
      ["VRP Waiting for Approval", pending_approvals, "VRP records currently pending"],
      ["Bills Created", bills.size, "All VRP bill records entered"],
      ["Bills Pending Payment", pending_payments, "Bills where payment status is Pending"],
      ["Weekly Targets Assigned", targets.size, "All weekly target records entered"],
      ["Activities Configured", activities.size, "Activities available for target and bill work"],
      ["Training Materials Uploaded", training.size, "Training files or material records"]
    ]
  end

  def dashboard_reports
    bills = module_records_for_dashboard("vrp-bill-add")
    targets = module_records_for_dashboard("weekly-target-add")

    [
      {
        title: "Monthly Bill Summary",
        headers: ["Month", "Bills", "Amount"],
        rows: grouped_rows(bills, "select_bill_month", "grand_total")
      },
      {
        title: "Weekly Target Status",
        headers: ["Week", "Assigned", "Completed"],
        rows: grouped_count_rows(targets, "week", "completion_status", "Completed")
      },
      {
        title: "Bill Payment Status",
        headers: ["Payment Status", "Bills", "Amount"],
        rows: grouped_rows(bills, "payment_status", "grand_total", default_key: "Pending")
      },
      {
        title: "Live Clock",
        clock: true
      }
    ]
  end

  def dashboard_vrps
    return [] unless model_ready?(:Vrp)
    return Vrp.all.to_a if current_app_user.blank? || current_app_user["user_type"].to_s.casecmp("admin").zero?

    ids = dashboard_current_app_user_ids
    emails = dashboard_current_app_user_emails
    return [] if ids.blank? && emails.blank?

    scope = Vrp.none
    if ids.any?
      scope = scope.or(Vrp.where(created_by_id: ids))
      scope = scope.or(Vrp.where(user_id: ids)) if Vrp.column_names.include?("user_id")
    end

    if emails.any?
      unassigned_scope = Vrp.where(created_by_id: nil).where("LOWER(email) IN (?)", emails)
      unassigned_scope = unassigned_scope.where(user_id: nil) if Vrp.column_names.include?("user_id")
      scope = scope.or(unassigned_scope)
    end

    scope.to_a
  end

  def dashboard_current_app_user_ids
    ([current_app_user&.dig("id")] + dashboard_legacy_current_app_user_ids).compact.uniq
  end

  def dashboard_legacy_current_app_user_ids
    return [] unless model_ready?(:ModuleRecord)

    username = current_app_user&.dig("username").to_s
    emails = dashboard_current_app_user_emails
    return [] if username.blank? && emails.blank?

    ModuleRecord.where(module_slug: "new-user").select do |record|
      record.data["user_name"].to_s == username ||
        emails.include?(record.data["email"].to_s.strip.downcase)
    end.map(&:id)
  end

  def dashboard_current_app_user_emails
    emails = [current_app_user&.dig("email")]

    if model_ready?(:User)
      user = User.find_by(user_name: current_app_user&.dig("username")) || User.find_by(id: current_app_user&.dig("id"))
      emails << user&.email
    end

    emails.compact_blank.map { |email| email.to_s.strip.downcase }.uniq
  end

  def module_records_for_dashboard(slug)
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord.where(module_slug: slug).order(created_at: :desc).to_a
  end

  def grouped_rows(records, group_key, amount_key, default_key: "Not Set")
    grouped = records.group_by { |record| record.data[group_key].presence || default_key }

    grouped.map do |key, rows|
      amount = rows.sum { |record| dashboard_amount(record, amount_key) }
      [key, rows.size, amount.positive? ? format("%.2f", amount) : "-"]
    end.presence || [["No data", 0, "-"]]
  end

  def grouped_count_rows(records, group_key, count_key, count_value)
    grouped = records.group_by { |record| record.data[group_key].presence || "Not Set" }

    grouped.map do |key, rows|
      [key, rows.size, rows.count { |record| record.data[count_key] == count_value }]
    end.presence || [["No data", 0, 0]]
  end

  def dashboard_amount(record, preferred_key)
    value = record.data[preferred_key].presence || record.data["grand_total"].presence || record.data["bill_amount"]
    value.to_s.gsub(",", "").to_f
  end

  def bill_payment_status(record)
    record.data["payment_status"].to_s.strip.presence || "Pending"
  end

  def bill_approved?(record)
    record.data["status"].to_s.casecmp("Approved").zero? || bill_payment_status(record).casecmp("Paid").zero?
  end

  def vrp_approval_pending?(vrp)
    return false if [55, 99].include?(vrp.status.to_i)
    return false if vrp.status.to_i < 25
    return false if vrp.status.to_i == 25 && !vrp_approval_sent?(vrp)

    !vrp_approval_rejected?(vrp) && !vrp_approval_complete?(vrp)
  end

  def vrp_approval_sent?(vrp)
    vrp_approval_history_for(vrp).any? do |record|
      ["Sent for Approval", "Approved", "Rejected"].include?(record.data["action"].to_s)
    end
  end

  def vrp_approval_rejected?(vrp)
    vrp_approval_history_for(vrp).any? { |record| record.data["action"].to_s == "Rejected" }
  end

  def vrp_approval_complete?(vrp)
    steps = vrp_approval_steps_for(vrp)
    return false if steps.blank?

    steps.all? { |step| vrp_approval_step_closed?(vrp, step) }
  end

  def vrp_approval_step_closed?(vrp, step)
    step_sequence = vrp_approval_sequence(step)
    step_approver = normalize_approval_label(step.data["approver_approved_by"].presence || "Approver")

    vrp_approval_history_for(vrp).any? do |record|
      ["Approved", "Rejected"].include?(record.data["action"].to_s) &&
        (
          approval_sequence_from_level(record.data["approval_level"]) == step_sequence ||
            normalize_approval_label(record.data["approver"]) == step_approver
        )
    end
  end

  def vrp_approval_history_for(vrp)
    return [] unless model_ready?(:ModuleRecord)

    @dashboard_approval_history ||= ModuleRecord.where(module_slug: "vrp-approval-history").order(created_at: :asc).to_a
    @dashboard_approval_history.select { |record| record.data["vrp_id"].to_i == vrp.id }
  end

  def vrp_approval_steps_for(vrp)
    return [] unless model_ready?(:ModuleRecord)

    identities = vrp_creator_identities_for_dashboard(vrp)
    return [] if identities.blank?

    @dashboard_approval_steps ||= ModuleRecord.where(module_slug: "approval-master").order(created_at: :asc).to_a
    @dashboard_approval_steps
      .select do |record|
        record.data["status"].to_s != "Inactive" &&
          ["Farmer Registration", "VRP Registration"].include?(record.data["module_name"].to_s) &&
          identities.any? do |identity|
            record_role = record.data["role"].presence || record.data["role_name"]
            record_role_name = record.data["role"].present? ? record.data["role_name"] : nil
            dashboard_value_matches?(record_role, identity[:role]) &&
              dashboard_value_matches?(record_role_name, identity[:role_name]) &&
              dashboard_value_matches?(record.data["stakeholder_name"], identity[:stakeholder]) &&
              dashboard_value_matches?(record.data["stakeholder_role"], identity[:stakeholder_role]) &&
              dashboard_value_matches?(record.data["user_management_role"], identity[:user_management_role]) &&
              dashboard_value_matches?(record.data["person_type"], identity[:person_type]) &&
              dashboard_vrp_name_matches?(record.data["vrp_name"], vrp) &&
              (record.data["office"].blank? || dashboard_value_matches?(record.data["office"], identity[:office]))
          end
      end
      .group_by { |record| vrp_approval_sequence(record) }
      .values
      .map { |records| records.max_by { |record| approval_record_priority(record) } }
      .sort_by { |record| vrp_approval_sequence(record) }
  end

  def vrp_creator_identities_for_dashboard(vrp)
    identities = []

    if vrp.created_by_id.present? && model_ready?(:User)
      user = User.find_by(id: vrp.created_by_id)
      identities << user_dashboard_identity(user) if user
    end

    if model_ready?(:User)
      matched_users = []
      matched_users << User.find_by(email: vrp.email) if vrp.email.present?
      matched_users << User.find_by(mobile_no: vrp.mobile_no) if vrp.mobile_no.present?
      matched_users.compact.uniq.each do |user|
        identities << user_dashboard_identity(user)
      end
    end

    if vrp.created_by_id.present? && model_ready?(:ModuleRecord)
      record = ModuleRecord.find_by(id: vrp.created_by_id)
      identities << record_dashboard_identity(record) if record
    end

    if model_ready?(:ModuleRecord)
      matched_records = ModuleRecord.where(module_slug: "new-user").select do |record|
        (vrp.email.present? && record.data["email"].to_s.casecmp(vrp.email.to_s).zero?) ||
          (vrp.mobile_no.present? && record.data["mobile_no"].to_s == vrp.mobile_no.to_s)
      end
      matched_records.each do |record|
        identities << record_dashboard_identity(record)
      end
    end

    identities << {
      role: current_app_user&.dig("role"),
      role_name: current_app_user&.dig("role_name"),
      stakeholder: current_app_user&.dig("stakeholder"),
      stakeholder_role: current_app_user&.dig("stakeholder_role"),
      user_management_role: current_app_user&.dig("user_management_role"),
      person_type: current_app_user&.dig("person_type"),
      office: current_app_user&.dig("office")
    } if vrp.created_by_id.blank?

    identities
      .select { |identity| identity[:role].present? && identity[:stakeholder].present? }
      .uniq
  end

  def user_dashboard_identity(user)
    {
      role: user.role,
      stakeholder: user.stakeholder,
      stakeholder_role: user.stakeholder_role,
      user_management_role: user.user_management_role,
      person_type: user.respond_to?(:person_type) ? user.person_type : nil,
      office: user.office
    }
  end

  def record_dashboard_identity(record)
    {
      role: record.data["role"],
      stakeholder: record.data["stakeholder"],
      stakeholder_role: record.data["stakeholder_role"],
      user_management_role: record.data["user_management_role"],
      person_type: record.data["person_type"],
      office: record.data["office"]
    }
  end

  def vrp_approval_sequence(record)
    approval_sequence_from_level(record.data["approval_level"])
  end

  def approval_sequence_from_level(level)
    level = level.to_s.downcase
    return 1 if level.include?("first")
    return 2 if level.include?("second")
    return 3 if level.include?("third")

    level[/\d+/].to_i.presence || 1
  end

  def normalize_approval_label(label)
    label.to_s.sub(/\s*\([^)]*\)\s*\z/, "").strip.downcase
  end

  def dashboard_value_matches?(expected, actual)
    return true if expected.blank?

    expected.to_s.strip.casecmp(actual.to_s.strip).zero?
  end

  def percentage(value, total)
    return "0%" if total.to_i.zero?

    "#{((value.to_f / total) * 100).round}%"
  end

  def load_module!
    @slug = current_slug
    @module = MODULES[@slug]
    redirect_to dashboard_path, alert: "Module not found." and return unless @module
  end

  def current_slug
    params[:slug] || params[:module_slug]
  end

  def module_records
    return [] unless ModuleRecord.table_exists?

    ModuleRecord.where(module_slug: record_source_slug).to_a.sort_by { |record| module_record_sort_value(record) }
  end

  def prepare_lg_directory_data
    @lg_directory_filter = params[:table].presence_in(lg_directory_filter_fields) || "State"
    @lg_directory_query = params[:q].to_s.strip
    @lg_directory_rows = filtered_lg_directory_rows(lg_directory_rows)
  end

  def filtered_lg_directory_rows(rows)
    return rows if @lg_directory_query.blank?

    key = @lg_directory_filter.parameterize(separator: "_").to_sym
    rows.select { |row| row[key].to_s.downcase.include?(@lg_directory_query.downcase) }
  end

  def lg_directory_rows
    return [] unless model_ready?(:ModuleRecord)

    rows = []
    rows.concat(lg_rows_from_records("village-master", village: "village_name"))
    rows.concat(lg_rows_from_records("gram-panchayat-master", gram_panchayat: "gram_panchayat_name"))
    rows.concat(lg_rows_from_records("block-master", block: "block_name"))
    rows.concat(lg_rows_from_records("district-master", district: "district_name"))
    rows.concat(lg_rows_from_records("state-master", state: "state_name"))
    state_codes = lg_directory_code_lookup(rows, :state, :state_code)
    gp_codes = lg_directory_code_lookup(rows, :gram_panchayat, :gp_code)

    compact_lg_directory_rows(rows)
      .map do |row|
        row.merge(
          state_code: row[:state_code].presence || state_codes[row[:state].to_s.strip.downcase],
          gp_code: row[:gp_code].presence || gp_codes[row[:gram_panchayat].to_s.strip.downcase]
        )
      end
      .uniq { |row| lg_directory_row_key(row) }
      .sort_by { |row| [row[:state], row[:district], row[:block], row[:gram_panchayat], row[:village]].map(&:to_s) }
  end

  def lg_rows_from_records(module_slug, aliases)
    ModuleRecord
      .where(module_slug: module_slug)
      .order(created_at: :desc)
      .map do |record|
        {
          record_id: record.id,
          source_slug: record.module_slug,
          state: record.data["state"].presence || record.data[aliases[:state].to_s].presence,
          state_code: record.data["state_code"].presence || record.data[aliases[:state_code].to_s].presence,
          district: record.data["district"].presence || record.data[aliases[:district].to_s].presence,
          block: record.data["block"].presence || record.data[aliases[:block].to_s].presence,
          gram_panchayat: record.data["gram_panchayat"].presence || record.data[aliases[:gram_panchayat].to_s].presence,
          gp_code: record.data["gp_code"].presence || record.data[aliases[:gp_code].to_s].presence,
          village: record.data["village"].presence || record.data[aliases[:village].to_s].presence,
          village_code: record.data["village_code"].presence || record.data[aliases[:village_code].to_s].presence,
          status: record.data["status"].presence || "Active"
        }
      end
  end

  def lg_directory_code_lookup(rows, name_key, code_key)
    rows.each_with_object({}) do |row, codes|
      next if row[name_key].blank? || row[code_key].blank?

      codes[row[name_key].to_s.strip.downcase] ||= row[code_key]
    end
  end

  def compact_lg_directory_rows(rows)
    rows.reject { |row| lg_directory_prefix_covered?(row, rows) }
  end

  def lg_directory_prefix_covered?(row, rows)
    levels = [:state, :district, :block, :gram_panchayat, :village]
    last_present_index = levels.rindex { |key| row[key].present? }
    return false unless last_present_index
    return false if last_present_index == levels.size - 1

    prefix = levels.first(last_present_index + 1)
    rows.any? do |candidate|
      next false if candidate.equal?(row)

      prefix.all? { |key| candidate[key].to_s.strip.casecmp(row[key].to_s.strip).zero? } &&
        levels[(last_present_index + 1)..].any? { |key| candidate[key].present? }
    end
  end

  def lg_directory_row_key(row)
    [:state, :district, :block, :gram_panchayat, :village]
      .map { |key| row[key].to_s.strip.downcase }
      .join("|")
  end

  def lg_directory_filter_fields
    ["State", "State Code", "District", "Block", "Gram Panchayat", "GP Code", "Village", "Village Code"]
  end

  def lg_directory_import_notice_counts(counts)
    {
      "state-master" => "State",
      "district-master" => "District",
      "block-master" => "Block",
      "gram-panchayat-master" => "GP",
      "village-master" => "Village"
    }.filter_map do |slug, label|
      count = counts[slug].to_i
      "#{label}: #{count}" if count.positive?
    end.join(", ")
  end

  def lg_directory_selected_records
    allowed_slugs = [
      "state-master",
      "district-master",
      "block-master",
      "gram-panchayat-master",
      "village-master"
    ]

    Array(params[:row_tokens]).filter_map do |token|
      slug, id = token.to_s.split(":", 2)
      next unless allowed_slugs.include?(slug) && id.present?

      ModuleRecord.where(module_slug: slug).find_by(id: id)
    end.uniq
  end

  def lg_directory_csv(rows)
    CSV.generate(headers: true) do |csv|
      csv << ["State", "State Code", "District", "Block", "Gram Panchayat", "GP Code", "Village", "Village Code", "Status"]
      rows.each do |row|
        csv << [
          row[:state],
          row[:state_code],
          row[:district],
          row[:block],
          row[:gram_panchayat],
          row[:gp_code],
          row[:village],
          row[:village_code],
          row[:status]
        ]
      end
    end
  end

  def prepare_vrp_bill_data
    @approved_vrp_options = approved_vrp_options
    month_master_rows = active_month_master_rows
    @bill_financial_year_options = month_master_rows.filter_map { |record| record.data["financial_year"].presence }.uniq
    @bill_month_options = month_master_rows.filter_map { |record| record.data["month_name"].presence }.uniq
    @bill_project_options = module_record_values("ics-master", "ics_name", "name", "ics", "select_ics") +
      module_record_values("add-vrp-activity", "ics", "select_ics", "ics_name")
    @bill_project_options = @bill_project_options.compact_blank.uniq

    @bill_activity_group_options = module_record_values("add-activity-group", "main_activity_name", "activity_group_name", "activity_group", "group_name", "name") +
      module_record_values("add-vrp-activity", "activity_group", "activity_group_name", "group_name")
    @bill_activity_group_options = @bill_activity_group_options.compact_blank.uniq
    @bill_village_options = module_field_options("Village")
    @bill_activity_map = bill_activity_map
    @bill_tci_map = bill_tci_map
  end

  def approved_vrp_options
    return [] unless model_ready?(:Vrp)

    scope = Vrp.where(status: 55)
    scope = scope.where(is_active: true) if Vrp.column_names.include?("is_active")

    scope.order(:name).map do |vrp|
      label = [vrp.name, vrp.mobile_no.presence].compact_blank.join(" - ")
      [label.presence || "VRP ##{vrp.id}", label.presence || vrp.id.to_s]
    end
  end

  def active_month_master_rows
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "month-master")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
  end

  def bill_activity_map
    return {} unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "add-vrp-activity")
      .select { |record| active_module_record?(record) }
      .group_by { |record| first_present_data(record, "main_activity", "activity_group", "activity_group_name", "group_name").to_s }
      .transform_values do |records|
        records.map do |record|
          {
            activity: first_present_data(record, "sub_activity_name", "activity_name", "vrp_activity_name", "activity").to_s,
            unit: record.data["unit"].to_s
          }
        end.reject { |row| row[:activity].blank? }
      end
  end

  def bill_tci_map
    return {} unless model_ready?(:ModuleRecord)

    grouped = ModuleRecord
      .where(module_slug: "task-completion-indicator")
      .select { |record| active_module_record?(record) }
      .group_by { |record| first_present_data(record, "select_activity", "activity", "activity_name").to_s }
      .transform_values do |records|
        records.map do |record|
          {
            indicator: first_present_data(record, "tci_name", "task_completion_indicator", "indicator").to_s,
            mandatory: first_present_data(record, "select_mandatory", "mandatory").presence || "No"
          }
        end.reject { |row| row[:indicator].blank? }
      end

    grouped.merge("__all" => grouped.values.flatten.uniq { |row| row[:indicator] })
  end

  def module_record_values(module_slug, *keys)
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: module_slug)
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .flat_map do |record|
        keys.filter_map { |key| record.data[key].presence }
      end
      .flat_map { |value| value.is_a?(Array) ? value : value.to_s.split(",") }
      .map(&:to_s)
      .map(&:strip)
      .reject(&:blank?)
  end

  def first_present_data(record, *keys)
    keys.filter_map { |key| record.data[key].presence }.first
  end

  def record_source_slug
    slug = @slug || current_slug
    RECORD_SOURCE_SLUGS.fetch(slug, slug)
  end

  def module_record_sort_value(record)
    visible_fields = @module&.dig(:fields) || []
    sort_field = visible_fields.reject { |field| field == "Status" }.first
    sort_key = sort_field&.parameterize(separator: "_")

    record.data[sort_key].presence ||
      record.data.values.find(&:present?).to_s
  end

  def module_record_params
    params.require(:module_record).permit!
  end

  def normalized_module_data
    data = module_record_params.to_h.transform_values do |value|
      if value.respond_to?(:original_filename)
        store_uploaded_module_file(value)
      else
        value
      end
    end

    if record_source_slug == "access-control"
      data["module_names"] ||= []
      data["sub_module_names"] ||= []
      data["stakeholder"] = data["stakeholder_name"] if data["stakeholder_name"].present?
    end

    data
  end

  def duplicate_access_control_record?(data, except_id: nil)
    return false unless record_source_slug == "access-control"
    return false unless model_ready?(:ModuleRecord)

    stakeholder = normalized_access_value(data["stakeholder_name"].presence || data["stakeholder"])
    stakeholder_role = normalized_access_value(data["stakeholder_role"].presence || data["stakeholder_person_type"])
    role = normalized_access_value(data["role"].presence || data["role_name"])
    role_name = normalized_access_value(data["role"].present? ? data["role_name"] : nil)
    user_management_role = normalized_access_value(data["user_management_role"].presence || data["user_management_person_type"])
    person_type = normalized_access_value(data["person_type"])
    return false if stakeholder.blank?

    ModuleRecord
      .where(module_slug: "access-control")
      .where.not(id: except_id)
      .any? do |record|
        normalized_access_value(record.data["stakeholder_name"].presence || record.data["stakeholder"]) == stakeholder &&
          normalized_access_value(record.data["stakeholder_role"].presence || record.data["stakeholder_person_type"]) == stakeholder_role &&
          normalized_access_value(record.data["role"].presence || record.data["role_name"]) == role &&
          normalized_access_value(record.data["role"].present? ? record.data["role_name"] : nil) == role_name &&
          normalized_access_value(record.data["user_management_role"].presence || record.data["user_management_person_type"]) == user_management_role &&
          normalized_access_value(record.data["person_type"]) == person_type &&
          normalized_access_value(record.data["status"].presence || "Active") == "active"
      end
  end

  def normalized_access_value(value)
    value.to_s.strip.downcase
  end

  def sync_stakeholder_name_change(previous_data, next_data)
    return unless record_source_slug == "stakeholder-master"

    previous_names = stakeholder_record_names(previous_data)
    next_name = (next_data["stakeholder_name_in_english"].presence || next_data["stakeholder_name"].presence).to_s.strip
    return if previous_names.blank? || next_name.blank?

    previous_names.each do |previous_name|
      next if previous_name == next_name

      User.where(stakeholder: previous_name).update_all(stakeholder: next_name, updated_at: Time.current) if model_ready?(:User)
      sync_legacy_user_stakeholder_name(previous_name, next_name)
    end
  end

  def stakeholder_record_names(data)
    [
      data["stakeholder_name_in_english"],
      data["stakeholder_name_in_hindi"],
      data["stakeholder_name"]
    ].compact_blank.map(&:to_s).map(&:strip).uniq
  end

  def sync_legacy_user_stakeholder_name(previous_name, next_name)
    return unless model_ready?(:ModuleRecord)

    ModuleRecord.where(module_slug: "new-user").find_each do |user_record|
      next unless user_record.data["stakeholder"].to_s.strip == previous_name

      user_record.update(data: user_record.data.merge("stakeholder" => next_name))
    end
  end

  def approval_channel_params?
    module_record_params[:approval_steps].present?
  end

  def create_approval_channel
    data = normalized_module_data
    steps = data.delete("approval_steps").to_h
    saved_count = 0

    steps.each do |level, approver|
      next if approver.blank?

      ModuleRecord.create!(
        module_slug: "approval-master",
        data: data.merge(
          "approval_level" => level,
          "approver_approved_by" => approver,
          "status" => data["status"].presence || "Active"
        )
      )
      saved_count += 1
    end

    if saved_count.positive?
      redirect_to module_path("approval-list"), notice: "Approval channel saved successfully."
    else
      @records = module_records
      flash.now[:alert] = "Please select at least one approval user."
      render :show, status: :unprocessable_entity
    end
  end

  def valid_module_data?(data)
    return true unless record_source_slug == "new-user"

    data["password"].to_s == data["confirmed_password"].to_s
  end

  def store_uploaded_module_file(upload)
    upload_dir = Rails.root.join("public", "uploads", "module_records")
    FileUtils.mkdir_p(upload_dir)

    extension = File.extname(upload.original_filename)
    basename = File.basename(upload.original_filename, extension).parameterize
    filename = "#{Time.current.to_i}-#{SecureRandom.hex(4)}-#{basename}#{extension.downcase}"
    path = upload_dir.join(filename)

    File.binwrite(path, upload.read)
    "/uploads/module_records/#{filename}"
  end

  def module_select_field?(field)
    source = field_sources[field]
    (source.present? && source[:module] != (@slug || current_slug)) || static_field_options(field).any?
  end

  def module_field_options(field)
    source = field_sources[field]
    return [] unless ModuleRecord.table_exists?

    if source
      return [] if source[:module] == (@slug || current_slug)

      return values_from_module(source[:module], source[:field])
    end

    generic_field_options(field)
  end

  def role_management_mappings
    return [] unless model_ready?(:ModuleRecord)

    stakeholder_role_mappings = ModuleRecord
      .where(module_slug: "stakeholder-role")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .flat_map do |record|
        stakeholder_role = first_present_data(record, "stakeholder_role").to_s.strip
        mapping_labels_for_option(stakeholder_role, :stakeholder_role).map do |stakeholder_role_label|
          {
            stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
            stakeholder_role: stakeholder_role,
            stakeholder_role_label: stakeholder_role_label,
            role: "",
            role_label: "",
            role_name: "",
            role_name_label: "",
            user_management_role: "",
            user_management_role_label: "",
            person_type: "",
            person_type_label: ""
          }
        end
      end

    role_mappings = ModuleRecord
      .where(module_slug: "role-name")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .flat_map do |record|
        role = first_present_data(record, "role_name").to_s.strip
        mapping_labels_for_option(role, :role).map do |role_label|
          {
            stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
            stakeholder_role: first_present_data(record, "stakeholder_role").to_s.strip,
            role: role,
            role_label: role_label,
            role_name: "",
            role_name_label: "",
            user_management_role: "",
            user_management_role_label: "",
            person_type: ""
          }
        end
      end

    user_management_role_mappings = ModuleRecord
      .where(module_slug: "user-management-role")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .flat_map do |record|
        user_management_role = first_present_data(record, "user_management_role").to_s.strip
        mapping_labels_for_option(user_management_role, :user_management_role).map do |user_management_role_label|
          {
            stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
            stakeholder_role: first_present_data(record, "stakeholder_role").to_s.strip,
            role: first_present_data(record, "role", "role_name").to_s.strip,
            role_name: "",
            role_name_label: "",
            user_management_role: user_management_role,
            user_management_role_label: user_management_role_label,
            person_type: ""
          }
        end
      end

    person_type_mappings = ModuleRecord
      .where(module_slug: "person-type")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .flat_map do |record|
        role = first_present_data(record, "role", "role_name").to_s.strip
        user_management_role = first_present_data(record, "user_management_role").to_s.strip
        person_type = first_present_data(record, "person_type").to_s.strip
        joined_type_labels(role, user_management_role, person_type).map do |person_type_label|
          {
            stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
            stakeholder_role: first_present_data(record, "stakeholder_role").to_s.strip,
            role: role,
            role_name: "",
            role_name_label: "",
            user_management_role: user_management_role,
            person_type: person_type,
            person_type_label: person_type_label
          }
        end
      end

    (stakeholder_role_mappings + role_mappings + user_management_role_mappings + person_type_mappings)
      .reject { |mapping| mapping[:stakeholder_role].blank? && mapping[:role].blank? && mapping[:role_name].blank? && mapping[:user_management_role].blank? && mapping[:person_type].blank? }
      .uniq
  end

  def label_with_registered_name(value, attribute)
    mapping_labels_for_option(value, attribute).first.to_s
  end

  def access_control_field_options(field, selected_value = nil)
    key = case field
    when "Stakeholder"
      :stakeholder
    when "Stakeholder Role"
      :stakeholder_role
    when "Role Name", "Role"
      :role
    end
    return [] unless key

    options = access_control_role_mappings.filter_map { |mapping| mapping[key].presence }
    options << selected_value if selected_value.present?
    options.compact_blank.uniq
  end

  def access_control_role_mappings
    registered_access_users
      .filter_map do |data|
        stakeholder = data["stakeholder"].to_s.strip
        stakeholder_role = data["stakeholder_role"].to_s.strip
        role = (data["role"].presence || data["role_name"]).to_s.strip
        next if stakeholder.blank? || stakeholder_role.blank? || role.blank?

        {
          stakeholder: stakeholder,
          stakeholder_role: stakeholder_role,
          stakeholder_role_label: stakeholder_role,
          role: role,
          role_label: role,
          role_name: "",
          role_name_label: "",
          user_management_role: data["user_management_role"].to_s.strip,
          user_management_role_label: data["user_management_role"].to_s.strip,
          person_type: data["person_type"].to_s.strip,
          person_type_label: data["person_type"].to_s.strip
        }
      end
      .uniq
  end

  def registered_access_users
    registered_access_user_model_rows + registered_access_module_rows
  end

  def registered_access_user_model_rows
    return [] unless model_ready?(:User)

    User.order(updated_at: :desc).filter_map do |user|
      status = user.respond_to?(:status) ? user.status.to_s : "Active"
      next if status.casecmp("Inactive").zero?

      {
        "stakeholder" => user.stakeholder,
        "stakeholder_role" => user.stakeholder_role,
        "role" => user.role,
        "role_name" => user.respond_to?(:role_name) ? user.role_name : nil,
        "user_management_role" => user.respond_to?(:user_management_role) ? user.user_management_role : nil,
        "person_type" => user.respond_to?(:person_type) ? user.person_type : nil
      }
    end
  end

  def registered_access_module_rows
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "new-user")
      .order(updated_at: :desc)
      .select { |record| active_module_record?(record) }
      .map(&:data)
  end

  def mapping_labels_for_option(value, attribute)
    return [] if value.blank?

    registered_names = registered_names_for_option(attribute, value)
    return [value] if registered_names.blank?

    registered_names.map { |registered_name| "#{value} (#{registered_name})" }
  end

  def joined_type_labels(role, user_management_role, person_type)
    base = [role, user_management_role, person_type].compact_blank.join("-")
    return [] if base.blank?

    registered_names =
      registered_names_for_option(:person_type, person_type).presence ||
      registered_names_for_option(:user_management_role, user_management_role).presence ||
      registered_names_for_option(:role, role)
    return [base] if registered_names.blank?

    registered_names.map { |registered_name| "#{base} (#{registered_name})" }
  end

  def registered_names_for_option(attribute, value)
    return [] if value.blank?

    (
      registered_vrp_names_for_option(attribute, value) +
      registered_user_names_for_option(attribute, value) +
      registered_module_user_names_for_option(attribute, value)
    ).compact_blank.uniq
  end

  def registered_vrp_names_for_option(attribute, value)
    return [] unless model_ready?(:Vrp)
    return [] unless Vrp.column_names.include?(attribute.to_s)

    Vrp.where(attribute => value).order(updated_at: :desc).filter_map { |vrp| vrp.name.presence }
  end

  def registered_user_names_for_option(attribute, value)
    return [] unless model_ready?(:User)
    return [] unless User.column_names.include?(attribute.to_s)

    User.where(attribute => value).order(updated_at: :desc).filter_map { |user| user.full_name.presence || user.user_name.presence }
  end

  def registered_module_user_names_for_option(attribute, value)
    return [] unless model_ready?(:ModuleRecord)

    key = attribute.to_s
    ModuleRecord
      .where(module_slug: "new-user")
      .order(updated_at: :desc)
      .select { |record| active_module_record?(record) && record.data[key].to_s.strip.casecmp(value.to_s.strip).zero? }
      .filter_map { |record| [record.data["first_name"], record.data["last_name"]].compact_blank.join(" ").presence || record.data["user_name"].presence }
  end

  def location_hierarchy_mappings
    return [] unless model_ready?(:ModuleRecord)

    states = active_records_for_location("state-master").map do |record|
      location_row(record, state: first_present_data(record, "state_name"))
    end

    districts = active_records_for_location("district-master").map do |record|
      location_row(record,
        state: first_present_data(record, "state"),
        district: first_present_data(record, "district_name"))
    end

    blocks = active_records_for_location("block-master").map do |record|
      location_row(record,
        state: first_present_data(record, "state"),
        district: first_present_data(record, "district"),
        block: first_present_data(record, "block_name"))
    end

    gram_panchayats = active_records_for_location("gram-panchayat-master").map do |record|
      location_row(record,
        state: first_present_data(record, "state"),
        district: first_present_data(record, "district"),
        block: first_present_data(record, "block"),
        gram_panchayat: first_present_data(record, "gram_panchayat_name"))
    end

    villages = active_records_for_location("village-master").map do |record|
      location_row(record,
        state: first_present_data(record, "state"),
        district: first_present_data(record, "district"),
        block: first_present_data(record, "block"),
        gram_panchayat: first_present_data(record, "gram_panchayat"),
        village: first_present_data(record, "village_name"))
    end

    states + districts + blocks + gram_panchayats + villages
  end

  def active_records_for_location(module_slug)
    ModuleRecord
      .where(module_slug: module_slug)
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
  end

  def location_row(record, values)
    row = { id: record.id.to_s }
    values.each { |key, value| row[key] = value.to_s.strip if value.present? }
    row
  end

  def static_field_options(field)
    {
      "Month Name" => Date::MONTHNAMES.compact,
      "Financial Year" => financial_year_options,
      "Approval Level" => ["First Approval", "Second Approval", "Third Approval"],
      "Priority" => ["High", "Medium", "Low"],
      "Payment Status" => ["Pending", "Paid", "Rejected"],
      "Completion Status" => ["Pending", "Completed", "Overdue"],
      "Gender" => ["Male", "Female", "Other"],
      "User Type" => ["Admin", "User"],
      "Can View" => ["Yes", "No"],
      "Can Create" => ["Yes", "No"],
      "Can Edit" => ["Yes", "No"],
      "Can Delete" => ["Yes", "No"],
      "Select Mandatory" => ["Yes", "No"],
      "Office Level" => ["State", "District", "Block", "Gram Panchayat", "Village"],
      "Module Name" => ["VRP Registration", "VRP Bill"],
      "VRP Name" => vrp_name_options,
      "Sub Module Name" => sidebar_submodule_names
    }[field] || []
  end

  def financial_year_options
    current_year = Date.current.year

    ((current_year - 2)..(current_year + 5)).map do |year|
      "#{year}-#{year + 1}"
    end
  end

  def field_sources
    {
      "State" => { module: "state-master", field: "state_name" },
      "District" => { module: "district-master", field: "district_name" },
      "Block" => { module: "block-master", field: "block_name" },
      "Gram Panchayat" => { module: "gram-panchayat-master", field: "gram_panchayat_name" },
      "Village" => { module: "village-master", field: "village_name" },
      "VRP Type" => { module: "add-vrp-type", field: "vrp_type_name" },
      "Select VRP Type" => { module: "add-vrp-type", field: "vrp_type_name" },
      "Activity Group" => { module: "add-activity-group", field: "activity_group_name" },
      "Main Activity" => { module: "add-activity-group", field: "main_activity_name" },
      "Select Main Activity" => { module: "add-activity-group", field: "main_activity_name" },
      "VRP Activity" => { module: "add-vrp-activity", field: "activity_name" },
      "Sub Activity" => { module: "add-vrp-activity", field: "sub_activity_name" },
      "Stakeholder" => { module: "stakeholder-master", field: "stakeholder_name_in_english" },
      "Stakeholder Name" => { module: "stakeholder-master", field: "stakeholder_name_in_english" },
      "Stakeholder Category" => { module: "stakeholder-master", field: "stakeholder_name_in_english" },
      "Stakeholder Role" => { module: "stakeholder-role", field: "stakeholder_role" },
      "Office" => { module: "office-category-add", field: "category_name" },
      "Approver (Approved By)" => { module: "new-user", field: "approver_name_with_role" },
      "Select Financial Year" => { module: "month-master", field: "financial_year" },
      "Select Bill Month" => { module: "month-master", field: "month_name" },
      "Month" => { module: "month-master", field: "month_name" },
      "ICS" => { module: "ics-master", field: "ics_name" },
      "Select ICS" => { module: "ics-master", field: "ics_name" },
      "Activity" => { module: "add-vrp-activity", field: "activity_name" },
      "Select Activity" => { module: "add-vrp-activity", field: "activity_name" },
      "Sub Activity Name" => { module: "add-vrp-activity", field: "sub_activity_name" },
      "Task Indicator" => { module: "task-indicator-master", field: "task_indicator_name" },
      "Select Task Indicator" => { module: "task-indicator-master", field: "task_indicator_name" },
      "Bank Name" => { module: "bank-master", field: "bank_name" },
      "Role" => { module: "role-name", field: "role_name" },
      "Role Name" => { module: "role-name", field: "role_name" },
      "User Management Role" => { module: "user-management-role", field: "user_management_role" },
      "Person Type" => { module: "person-type", field: "person_type" }
    }
  end

  def office_category_mappings
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "office-category-add")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .map do |record|
        {
          stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
          office: first_present_data(record, "category_name", "office").to_s.strip
        }
      end
      .reject { |mapping| mapping[:office].blank? }
      .uniq
  end

  def vrp_name_options
    return [] unless model_ready?(:Vrp)

    Vrp.order(:name, :id).filter_map { |vrp| vrp_approval_label(vrp) }.uniq
  end

  def vrp_approval_label(vrp)
    [vrp.name.presence, vrp.mobile_no.presence].compact.join(" - ").presence
  end

  def dashboard_vrp_name_matches?(expected, vrp)
    return true if expected.blank?

    [vrp_approval_label(vrp), vrp.name].compact.any? { |label| dashboard_value_matches?(expected, label) }
  end

  def approval_record_priority(record)
    [record.data["vrp_name"].present? ? 1 : 0, record.id]
  end

  def sidebar_module_names
    ApplicationHelper::SIDEBAR_SECTIONS.map { |section| section[:title] }
  end

  def sidebar_submodule_names
    ApplicationHelper::SIDEBAR_SECTIONS.flat_map { |section| section[:links].map(&:first) }
  end

  def generic_field_options(field)
    key = field.parameterize(separator: "_")
    candidate_keys = [
      key,
      "#{key}_name",
      "#{key}_title",
      "#{key}_code",
      key.delete_prefix("select_"),
      "#{key.delete_prefix('select_')}_name"
    ].uniq

    ModuleRecord
      .where.not(module_slug: @slug || current_slug)
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .flat_map { |record| candidate_keys.filter_map { |candidate| record.data[candidate].presence } }
      .uniq
  end

  def values_from_module(module_slug, field_key)
    return approver_options if module_slug == "new-user" && field_key == "approver_name_with_role"

    field_keys = [field_key]
    field_keys << "role_name" if module_slug == "role-management" && field_key == "role"
    field_keys << "activity_group_name" if module_slug == "add-activity-group" && field_key == "main_activity_name"
    field_keys << "vrp_activity_name" if module_slug == "add-vrp-activity" && field_key == "activity_name"
    field_keys.concat(["activity_name", "vrp_activity_name"]) if module_slug == "add-vrp-activity" && field_key == "sub_activity_name"

    ModuleRecord
      .where(module_slug: module_slug)
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .flat_map { |record| field_keys.filter_map { |key| record.data[key].presence } }
      .uniq
  end

  def approver_options
    user_options = []
    if model_ready?(:User)
      user_options = User.order(created_at: :desc).filter_map do |user|
        full_name = user.full_name.presence || user.user_name.presence
        next if full_name.blank?

        user.role.present? ? "#{full_name} (#{user.role})" : full_name
      end
    end

    return user_options.uniq if user_options.any?
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "new-user")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .filter_map do |record|
        full_name = [record.data["first_name"], record.data["last_name"]].compact_blank.join(" ").presence ||
          record.data["user_name"].presence
        role = record.data["role"].presence
        next if full_name.blank?

        role.present? ? "#{full_name} (#{role})" : full_name
      end
      .uniq
  end

  def active_module_record?(record)
    record.data["status"].blank? || record.data["status"] == "Active"
  end

  def sync_vrp_master_record(record)
    case record.module_slug
    when "bank-master"
      sync_bank_master(record)
    when "add-vrp-type"
      sync_vrp_type(record)
    end
  end

  def sync_bank_master(record)
    klass = "VrpBankMaster".safe_constantize
    return unless klass&.table_exists?

    name = record.data["bank_name"].to_s.strip
    return if name.blank?

    bank = klass.find_or_initialize_by(name: name)
    bank.is_active = record.data["status"].to_s != "Inactive" if bank.respond_to?(:is_active=)
    bank.is_deleted = false if bank.respond_to?(:is_deleted=)
    bank.save(validate: false)
  end

  def sync_vrp_type(record)
    klass = "VrpType".safe_constantize
    return unless klass&.table_exists?

    type_name = (record.data["position_type_name"].presence || record.data["vrp_type_name"]).to_s.strip
    return if type_name.blank?

    vrp_type = klass.find_or_initialize_by(type_name: type_name)
    vrp_type.is_active = record.data["status"].to_s != "Inactive" if vrp_type.respond_to?(:is_active=)
    vrp_type.is_deleted = false if vrp_type.respond_to?(:is_deleted=)
    vrp_type.save(validate: false)
  end

  def model_ready?(name)
    klass = name.to_s.safe_constantize
    klass.present? && (!klass.respond_to?(:table_exists?) || klass.table_exists?)
  end
end
