require "fileutils"
require "securerandom"
require "csv"

class ModulesController < ApplicationController
  helper_method :module_field_options, :module_select_field?, :static_field_options, :role_management_mappings,
                :access_control_role_mappings, :access_control_field_options,
                :location_hierarchy_mappings, :office_category_mappings, :training_target_mappings,
                :training_activity_mappings, :approval_user_mappings, :approval_user_options,
                :parent_office_mappings

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
      fields: ["State Name", "State Code", "District Name", "District Code", "Block Name", "Block Code", "Gram Name", "Gram Code", "Village Name", "Village Code"]
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
    "training-form" => {
      title: "ट्रेनिंग प्रपत्र",
      group: "Training",
      purpose: "VRP training details save karne ke liye.",
      fields: [
        "ICS / Block",
        "Gram Name",
        "Trainee Department",
        "Trainer Name",
        "Trainer Contact",
        "Training Date",
        "Training Location",
        "Department",
        "Training Topic",
        "Training Subject",
        "Training Description",
        "Farmer Count",
        "Male Count",
        "Female Count",
        "Next Farmer Training Date",
        "Training Register Upload",
        "Training Photo Upload with Geo Tag"
      ]
    },
    "training-form-list" => {
      title: "Training List",
      group: "Training",
      purpose: "Saved training records dekhne ke liye.",
      fields: [
        "ICS / Block",
        "Gram Name",
        "Trainer Name",
        "Training Date",
        "Training Location",
        "Training Topic",
        "Farmer Count",
        "Selected Farmers",
        "Male Count",
        "Female Count",
        "Next Farmer Training Date"
      ]
    },
    "training-topic-mapping" => {
      title: "Training Topic Mapping",
      group: "Training",
      purpose: "Department, training topic aur training subject mapping maintain karne ke liye.",
      fields: ["Department", "Training Topic", "Training Subject", "Status"]
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
      title: "Project Add",
      group: "Activity Setup",
      purpose: "Project details maintain karna.",
      fields: ["Project Name", "Status"]
    },
    "activity-master" => {
      title: "Activity Master",
      group: "Activity Master",
      purpose: "All activities maintain karna.",
      fields: ["Activity Name", "Status"]
    },
    "parent-office-add" => {
      title: "Parent Office Add",
      group: "Office Setup",
      purpose: "Parent office category maintain karne ke liye.",
      fields: ["Stakeholder Category", "Parent Office Type", "Parent Office", "Parent Office Name", "Office Level", "Status"]
    },
    "office-category-add" => {
      title: "Office Category Add",
      group: "Office Setup",
      purpose: "Office category aur office level maintain karne ke liye.",
      fields: ["Stakeholder Category", "Parent Category", "Office Name", "Office Level", "Status"]
    },
    "office-mapping-add" => {
      title: "Sub Office Add",
      group: "Office Setup",
      purpose: "Office name wise sub office maintain karne ke liye.",
      fields: ["Stakeholder Category", "Parent Category", "Office Name", "Sub Office Name", "Office Level", "Status"]
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
      fields: ["Module Name", "Stakeholder Name", "Approval Level", "Approver (Approved By)", "Status", "User Name"]
    },
    "approval-list" => {
      title: "VRP Approval List",
      group: "VRP Registration",
      purpose: "Saved approval mappings dekhne ke liye.",
      fields: ["Module Name", "Stakeholder Name", "Approval Level", "Approver (Approved By)", "Status", "User Name"]
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
      fields: ["Stakeholder Category", "Stakeholder Role", "Role", "User Management Role", "Person Type", "State", "District", "Block", "Gram Panchayat", "Village", "Office Name", "Sub Office Name", "Full Address", "Pincode", "First Name", "Last Name", "Gender", "Email", "Password", "Confirmed Password", "User Name", "Mobile No", "User Type", "Status"]
    },
    "all-user" => {
      title: "All User",
      group: "User Register",
      purpose: "Registered users dekhne ke liye.",
      fields: ["Stakeholder Category", "Stakeholder Role", "Role", "User Management Role", "Person Type", "State", "District", "Block", "Gram Panchayat", "Village", "Office Name", "Sub Office Name", "Full Address", "Pincode", "First Name", "Last Name", "Gender", "Email", "Password", "Confirmed Password", "User Name", "Mobile No", "User Type", "Status"]
    },
    "user-hierarchy-mapping" => {
      title: "User Hierarchy Mapping",
      group: "User Mapping",
      purpose: "Kis user ke under kaun user kaam karega map karne ke liye.",
      fields: ["Stakeholder Category", "Level 1 User", "Level 2 User", "Level 3 User", "Status"]
    },
    "stakeholder-role" => {
      title: "Stakeholder Person Type",
      group: "Stakeholder",
      purpose: "Stakeholder category wise stakeholder person type maintain karne ke liye.",
      fields: ["Stakeholder Category", "Office Name", "Stakeholder Role", "Status"]
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
    "training-form-list" => "training-form",
    "all-user" => "new-user"
  }.freeze

  def dashboard
    if vrp_login_user?
      prepare_vrp_dashboard
      return
    end

    @dashboard_title = admin_dashboard_user? ? "Admin Dashboard" : "User Dashboard"
    @dashboard_caption = admin_dashboard_user? ? "Live complete system summary." : "Live summary for your mapped records."
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
      redirect_to module_path(module_redirect_slug), notice: "#{@module[:title]} saved successfully."
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
      redirect_to module_path(module_redirect_slug), notice: "#{@module[:title]} updated successfully."
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
    redirect_to module_path(@slug), notice: "#{@module[:title]} deleted successfully.", status: :see_other
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
    if @slug == "lg-directory-list"
      result = LgDirectoryImporter.import(params[:file])
      counts = lg_directory_import_notice_counts(result[:counts])
      notice = "LG Directory uploaded successfully. #{result[:imported]} records created"
      notice = "#{notice} (#{counts})" if counts.present?
      redirect_to module_path(@slug), notice: "#{notice}."
      return
    end

    result = import_module_records(params[:file])
    redirect_to module_path(@slug), notice: "#{@module[:title]} uploaded successfully. #{result[:imported]} records created."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to module_path(@slug), alert: e.message
  end

  def export
    load_module!

    if @slug == "lg-directory-list"
      prepare_lg_directory_data
      csv_data = lg_directory_csv(@lg_directory_rows)
      filename = "lg_directory_all_list_#{Date.current}.csv"
    else
      csv_data = module_records_csv(module_records)
      filename = "#{record_source_slug.tr("-", "_")}_records_#{Date.current}.csv"
    end

    send_data csv_data,
      filename: filename,
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

      edit_record = lg_directory_edit_record(selected_records.first)
      redirect_to module_path(@slug), alert: "This LG Directory row cannot be edited from All List." and return unless edit_record

      redirect_to edit_module_record_path(edit_record.module_slug, edit_record)
    when "active", "inactive"
      next_status = params[:bulk_action] == "active" ? "Active" : "Inactive"
      records_to_update = lg_directory_matching_records(selected_records)
      records_to_update.each { |record| record.update!(data: record.data.merge("status" => next_status)) }
      redirect_to module_path(@slug), notice: "#{selected_records.size} LG Directory row(s) marked #{next_status}."
    when "delete"
      records_to_delete = lg_directory_matching_records(selected_records)
      records_to_delete.each(&:destroy!)
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

  def prepare_vrp_dashboard
    @vrp_dashboard = true
    @dashboard_generated_at = Time.current
    @vrp = current_vrp_record

    unless @vrp
      @dashboard_cards = []
      @vrp_target_rows = []
      @vrp_village_rows = []
      @vrp_farmer_followup = empty_vrp_farmer_followup
      return
    end

    mappings = vrp_dashboard_mappings(@vrp)
    targets = vrp_dashboard_targets(@vrp)
    bills = vrp_dashboard_bills(@vrp)
    farmer_followup = vrp_farmer_followup(mappings)
    mapped_farmer_count = vrp_mapped_farmer_count(mappings)
    village_count = mappings.map { |mapping| mapping.village_id.presence || mapping.village_name.presence }.compact.uniq.size
    main_activity_count = targets.map { |target| normalize_dashboard_text(target.main_activity_name) }.reject(&:blank?).uniq.size
    sub_activity_count = targets.map { |target| normalize_dashboard_text(target.activity_name) }.reject(&:blank?).uniq.size
    target_total = targets.sum { |target| target.target_quantity.to_f }
    completed_total = targets.sum { |target| vrp_target_completed_quantity(target, bills) }

    @dashboard_cards = [
      dashboard_card("Mapped Farmers", mapped_farmer_count, "Farmers mapped with your VRP profile", dashboard_path(anchor: "vrp_mapped_villages")),
      dashboard_card("Mapped Villages", village_count, "Villages assigned for field work", dashboard_path(anchor: "vrp_mapped_villages")),
      dashboard_card("Main Activities", main_activity_count, "Main activities mapped to your targets", target_mappings_path),
      dashboard_card("Sub Activities", sub_activity_count, "Sub activities mapped to your targets", target_mappings_path),
      dashboard_card("Repeat Farmers", farmer_followup[:repeat].size, "Worked in previous month and this month", dashboard_path(anchor: "vrp_farmer_followup")),
      dashboard_card("New Farmers", farmer_followup[:new].size, "Worked this month but not previous month", dashboard_path(anchor: "vrp_farmer_followup")),
      dashboard_card("Pending Farmers", farmer_followup[:pending].size, "Mapped farmers not covered this month", dashboard_path(anchor: "vrp_farmer_followup")),
      dashboard_card("Assigned Target", dashboard_quantity(target_total), "Total target from Target Mapping Master", target_mappings_path),
      dashboard_card("Completed", dashboard_quantity(completed_total), "#{percentage(completed_total, target_total)} target completed", dashboard_path(anchor: "vrp_target_progress"))
    ]

    @vrp_target_rows = targets.map do |target|
      completed = vrp_target_completed_quantity(target, bills)
      target_quantity = target.target_quantity.to_f
      pending = [target_quantity - completed, 0].max

      {
        month: target.month_name,
        fco: target.fco_name.presence || target.fco_id,
        ics: target.ics_name.presence || target.ics_id,
        village: target.village_name.presence || target.village_id,
        farmers: target.farmer_count,
        main_activity: target.main_activity_name,
        activity: target.activity_name,
        target: target_quantity,
        completed: completed,
        pending: pending,
        progress: percentage(completed, target_quantity)
      }
    end

    @vrp_village_rows = mappings.map do |mapping|
      village_targets = targets.select { |target| target.village_id.to_s == mapping.village_id.to_s }
      {
        fco: mapping.fco_name.presence || mapping.fco_id,
        ics: mapping.ics_name.presence || mapping.ics_id,
        village: mapping.village_name.presence || mapping.village_id,
        farmers: mapping.farmer_count,
        targets: village_targets.size,
        target_quantity: village_targets.sum { |target| target.target_quantity.to_f }
      }
    end

    @vrp_farmer_followup = farmer_followup
  end

  def vrp_login_user?
    current_app_user&.dig("record_type").to_s == "Vrp"
  end

  def current_vrp_record
    return unless model_ready?(:Vrp)

    @current_vrp_record ||= Vrp.find_by(id: current_app_user&.dig("id"))
  end

  def vrp_dashboard_mappings(vrp)
    return [] unless model_ready?(:VrpIcsMapping)

    VrpIcsMapping.where(vrp_id: vrp.id).order(:village_name, :id).to_a
  end

  def vrp_dashboard_targets(vrp)
    return [] unless model_ready?(:TargetMapping)

    TargetMapping.where(vrp_id: vrp.id).order(:month_name, :main_activity_name, :activity_name, :id).to_a
  end

  def vrp_dashboard_bills(vrp)
    return [] unless model_ready?(:ModuleRecord)

    labels = vrp_bill_match_labels(vrp)
    ModuleRecord.where(module_slug: "vrp-bill-add").order(created_at: :desc).select do |record|
      labels.include?(normalize_dashboard_text(record.data["select_vrp"]))
    end
  end

  def vrp_bill_match_labels(vrp)
    [
      vrp.id,
      vrp.name,
      vrp.user_name,
      vrp.mobile_no,
      [vrp.name, vrp.mobile_no.presence].compact_blank.join(" - ")
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?).uniq
  end

  def vrp_mapped_farmer_count(mappings)
    farmer_ids = mappings.flat_map { |mapping| Array(mapping.afl_ids).map(&:to_s) }.reject(&:blank?).uniq
    return farmer_ids.size if farmer_ids.any?

    mappings.sum(&:farmer_count)
  end

  def vrp_farmer_followup(mappings)
    mapped_farmer_ids = mappings.flat_map { |mapping| Array(mapping.afl_ids).map(&:to_s) }.reject(&:blank?).uniq
    return empty_vrp_farmer_followup if mapped_farmer_ids.blank? || !model_ready?(:Afl)

    farmers = Afl.where(id: mapped_farmer_ids).to_a
    work_dates = farmers.filter_map { |farmer| afl_work_date(farmer) }
    current_month = work_dates.max&.beginning_of_month || Date.current.beginning_of_month
    previous_month = current_month.prev_month
    mapped_farmer_keys = farmers.map { |farmer| farmer_identity_key(farmer) }.reject(&:blank?).uniq
    current_farmer_keys = farmers.select { |farmer| date_in_month?(afl_work_date(farmer), current_month) }.map { |farmer| farmer_identity_key(farmer) }.reject(&:blank?).uniq
    previous_farmer_keys = farmers.select { |farmer| date_in_month?(afl_work_date(farmer), previous_month) }.map { |farmer| farmer_identity_key(farmer) }.reject(&:blank?).uniq

    {
      current_month: current_month,
      previous_month: previous_month,
      repeat: farmer_rows_for_keys(current_farmer_keys & previous_farmer_keys, farmers),
      new: farmer_rows_for_keys(current_farmer_keys - previous_farmer_keys, farmers),
      pending: farmer_rows_for_keys(mapped_farmer_keys - current_farmer_keys, farmers)
    }
  end

  def empty_vrp_farmer_followup
    {
      current_month: Date.current.beginning_of_month,
      previous_month: Date.current.prev_month.beginning_of_month,
      repeat: [],
      new: [],
      pending: []
    }
  end

  def afl_work_date(afl)
    afl.purchase_date || afl.date || afl.qrcode_date&.to_date
  end

  def date_in_month?(date, month_start)
    return false unless date

    date >= month_start && date < month_start.next_month
  end

  def farmer_identity_key(farmer)
    farmer.tracenet_no.presence ||
      farmer.mobile_no.presence ||
      farmer.aadhar.presence ||
      [farmer.farmer_name, farmer.father_name, farmer.village_id].map { |value| normalize_dashboard_text(value) }.join("|")
  end

  def farmer_rows_for_keys(keys, farmers)
    farmer_by_key = farmers.group_by { |farmer| farmer_identity_key(farmer) }
    keys.filter_map do |key|
      farmer = farmer_by_key[key.to_s]&.max_by { |row| afl_work_date(row) || Date.new(1900, 1, 1) }
      next unless farmer

      {
        name: farmer.farmer_name.presence || "Farmer ##{farmer.id}",
        father_name: farmer.father_name,
        village: farmer.village_name.presence || farmer.village_id,
        mobile_no: farmer.mobile_no,
        tracenet_no: farmer.tracenet_no,
        work_date: afl_work_date(farmer)
      }
    end.sort_by { |row| [row[:village].to_s, row[:name].to_s] }
  end

  def vrp_target_completed_quantity(target, bills)
    relevant_bills = bills.select do |record|
      target.month_name.blank? || normalize_dashboard_text(record.data["select_bill_month"]) == normalize_dashboard_text(target.month_name)
    end

    relevant_bills.sum do |record|
      matching_items = vrp_bill_items(record).select do |item|
        normalize_dashboard_text(item["activity"]) == normalize_dashboard_text(target.activity_name)
      end

      if matching_items.any?
        matching_items.sum { |item| dashboard_numeric(item["no_of_unit"]) }
      elsif Array(record.data["select_activity_group"]).any? { |activity| normalize_dashboard_text(activity) == normalize_dashboard_text(target.main_activity_name) }
        dashboard_numeric(record.data["grand_units"])
      else
        0
      end
    end
  end

  def vrp_bill_items(record)
    raw_items = record.data["bill_items"]
    items = raw_items.is_a?(Hash) ? raw_items.values : Array(raw_items)
    items.select { |item| item.respond_to?(:[]) }
  end

  def dashboard_numeric(value)
    value.to_s.gsub(",", "").to_f
  end

  def dashboard_quantity(value)
    value = value.to_f
    value == value.to_i ? value.to_i : format("%.2f", value)
  end

  def normalize_dashboard_text(value)
    value.to_s.strip.downcase
  end

  def dashboard_cards
    vrps = dashboard_vrps
    targets = dashboard_target_mappings
    activities = module_records_for_dashboard("add-vrp-activity")
    hierarchy_summary = user_hierarchy_dashboard_summary
    approved_vrps = vrps.count { |vrp| vrp.status.to_i == 55 || vrp_approval_complete?(vrp) }
    pending_approvals = vrps.count { |vrp| vrp_approval_pending?(vrp) }

    cards = [
      dashboard_card("Total Registered VRP", vrps.size, admin_dashboard_user? ? "All VRP records saved in registration" : "VRP records visible to you", vrps_path),
      dashboard_card("Final Approved VRP", approved_vrps, "VRP records with final approval", vrps_path),
      dashboard_card("VRP Waiting for Approval", pending_approvals, "VRP records currently pending", approvals_vrps_path),
      dashboard_card("VRP Targets Assigned", targets.size, "Target records assigned in VRP Targets", target_mappings_path),
      dashboard_card("Activities Configured", activities.size, "Activities available for target and bill work", module_path("vrp-activity-list"))
    ]

    cards.insert(0, dashboard_card("Level 3 Users Under Level 1", hierarchy_summary[:level_3_total], "Level 3 users mapped below your Level 1 hierarchy", dashboard_path(anchor: "user_hierarchy_report"))) if hierarchy_summary[:level_3_total].positive?
    cards.insert(0, dashboard_card("Direct Level 2 Users", hierarchy_summary[:level_2_total], "Users directly mapped under you", dashboard_path(anchor: "user_hierarchy_report"))) if hierarchy_summary[:level_2_total].positive?

    cards
  end

  def dashboard_reports
    targets = dashboard_target_mappings
    hierarchy_summary = user_hierarchy_dashboard_summary

    reports = [
      {
        title: "VRP Target Summary",
        headers: ["Month", "Targets", "Target Quantity"],
        rows: dashboard_target_summary_rows(targets)
      },
      {
        title: "Live Clock",
        clock: true
      }
    ]

    reports.insert(0, user_hierarchy_dashboard_report(hierarchy_summary)) if hierarchy_summary[:total].positive?
    if admin_dashboard_user?
      reports.insert(0, vrp_assigned_target_report)
      reports.insert(0, vrp_declaration_acceptance_report)
    end
    reports
  end

  def dashboard_card(title, value, caption, path = nil)
    {
      title: title,
      value: value,
      caption: caption,
      path: path.presence || dashboard_path
    }
  end

  def user_hierarchy_dashboard_report(summary)
    {
      title: "User Hierarchy",
      dom_id: "user_hierarchy_report",
      headers: ["Group", "Level", "User", "Reports To"],
      rows: summary[:rows].presence || [["No mapped user", "-", "-", "-"]]
    }
  end

  def user_hierarchy_dashboard_summary
    @user_hierarchy_dashboard_summary ||= begin
      direct_rows, level_3_rows = user_hierarchy_dashboard_rows
      rows = direct_rows + level_3_rows
      {
        level_2_total: direct_rows.size,
        level_3_total: level_3_rows.size,
        total: rows.size,
        rows: rows
      }
    end
  end

  def user_hierarchy_dashboard_rows
    return [[], []] unless model_ready?(:ModuleRecord)

    current_labels = current_dashboard_user_labels
    return [[], []] if current_labels.blank?

    direct_rows = []
    level_3_rows = []
    ModuleRecord
      .where(module_slug: "user-hierarchy-mapping")
      .order(updated_at: :desc)
      .select { |record| active_module_record?(record) }
      .each do |record|
        level_1_user = record.data["level_1_user"].to_s.strip
        hierarchy_mappings_for_dashboard(record).each do |mapping|
          level_2_user = mapping["level_2_user"].to_s.strip
          level_3_users = Array(mapping["level_3_users"]).map(&:to_s).map(&:strip).reject(&:blank?)

          if dashboard_user_label_matches?(level_1_user, current_labels)
            direct_rows << ["Direct Level 2 Users", "Level 2", level_2_user, level_1_user] if level_2_user.present?
            level_3_users.each { |user| level_3_rows << ["Level 3 Users Under Level 1", "Level 3", user, level_2_user.presence || level_1_user] }
          elsif dashboard_user_label_matches?(level_2_user, current_labels)
            level_3_users.each { |user| level_3_rows << ["Level 3 Users Under Me", "Level 3", user, level_2_user] }
          end
        end
      end

    [
      direct_rows.reject { |row| row[2].blank? },
      level_3_rows.reject { |row| row[2].blank? }
    ]
  end

  def hierarchy_mappings_for_dashboard(record)
    raw_mappings = record.data["level_2_mappings"]
    raw_mappings = raw_mappings.values if raw_mappings.is_a?(Hash)
    mappings = Array(raw_mappings).filter_map do |mapping|
      mapping = mapping.to_h if mapping.respond_to?(:to_h)
      next unless mapping.is_a?(Hash)

      {
        "level_2_user" => mapping["level_2_user"],
        "level_3_users" => Array(mapping["level_3_users"]).flat_map { |value| value.to_s.split(",") }.map(&:strip).reject(&:blank?)
      }
    end

    return mappings if mappings.any?

    Array(record.data["level_2_users"].presence || record.data["level_2_user"]).flat_map { |value| value.to_s.split(",") }.map(&:strip).reject(&:blank?).map do |level_2_user|
      {
        "level_2_user" => level_2_user,
        "level_3_users" => Array(record.data["level_3_users"].presence || record.data["level_3_user"]).flat_map { |value| value.to_s.split(/[;,]/) }.map(&:strip).reject(&:blank?)
      }
    end
  end

  def current_dashboard_user_labels
    name = current_app_user&.dig("name").to_s.strip
    username = current_app_user&.dig("username").to_s.strip
    role = current_app_user&.dig("role").presence || current_app_user&.dig("role_name")

    [
      name,
      username,
      role.present? && name.present? ? "#{name} (#{role})" : nil,
      role.present? && username.present? ? "#{username} (#{role})" : nil
    ].compact_blank.uniq
  end

  def dashboard_user_label_matches?(stored_label, current_labels)
    stored_values = dashboard_user_label_match_values(stored_label)
    return false if stored_values.blank?

    current_labels.any? do |label|
      (stored_values & dashboard_user_label_match_values(label)).any?
    end
  end

  def dashboard_user_label_match_values(label)
    normalized = normalize_dashboard_user_label(label)
    base = normalize_dashboard_user_label(label.to_s.sub(/\s*\([^)]*\)\s*\z/, ""))

    [normalized, base].compact_blank.reject { |value| value.length < 3 }.uniq
  end

  def normalize_dashboard_user_label(label)
    label.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
  end

  def vrp_declaration_acceptance_report
    rows = if model_ready?(:Vrp) && Vrp.column_names.include?("agreement_accepted_at")
      Vrp.where.not(agreement_accepted_at: nil)
        .order(agreement_accepted_at: :desc)
        .limit(50)
        .map do |vrp|
          [
            vrp.name.presence || "-",
            vrp.user_name.presence || "-",
            vrp.mobile_no.presence || "-",
            vrp.email.presence || "-",
            vrp.agreement_accepted_at&.strftime("%d-%m-%Y %I:%M %p")
          ]
        end
    else
      []
    end

    {
      title: "VRP Declaration Accepted",
      headers: ["VRP", "Username", "Mobile", "Email", "Accepted At"],
      rows: rows.presence || [["No accepted declaration", "-", "-", "-", "-"]]
    }
  end

  def vrp_assigned_target_report
    rows = if model_ready?(:TargetMapping)
      TargetMapping.includes(:vrp)
        .order(updated_at: :desc)
        .limit(100)
        .map do |target|
          [
            target.vrp&.name.presence || "VRP ##{target.vrp_id}",
            target.month_name.presence || "-",
            target.village_name.presence || target.village_id.presence || "-",
            target.main_activity_name.presence || "-",
            target.activity_name.presence || "-",
            target.farmer_count,
            dashboard_quantity(target.target_quantity)
          ]
        end
    else
      []
    end

    {
      title: "VRP Target Assigned",
      headers: ["VRP", "Month", "Village", "Main Activity", "Sub Activity", "Farmers", "Target"],
      rows: rows.presence || [["No target assigned", "-", "-", "-", "-", "-", "-"]]
    }
  end

  def admin_dashboard_user?
    current_app_user&.dig("user_type").to_s.strip.casecmp("admin").zero?
  end

  def dashboard_vrps
    return [] unless model_ready?(:Vrp)
    return Vrp.all.to_a if current_app_user.blank? || current_app_user["user_type"].to_s.casecmp("admin").zero?

    (dashboard_own_vrps.to_a + dashboard_approval_related_vrps).uniq
  end

  def dashboard_target_mappings
    return [] unless model_ready?(:TargetMapping)

    scope = TargetMapping.includes(:vrp).order(updated_at: :desc)
    return scope.to_a if admin_dashboard_user?

    visible_vrp_ids = dashboard_vrps.map(&:id)
    return [] if visible_vrp_ids.blank?

    scope.where(vrp_id: visible_vrp_ids).to_a
  end

  def dashboard_target_summary_rows(targets)
    grouped = targets.group_by { |target| target.month_name.presence || "Not Set" }

    grouped.map do |month, rows|
      [
        month,
        rows.size,
        dashboard_quantity(rows.sum { |target| target.target_quantity.to_f })
      ]
    end.presence || [["No data", 0, 0]]
  end

  def dashboard_own_vrps
    ids = dashboard_current_app_user_ids
    emails = dashboard_current_app_user_emails
    return Vrp.none if ids.blank? && emails.blank?

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

    scope
  end

  def dashboard_approval_related_vrps
    return [] unless model_ready?(:Vrp)

    Vrp.all.select do |vrp|
      vrp_approval_sent?(vrp) && dashboard_current_user_in_approval_channel?(vrp)
    end
  end

  def dashboard_current_user_in_approval_channel?(vrp)
    current_labels = current_dashboard_user_labels
    return false if current_labels.blank?

    dashboard_approval_steps_for_visibility(vrp).any? do |step|
      dashboard_user_label_matches?(step.data["approver_approved_by"], current_labels)
    end
  end

  def dashboard_approval_steps_for_visibility(vrp)
    return [] unless model_ready?(:ModuleRecord)

    identities = vrp_creator_identities_for_dashboard(vrp)
    return [] if identities.blank?

    @dashboard_approval_visibility_steps ||= ModuleRecord.where(module_slug: "approval-master").order(created_at: :asc).to_a
    @dashboard_approval_visibility_steps
      .select do |record|
        record.data["status"].to_s != "Inactive" &&
          ["Farmer Registration", "VRP Registration"].include?(record.data["module_name"].to_s) &&
          dashboard_vrp_name_matches?(record.data["vrp_name"], vrp) &&
          identities.any? do |identity|
            dashboard_value_matches?(record.data["stakeholder_name"], identity[:stakeholder]) &&
              approval_identity_filters_match?(record, identity)
          end
      end
      .group_by { |record| vrp_approval_sequence(record) }
      .values
      .map { |records| records.max_by { |record| approval_record_priority(record) } }
      .sort_by { |record| vrp_approval_sequence(record) }
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
              approval_identity_filters_match?(record, identity)
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
      office: current_app_user&.dig("sub_office_name").presence || current_app_user&.dig("office"),
      office_category: current_app_user&.dig("office_category").presence || current_app_user&.dig("office_name"),
      user_name: current_app_user&.dig("username").presence || current_app_user&.dig("user_name")
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
      office: user.respond_to?(:sub_office_name) ? user.sub_office_name.presence || user.office : user.office,
      office_category: (user.respond_to?(:office_category) ? user.office_category : nil).presence || (user.respond_to?(:office_name) ? user.office_name : nil),
      user_name: user.user_name
    }
  end

  def record_dashboard_identity(record)
    {
      role: record.data["role"],
      stakeholder: record.data["stakeholder"],
      stakeholder_role: record.data["stakeholder_role"],
      user_management_role: record.data["user_management_role"],
      person_type: record.data["person_type"],
      office: record.data["sub_office_name"].presence || record.data["office"],
      office_category: record.data["office_category"].presence || record.data["office_name"],
      user_name: record.data["user_name"]
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

  def approval_identity_filters_match?(record, identity)
    approval_value_matches?(approval_record_office(record), identity[:office]) &&
      approval_value_matches?(record.data["office_category"], identity[:office_category]) &&
      approval_user_name_matches?(record.data["user_name"], identity[:user_name])
  end

  def approval_value_matches?(expected, actual)
    expected.blank? || actual.blank? || dashboard_value_matches?(expected, actual)
  end

  def approval_user_name_matches?(expected, actual)
    expected.blank? || (actual.present? && dashboard_value_matches?(expected, actual))
  end

  def approval_record_office(record)
    record.data["sub_office_name"].presence || record.data["office"]
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
    @lg_directory_filter = params[:table].presence_in(lg_directory_filter_fields) || "State Name"
    @lg_directory_query = params[:q].to_s.strip
    @lg_directory_rows = filtered_lg_directory_rows(lg_directory_rows)
  end

  def filtered_lg_directory_rows(rows)
    return rows if @lg_directory_query.blank?

    key = lg_directory_filter_key(@lg_directory_filter)
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
    rows.concat(lg_rows_from_records("lg-directory-list",
      state: "state_name",
      district: "district_name",
      sub_district: "sub_district_name",
      block: "cd_block_name",
      block_code: "cd_block_code",
      village: "village_name"))
    state_codes = lg_directory_code_lookup(rows, :state, :state_code)
    district_codes = lg_directory_code_lookup(rows, :district, :district_code)
    block_codes = lg_directory_code_lookup(rows, :block, :block_code)
    gp_codes = lg_directory_code_lookup(rows, :gram_panchayat, :gp_code)

    compact_lg_directory_rows(rows)
      .map do |row|
        row.merge(
          state_code: row[:state_code].presence || state_codes[row[:state].to_s.strip.downcase],
          district_code: row[:district_code].presence || district_codes[row[:district].to_s.strip.downcase],
          block_code: row[:block_code].presence || block_codes[row[:block].to_s.strip.downcase],
          gp_code: row[:gp_code].presence || gp_codes[row[:gram_panchayat].to_s.strip.downcase]
        )
      end
      .uniq { |row| lg_directory_row_key(row) }
      .sort_by { |row| [row[:state], row[:district], row[:sub_district], row[:block], row[:gram_panchayat], row[:village]].map(&:to_s) }
  end

  def lg_rows_from_records(module_slug, aliases)
    ModuleRecord
      .where(module_slug: module_slug)
      .order(created_at: :desc)
      .map { |record| lg_directory_row_from_record(record, aliases) }
  end

  def lg_directory_row_from_record(record, aliases = {})
    normalize_lg_gram_fields(
      record_id: record.id,
      source_slug: record.module_slug,
      state: record.data["state"].presence || record.data[aliases[:state].to_s].presence,
      state_code: record.data["state_code"].presence || record.data[aliases[:state_code].to_s].presence,
      district: record.data["district"].presence || record.data[aliases[:district].to_s].presence,
      district_code: record.data["district_code"].presence || record.data[aliases[:district_code].to_s].presence,
      sub_district: record.data["sub_district"].presence || record.data[aliases[:sub_district].to_s].presence,
      sub_district_code: record.data["sub_district_code"].presence || record.data[aliases[:sub_district_code].to_s].presence,
      block: record.data["block"].presence || record.data[aliases[:block].to_s].presence,
      block_code: record.data["block_code"].presence || record.data[aliases[:block_code].to_s].presence,
      gram_panchayat: record.data["gram_panchayat"].presence || record.data[aliases[:gram_panchayat].to_s].presence,
      gp_code: record.data["gp_code"].presence || record.data[aliases[:gp_code].to_s].presence,
      village: record.data["village"].presence || record.data[aliases[:village].to_s].presence,
      village_code: record.data["village_code"].presence || record.data[aliases[:village_code].to_s].presence,
      status: record.data["status"].presence || "Active"
    )
  end

  def normalize_lg_gram_fields(row)
    gram_name = row[:gram_panchayat].to_s.strip
    gram_code = row[:gp_code].to_s.strip
    if code_like_location_value?(gram_name) && gram_code.present? && !code_like_location_value?(gram_code)
      row.merge(gram_panchayat: gram_code, gp_code: gram_name)
    else
      row
    end
  end

  def lg_directory_aliases_for_slug(module_slug)
    {
      "lg-directory-list" => {
        state: "state_name",
        district: "district_name",
        sub_district: "sub_district_name",
        block: "cd_block_name",
        block_code: "cd_block_code",
        village: "village_name"
      },
      "village-master" => { village: "village_name" },
      "gram-panchayat-master" => { gram_panchayat: "gram_panchayat_name" },
      "block-master" => { block: "block_name" },
      "district-master" => { district: "district_name" },
      "state-master" => { state: "state_name" }
    }.fetch(module_slug, {})
  end

  def lg_directory_matching_records(records)
    row_keys = records.map do |record|
      lg_directory_row_key(lg_directory_row_from_record(record, lg_directory_aliases_for_slug(record.module_slug)))
    end.uniq

    ModuleRecord
      .where(module_slug: lg_directory_allowed_slugs)
      .select do |record|
        row_keys.include?(lg_directory_row_key(lg_directory_row_from_record(record, lg_directory_aliases_for_slug(record.module_slug))))
      end
  end

  def lg_directory_edit_record(record)
    records = lg_directory_matching_records([record])
    preferred_slugs = ["village-master", "gram-panchayat-master", "block-master", "district-master", "state-master"]

    records
      .select { |candidate| preferred_slugs.include?(candidate.module_slug) }
      .min_by { |candidate| preferred_slugs.index(candidate.module_slug) }
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
    levels = [:state, :district, :sub_district, :block, :gram_panchayat, :village]
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
    [:state_code, :state, :district_code, :district, :sub_district_code, :sub_district, :block_code, :block, :gp_code, :gram_panchayat, :village_code, :village]
      .map { |key| row[key].to_s.strip.downcase }
      .join("|")
  end

  def lg_directory_filter_fields
    ["State Name", "State Code", "District Name", "District Code", "Block Name", "Block Code", "Gram Name", "Gram Code", "Village Name", "Village Code"]
  end

  def lg_directory_filter_key(field)
    {
      "State Name" => :state,
      "State Code" => :state_code,
      "District Name" => :district,
      "District Code" => :district_code,
      "Block Name" => :block,
      "Block Code" => :block_code,
      "Gram Name" => :gram_panchayat,
      "Gram Code" => :gp_code,
      "Village Name" => :village,
      "Village Code" => :village_code
    }.fetch(field, :state)
  end

  def lg_directory_import_notice_counts(counts)
    {
      "lg-directory-list" => "All List",
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
    Array(params[:row_tokens]).filter_map do |token|
      slug, id = token.to_s.split(":", 2)
      next unless lg_directory_allowed_slugs.include?(slug) && id.present?

      ModuleRecord.where(module_slug: slug).find_by(id: id)
    end.uniq
  end

  def lg_directory_allowed_slugs
    [
      "lg-directory-list",
      "state-master",
      "district-master",
      "block-master",
      "gram-panchayat-master",
      "village-master"
    ]
  end

  def lg_directory_csv(rows)
    CSV.generate(headers: true) do |csv|
      csv << ["State Name", "State Code", "District Name", "District Code", "Block Name", "Block Code", "Gram Name", "Gram Code", "Village Name", "Village Code"]
      rows.each do |row|
        csv << [
          row[:state],
          row[:state_code],
          row[:district],
          row[:district_code],
          row[:block],
          row[:block_code],
          row[:gram_panchayat],
          row[:gp_code],
          row[:village],
          row[:village_code]
        ]
      end
    end
  end

  def module_records_csv(records)
    fields = @module[:fields]
    field_keys = fields.map { |field| field.parameterize(separator: "_") }

    CSV.generate(headers: true) do |csv|
      csv << fields
      records.each do |record|
        csv << field_keys.map { |key| record.data[key].to_s }
      end
    end
  end

  def import_module_records(file)
    raise ArgumentError, "Please choose an Excel or CSV file." unless file.present?
    raise ArgumentError, "Import is not available for this module." unless @module.present?

    rows = LgDirectoryImporter.rows_from_upload(file).map { |row| Array(row).map { |cell| cell.to_s.strip } }
    rows.reject! { |row| row.all?(&:blank?) }
    raise ArgumentError, "No rows found in uploaded file." if rows.blank?

    headers = rows.shift
    header_keys = headers.map { |header| module_import_header_key(header) }
    raise ArgumentError, "No matching headers found. Use: #{@module[:fields].join(", ")}." if header_keys.compact.blank?

    imported = 0
    rows.each do |row|
      data = {}
      header_keys.each_with_index do |key, index|
        next if key.blank?

        data[key] = row[index].to_s.strip
      end
      data.compact_blank!
      next if data.blank?

      data["status"] = "Active" if @module[:fields].include?("Status") && data["status"].blank?
      ModuleRecord.create!(module_slug: @slug, data: data)
      imported += 1
    end

    raise ArgumentError, "No valid records found in uploaded file." if imported.zero?

    { imported: imported }
  end

  def module_import_header_key(header)
    normalized_header = normalized_import_header(header)
    field = @module[:fields].find do |candidate|
      normalized_import_header(candidate) == normalized_header ||
        normalized_import_header(helpers.resource_person_label(candidate)) == normalized_header
    end
    field&.parameterize(separator: "_")
  end

  def normalized_import_header(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, "")
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

  def module_redirect_slug
    {
      "training-form" => "training-form-list",
      "vrp-bill-add" => "vrp-bill-list"
    }.fetch(record_source_slug, @slug)
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

    if record_source_slug == "user-hierarchy-mapping"
      level_2_mappings = normalize_user_hierarchy_mappings(data)
      level_2_users = level_2_mappings.filter_map { |mapping| mapping["level_2_user"].presence }.uniq
      level_3_users = level_2_mappings.flat_map { |mapping| mapping["level_3_users"] }.uniq

      data["level_2_mappings"] = level_2_mappings
      data["level_2_users"] = level_2_users
      data["level_2_user"] = level_2_users.join(", ")
      data["level_3_users"] = level_3_users
      data["level_3_user"] = level_2_mappings.filter_map do |mapping|
        next if mapping["level_2_user"].blank? || mapping["level_3_users"].blank?

        "#{mapping["level_2_user"]} -> #{mapping["level_3_users"].join(", ")}"
      end.join("; ")
      data["status"] = data["status"].presence || "Active"
    end

    if record_source_slug == "parent-office-add"
      data["parent_office_type"] = data["parent_office_type"].presence || (data["parent_office"].present? ? "Sub Parent Office" : "Parent Office")
      data["parent_office"] = "" if data["parent_office_type"] == "Parent Office"
    end

    data = normalize_training_form_data(data) if record_source_slug == "training-form"

    data
  end

  def normalize_training_form_data(data)
    trainer_name, trainer_contact = training_trainer_defaults
    data["trainer_name"] = trainer_name if trainer_name.present?
    data["trainer_contact"] = trainer_contact if trainer_contact.present?

    selected_farmer_ids = Array(data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?).uniq
    data["selected_farmer_ids"] = selected_farmer_ids
    data["selected_farmer_names"] = training_farmer_names(selected_farmer_ids)
    data["farmer_count"] = selected_farmer_ids.size.to_s if selected_farmer_ids.any?
    data.delete("status")
    data
  end

  def training_trainer_defaults
    if vrp_login_user? && current_vrp_record.present?
      return [current_vrp_record.name, current_vrp_record.mobile_no]
    end

    [current_app_user&.dig("name"), current_app_user&.dig("mobile_no")]
  end

  def training_farmer_names(farmer_ids)
    return [] if farmer_ids.blank? || !model_ready?(:Afl)

    Afl.where(id: farmer_ids)
      .order(:farmer_name, :id)
      .map { |farmer| farmer.farmer_name.presence || "Farmer ##{farmer.id}" }
  end

  def normalize_user_hierarchy_mappings(data)
    raw_mappings = data["level_2_mappings"]
    raw_mappings = raw_mappings.values if raw_mappings.is_a?(Hash)
    raw_mappings = Array(raw_mappings)

    mappings = raw_mappings.filter_map do |mapping|
      mapping = mapping.to_h if mapping.respond_to?(:to_h)
      next unless mapping.is_a?(Hash)

      level_2_user = mapping["level_2_user"].to_s.strip
      level_3_users = Array(mapping["level_3_users"]).flat_map { |value| value.to_s.split(",") }.map(&:strip).reject(&:blank?).uniq
      next if level_2_user.blank? && level_3_users.blank?

      {
        "level_2_user" => level_2_user,
        "level_3_users" => level_3_users
      }
    end

    return mappings if mappings.any?

    Array(data["level_2_users"]).map { |value| value.to_s.strip }.reject(&:blank?).uniq.map do |level_2_user|
      {
        "level_2_user" => level_2_user,
        "level_3_users" => []
      }
    end
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
    return false if current_slug == "training-topic-mapping" && ["Department", "Training Topic", "Training Subject"].include?(field)
    return true if current_slug == "parent-office-add" && field == "Parent Office"
    return true if training_target_field?(field)
    return true if training_activity_field?(field)

    source = field_sources[field]
    (source.present? && source[:module] != (@slug || current_slug)) || static_field_options(field).any?
  end

  def module_field_options(field)
    return parent_office_parent_options if current_slug == "parent-office-add" && field == "Parent Office"
    return training_target_field_options(field) if training_target_field?(field)
    return training_activity_field_options(field) if training_activity_field?(field)

    source = field_sources[field]
    return [] unless ModuleRecord.table_exists?

    if source
      return [] if source[:module] == (@slug || current_slug)

      return values_from_module(source[:module], source[:field])
    end

    generic_field_options(field)
  end

  def training_target_field?(field)
    record_source_slug == "training-form" && ["ICS / Block", "Gram Name"].include?(field)
  end

  def training_activity_field?(field)
    record_source_slug == "training-form" && ["Department", "Training Topic", "Training Subject"].include?(field)
  end

  def training_target_field_options(field)
    case field
    when "ICS / Block"
      training_target_mappings.filter_map { |mapping| mapping[:ics].presence }.uniq
    when "Gram Name"
      training_target_mappings.filter_map { |mapping| mapping[:village].presence }.uniq
    else
      []
    end
  end

  def training_activity_field_options(field)
    case field
    when "Department"
      training_activity_mappings.filter_map { |mapping| mapping[:department].presence }.uniq
    when "Training Topic"
      training_activity_mappings.filter_map { |mapping| mapping[:training_topic].presence }.uniq
    when "Training Subject"
      training_activity_mappings.filter_map { |mapping| mapping[:training_subject].presence }.uniq
    else
      []
    end
  end

  def training_activity_mappings
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "training-topic-mapping")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .map do |record|
        {
          department: first_present_data(record, "department", "trainee_department").to_s.strip,
          training_topic: first_present_data(record, "training_topic", "topic").to_s.strip,
          training_subject: first_present_data(record, "training_subject", "subject").to_s.strip
        }
      end
      .reject { |mapping| mapping.values.all?(&:blank?) }
      .uniq
  end

  def training_target_mappings
    return [] unless model_ready?(:TargetMapping)

    scope = TargetMapping.all
    scope = scope.where(vrp_id: current_vrp_record.id) if vrp_login_user? && current_vrp_record.present?

    scope
      .order(:ics_name, :ics_id, :village_name, :village_id, :id)
      .map do |target|
        mapping = target.vrp_ics_mapping
        {
          ics: target.ics_name.presence || target.ics_id,
          village: target.village_name.presence || target.village_id,
          farmers: training_farmers_for_mapping(mapping)
        }
      end
      .reject { |mapping| mapping[:ics].blank? && mapping[:village].blank? }
      .uniq
  end

  def training_farmers_for_mapping(mapping)
    return [] unless mapping && model_ready?(:Afl)

    farmer_ids = Array(mapping.afl_ids).map(&:to_s).reject(&:blank?).uniq
    return [] if farmer_ids.blank?

    Afl.where(id: farmer_ids)
      .order(:farmer_name, :id)
      .map do |farmer|
        {
          id: farmer.id.to_s,
          farmer_name: farmer.farmer_name.presence || "Farmer ##{farmer.id}",
          father_name: farmer.father_name,
          tracenet_no: farmer.tracenet_no,
          mobile_no: farmer.mobile_no,
          khasara_no: farmer.khasara_no
        }
      end
  end

  def role_management_mappings
    return [] unless model_ready?(:ModuleRecord)

    stakeholder_role_mappings = ModuleRecord
      .where(module_slug: "stakeholder-role")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .flat_map do |record|
        stakeholder_role = first_present_data(record, "stakeholder_role").to_s.strip
        parent_office = first_present_data(record, "parent_office", "parent_category", "office_name", "office").to_s.strip
        office_name = first_present_data(record, "office_name", "office").to_s.strip
        mapping_labels_for_option(stakeholder_role, :stakeholder_role).map do |stakeholder_role_label|
          {
            stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
            stakeholder_role: stakeholder_role,
            stakeholder_role_label: stakeholder_role_label,
            parent_office: parent_office,
            office_category: parent_office,
            office_name: office_name,
            office: office_name,
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
        gram_panchayat: gram_panchayat_name_from_record(record))
    end

    villages = active_records_for_location("village-master").map do |record|
      location_row(record,
        state: first_present_data(record, "state"),
        district: first_present_data(record, "district"),
        block: first_present_data(record, "block"),
        gram_panchayat: first_present_data(record, "gram_panchayat"),
        village: first_present_data(record, "village_name"))
    end

    lg_directory_rows = active_records_for_location("lg-directory-list").map do |record|
      location_row(record,
        state: first_present_data(record, "state", "state_name"),
        district: first_present_data(record, "district", "district_name"),
        block: first_present_data(record, "block", "cd_block_name"),
        gram_panchayat: gram_panchayat_name_from_record(record),
        village: first_present_data(record, "village", "village_name"))
    end

    states + districts + blocks + gram_panchayats + villages + lg_directory_rows
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

  def gram_panchayat_name_from_record(record)
    first_non_code_data(record, "gram_panchayat_name", "gram_panchayat", "gp_name", "gram_name", "name", "gp_code")
  end

  def first_non_code_data(record, *keys)
    keys.filter_map { |key| record.data[key].to_s.strip.presence }.find { |value| !code_like_location_value?(value) }
  end

  def code_like_location_value?(value)
    value.to_s.strip.match?(/\A[\d\s.\/-]+\z/)
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
      "Parent Office Type" => ["Parent Office", "Sub Parent Office"],
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
      "ICS / Block" => { module: "block-master", field: "block_name" },
      "Gram Panchayat" => { module: "gram-panchayat-master", field: "gram_panchayat_name" },
      "Gram Name" => { module: "gram-panchayat-master", field: "gram_panchayat_name" },
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
      "Parent Office" => { module: "parent-office-add", field: "parent_office_name" },
      "Parent Category" => { module: "parent-office-add", field: "parent_office_name" },
      "Office Category" => { module: "office-category-add", field: "office_name" },
      "Office Name" => { module: "office-category-add", field: "office_name" },
      "Office" => { module: "office-category-add", field: "office_name" },
      "Sub Office Name" => { module: "office-mapping-add", field: "sub_office_name" },
      "Approver (Approved By)" => { module: "new-user", field: "approver_name_with_role" },
      "Level 1 User" => { module: "new-user", field: "approver_name_with_role" },
      "Level 2 User" => { module: "new-user", field: "approver_name_with_role" },
      "Level 3 User" => { module: "new-user", field: "approver_name_with_role" },
      "Select Financial Year" => { module: "month-master", field: "financial_year" },
      "Select Bill Month" => { module: "month-master", field: "month_name" },
      "Month" => { module: "month-master", field: "month_name" },
      "ICS" => { module: "ics-master", field: "ics_name" },
      "Select ICS" => { module: "ics-master", field: "ics_name" },
      "Activity" => { module: "add-vrp-activity", field: "activity_name" },
      "Select Activity" => { module: "add-vrp-activity", field: "activity_name" },
      "Sub Activity Name" => { module: "add-vrp-activity", field: "sub_activity_name" },
      "Trainee Department" => { module: "office-category-add", field: "office_name" },
      "Department" => { module: "office-category-add", field: "office_name" },
      "Training Topic" => { module: "add-activity-group", field: "main_activity_name" },
      "Training Subject" => { module: "add-vrp-activity", field: "sub_activity_name" },
      "Task Indicator" => { module: "task-indicator-master", field: "task_indicator_name" },
      "Select Task Indicator" => { module: "task-indicator-master", field: "task_indicator_name" },
      "Bank Name" => { module: "bank-master", field: "bank_name" },
      "Role" => { module: "role-name", field: "role_name" },
      "Role Name" => { module: "role-name", field: "role_name" },
      "User Management Role" => { module: "user-management-role", field: "user_management_role" },
      "Person Type" => { module: "person-type", field: "person_type" },
      "Project Name" => { module: "project-master", field: "project_name" }
    }
  end

  def office_category_mappings
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: ["office-category-add", "office-mapping-add"])
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .map do |record|
        office_category = first_present_data(record, "office_category", "category_name")
        office_name = first_present_data(record, "office_name", "office")
        if record.module_slug == "office-category-add"
          office_category = office_name if office_category.blank?
          office_name = ""
        elsif record.module_slug == "office-mapping-add"
          office_category = office_name if office_category.blank?
          office_name = first_present_data(record, "sub_office_name", "office_mapping", "office").to_s.strip
        end

        {
          stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
          parent_office: first_present_data(record, "parent_category", "parent_office", "parent_office_name").to_s.strip,
          office_category: office_category.to_s.strip,
          office_name: office_name.to_s.strip,
          office: office_name.presence || office_category.to_s.strip,
          office_level: first_present_data(record, "office_level").to_s.strip
        }
      end
      .reject { |mapping| mapping[:office_category].blank? && mapping[:office_name].blank? }
      .uniq
  end

  def parent_office_mappings
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "parent-office-add")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .filter_map do |record|
        name = first_present_data(record, "parent_office_name", "parent_category").to_s.strip
        next if name.blank?

        parent_office = first_present_data(record, "parent_office").to_s.strip
        parent_office_type = first_present_data(record, "parent_office_type").to_s.strip
        parent_office_type = parent_office.present? ? "Sub Parent Office" : "Parent Office" if parent_office_type.blank?

        {
          stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
          parent_office_name: name,
          parent_office_type: parent_office_type,
          parent_office: parent_office,
          office_level: first_present_data(record, "office_level").to_s.strip
        }
      end
      .uniq
  end

  def parent_office_parent_options
    parent_office_mappings
      .filter_map { |mapping| mapping[:parent_office_name].presence }
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
    [(record.data["user_name"].present? || record.data["vrp_name"].present?) ? 1 : 0, record.id]
  end

  def approval_user_options
    approval_user_mappings.map { |mapping| mapping.slice(:value, :label) }.uniq
  end

  def approval_user_mappings
    @approval_user_mappings ||= begin
      mappings = []

      if model_ready?(:ModuleRecord)
        mappings.concat(
          ModuleRecord
            .where(module_slug: "new-user")
            .order(created_at: :desc)
            .select { |record| active_module_record?(record) }
            .filter_map { |record| approval_user_mapping_from_data(record.data) }
        )
      end

      if model_ready?(:User)
        mappings.concat(
          User.order(:user_name, :id).filter_map { |user| approval_user_mapping_from_user(user) }
        )
      end

      mappings.uniq { |mapping| [mapping[:value], mapping[:label], mapping[:office_category], mapping[:office_name]] }
    end
  end

  def approval_user_mapping_from_data(data)
    username = data["user_name"].to_s.strip
    return if username.blank?

    role = data["role"].presence || data["role_name"].presence
    {
      value: username,
      label: approval_user_label(username, role),
      stakeholder: data["stakeholder"].presence || data["stakeholder_name"].presence || data["stakeholder_category"].to_s.strip,
      office_category: data["office_category"].presence || data["office_name"].to_s.strip,
      office_name: data["sub_office_name"].presence || data["office"].to_s.strip,
      office: data["sub_office_name"].presence || data["office"].to_s.strip
    }
  end

  def approval_user_mapping_from_user(user)
    username = user.user_name.to_s.strip
    return if username.blank?

    role = (user.respond_to?(:role) ? user.role : nil).presence ||
      (user.respond_to?(:role_name) ? user.role_name : nil).presence
    office_category = (user.respond_to?(:office_category) ? user.office_category : nil).presence ||
      (user.respond_to?(:office_name) ? user.office_name.to_s.strip : "")
    office_name = user.respond_to?(:sub_office_name) ? user.sub_office_name.presence : nil
    office_name ||= user.respond_to?(:office) ? user.office.to_s.strip : ""
    {
      value: username,
      label: approval_user_label(username, role),
      stakeholder: user.respond_to?(:stakeholder) ? user.stakeholder.to_s.strip : "",
      office_category: office_category,
      office_name: office_name,
      office: office_name
    }
  end

  def approval_user_label(username, role)
    role.present? ? "#{username}(#{role})" : username
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
    if module_slug == "gram-panchayat-master" && field_key == "gram_panchayat_name"
      return ModuleRecord
        .where(module_slug: module_slug)
        .order(created_at: :desc)
        .select { |record| active_module_record?(record) }
        .filter_map { |record| gram_panchayat_name_from_record(record) }
        .uniq
    end

    field_keys = [field_key]
    field_keys << "role_name" if module_slug == "role-management" && field_key == "role"
    field_keys << "activity_group_name" if module_slug == "add-activity-group" && field_key == "main_activity_name"
    field_keys << "vrp_activity_name" if module_slug == "add-vrp-activity" && field_key == "activity_name"
    field_keys.concat(["activity_name", "vrp_activity_name"]) if module_slug == "add-vrp-activity" && field_key == "sub_activity_name"
    field_keys << "category_name" if module_slug == "office-category-add" && field_key == "office_name"

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
    return false if truthy_module_flag?(record.data["deleted"]) ||
      truthy_module_flag?(record.data["is_deleted"]) ||
      truthy_module_flag?(record.data["discarded"])

    status = record.data["status"].to_s.strip
    return true if status.blank?

    status.casecmp("Active").zero?
  end

  def truthy_module_flag?(value)
    ["1", "true", "yes", "deleted"].include?(value.to_s.strip.downcase)
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
