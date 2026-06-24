require "fileutils"
require "securerandom"
require "csv"

class ModulesController < ApplicationController
  helper_method :module_field_options, :module_select_field?, :static_field_options, :role_management_mappings,
                :access_control_role_mappings, :access_control_field_options,
                :location_hierarchy_mappings, :office_category_mappings, :training_target_mappings,
                :training_activity_setup_mappings, :training_target_month_options,
                :training_activity_mappings, :approval_user_mappings, :approval_user_options,
                :parent_office_mappings, :user_hierarchy_list_rows, :jeevika_jankar_cluster_rows,
                :jeevika_bill_status_label, :jeevika_bill_status_class, :jeevika_bill_rows,
                :jeevika_bill_detail_rows, :jeevika_bill_current_approval_step,
                :jeevika_bill_approval_history, :jeevika_bill_current_approver?,
                :jeevika_bill_approval_steps, :jeevika_bill_summary,
                :jeevika_bill_attachment_rows, :jeevika_jankar_display_name,
                :jeevika_jankar_vrp_label, :jeevika_bill_time_slot_rows,
                :jeevika_bill_description_rows, :jeevika_bill_bank_rows,
                :jeevika_bill_prepared_by, :jeevika_bill_approved_by_rows,
                :jeevika_bill_vrp, :bill_display_date, :bill_display_datetime,
                :approval_sequence_from_level, :module_record_field_value,
                :approval_level_display_label, :approval_level_label_for_sequence,
                :training_participation_status_label, :training_participation_status_caption,
                :training_target_status_label, :training_target_status_caption,
                :training_trainee_department_default, :seed_distribution_target_mappings,
                :seed_distribution_target_month_options

  APPROVAL_REGISTRATION_MODULES = ["Farmer Registration", "VRP Registration", "Jeevika Jankar Registration"].freeze
  OTHER_TARGET_MODULE_SLUGS = ["seed-distribution-target", "papl360-target"].freeze
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
      title: "Farmer Training Form",
      group: "Farmer Target",
      purpose: "Farmer target details save karne ke liye.",
      fields: [
        "Month",
        "ICS / Block",
        "Gram Name",
        "Trainee Department",
        "Trainer Name",
        "Trainer Contact",
        "Training Date",
        "Training Location",
        "Main Activity",
        "Sub Activity",
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
      title: "Farmer Training Form List",
      group: "Farmer Target",
      purpose: "Saved farmer target records dekhne ke liye.",
      fields: [
        "Month",
        "ICS / Block",
        "Gram Name",
        "Trainer Name",
        "Training Date",
        "Training Location",
        "Main Activity",
        "Sub Activity",
        "Farmer Count",
        "Selected Farmers",
        "Male Count",
        "Female Count",
        "Next Farmer Training Date"
      ]
    },
    "seed-distribution-target" => {
      title: "Seed Distribution Target",
      group: "Farmer Target",
      purpose: "Other activity ke seed distribution target aur achievement save karne ke liye.",
      fields: [
        "Jeevika Jankar Name",
        "Contact Number",
        "Department",
        "Month",
        "ICS",
        "Village",
        "Main Activity",
        "Sub Activity",
        "Completion Date",
        "Farmer Count",
        "Target",
        "Achievement",
        "Attachment Upload"
      ]
    },
    "seed-distribution-target-list" => {
      title: "Seed Distribution Target List",
      group: "Farmer Target",
      purpose: "Saved seed distribution target records dekhne ke liye.",
      fields: [
        "Jeevika Jankar Name",
        "Contact Number",
        "Department",
        "Month",
        "ICS",
        "Village",
        "Main Activity",
        "Sub Activity",
        "Farmer Count",
        "Target",
        "Achievement",
        "Attachment Upload",
        "Status"
      ]
    },
    "papl360-target" => {
      title: "PAPL360 Target",
      group: "Farmer Target",
      purpose: "Other activity ke PAPL360 target aur achievement save karne ke liye.",
      fields: [
        "Jeevika Jankar Name",
        "Contact Number",
        "Department",
        "Month",
        "ICS",
        "Village",
        "Main Activity",
        "Sub Activity",
        "Completion Date",
        "Target",
        "Achievement",
        "Excel Upload",
        "Attachment Upload"
      ]
    },
    "papl360-target-list" => {
      title: "PAPL360 Target List",
      group: "Farmer Target",
      purpose: "Saved PAPL360 target records dekhne ke liye.",
      fields: [
        "Jeevika Jankar Name",
        "Contact Number",
        "Department",
        "Month",
        "ICS",
        "Village",
        "Main Activity",
        "Sub Activity",
        "Target",
        "Achievement",
        "Excel Upload",
        "Attachment Upload",
        "Status"
      ]
    },
    "training-topic-mapping" => {
      title: "Farmer Training Topic Mapping",
      group: "Farmer Training",
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
      title: "Add Jeevika Jankar Type",
      group: "Stakeholder",
      purpose: "Jeevika Jankar type add karne ke liye.",
      fields: ["Jeevika Jankar Type Name", "Status"]
    },
    "add-activity-group" => {
      title: "Main Activity",
      group: "Activity Setup",
      purpose: "Main activity add karne ke liye.",
      fields: ["Main Activity Name", "Main Activity Type", "Achievement Fill", "Status"]
    },
    "activity-group-list" => {
      title: "Main Activity List",
      group: "Activity Setup",
      purpose: "Saved main activities dekhne ke liye.",
      fields: ["Main Activity Name", "Main Activity Type", "Achievement Fill", "Status"]
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
    "jeevika-jankar-bill-process" => {
      title: "Jeevika Jankar Bill Process",
      group: "Jeevika Jankar Bill",
      purpose: "Approved VRP ke target, achievement, farmer training aur invoice wise timesheet generate karne ke liye.",
      fields: ["Jeevika Jankar Name", "Bill Month", "Total Target", "Total Achievement"]
    },
    "jeevika-jankar-bill-list" => {
      title: "Jeevika Jankar Bill List",
      group: "Jeevika Jankar Bill",
      purpose: "Saved Jeevika Jankar bill aur invoice records dekhne ke liye.",
      fields: ["Jeevika Jankar Name", "Bill Month", "Total Target", "Total Achievement"]
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
      fields: ["Stakeholder Category", "Level 1 User", "Level 2 User", "Status"]
    },
    "user-hierarchy-list" => {
      title: "Cluster Incharge Under Jeevika Jankar User",
      group: "User Mapping",
      purpose: "Saved user hierarchy aur Jeevika Jankar cluster incharge mapping dekhne ke liye.",
      fields: ["Stakeholder Category", "Level 1 User", "Level 2 User", "Status"]
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
      fields: ["Stakeholder", "Stakeholder Role", "Role Name", "Jeevika Jankar Type", "Module Name", "Sub Module Name", "Can View", "Can Create", "Can Edit", "Can Delete", "Status"]
    },
    "access-control-list" => {
      title: "Access Control List",
      group: "Resource Person Type",
      purpose: "Saved access control records dekhne ke liye.",
      fields: ["Stakeholder", "Stakeholder Role", "Role Name", "Jeevika Jankar Type", "Module Name", "Sub Module Name", "Status"]
    }
  }.freeze

  RECORD_SOURCE_SLUGS = {
    "activity-group-list" => "add-activity-group",
    "vrp-activity-list" => "add-vrp-activity",
    "task-completion-indicator-list" => "task-completion-indicator",
    "approval-list" => "approval-master",
    "access-control-list" => "access-control",
    "vrp-bill-list" => "vrp-bill-add",
    "jeevika-jankar-bill-list" => "jeevika-jankar-bill-process",
    "training-form-list" => "training-form",
    "seed-distribution-target-list" => "seed-distribution-target",
    "papl360-target-list" => "papl360-target",
    "user-hierarchy-list" => "user-hierarchy-mapping",
    "all-user" => "new-user"
  }.freeze

  def dashboard
    if vrp_login_user?
      prepare_vrp_dashboard
      return
    end

    targets = dashboard_target_mappings
    selected_month = dashboard_selected_training_month_name
    selected_sub_activity = dashboard_selected_training_sub_activity_name
    month_targets = dashboard_targets_for_month(targets, selected_month)
    training_targets = dashboard_targets_for_filters(targets, selected_month, selected_sub_activity)
    @dashboard_title = admin_dashboard_user? ? "Admin Dashboard" : dashboard_current_user_title
    @dashboard_caption = admin_dashboard_user? ? "Live complete system summary." : "Live summary for your mapped records."
    @training_selected_month = selected_month
    @training_selected_sub_activity = selected_sub_activity
    @training_month_options = dashboard_month_options_for_targets(targets)
    @training_sub_activity_options = dashboard_sub_activity_options_for_targets(month_targets, selected_month)
    participation_status_targets = if selected_month.present? && selected_sub_activity.present?
      training_targets
    elsif selected_month.present?
      month_targets
    else
      targets
    end
    @training_participation_status_cards = training_participation_status_cards(participation_status_targets, month_name: selected_month, sub_activity_name: selected_sub_activity)
    @training_target_status_cards = training_target_status_cards(training_targets, month_name: selected_month, sub_activity_name: selected_sub_activity)
    @training_participation = training_participation_summary(training_targets, month_name: selected_month)
    @farmer_training_dashboard_rows = farmer_training_dashboard_rows(training_targets, month_name: selected_month)
    @dashboard_cards = dashboard_cards
    @dashboard_reports = dashboard_reports
    @dashboard_generated_at = Time.current
  end

  def farmer_training_participation
    targets = dashboard_participation_targets
    selected_month = params[:training_month].presence
    selected_sub_activity = params[:training_sub_activity].presence
    selected_status = normalize_training_participation_status(params[:status]) || "green"
    filtered_targets = if selected_month.present? && selected_sub_activity.present?
      dashboard_targets_for_filters(targets, selected_month, selected_sub_activity)
    elsif selected_month.present?
      dashboard_targets_for_month(targets, selected_month)
    else
      targets
    end

    @training_participation_status = selected_status
    @training_participation_title = training_participation_status_label(selected_status)
    @training_participation_caption = training_participation_status_caption(selected_status)
    @training_participation_rows = training_participation_farmer_rows(filtered_targets, month_name: selected_month)
    @training_participation_rows = @training_participation_rows.select { |row| row[:status] == selected_status } unless selected_status == "total"
    @training_participation_totals = training_participation_status_counts(filtered_targets, month_name: selected_month)
    @training_selected_month = selected_month
    @training_selected_sub_activity = selected_sub_activity

    respond_to do |format|
      format.html
      format.csv do
        send_data(
          training_participation_rows_csv(@training_participation_rows),
          filename: "farmer-training-#{selected_status}-#{Time.current.strftime("%Y%m%d%H%M")}.csv",
          type: "text/csv"
        )
      end
    end
  end

  def farmer_training_target_status
    targets = dashboard_participation_targets
    selected_month = params[:training_month].presence
    selected_sub_activity = params[:training_sub_activity].presence
    selected_status = normalize_training_target_status(params[:status]) || "green"
    filtered_targets = if selected_month.present? && selected_sub_activity.present?
      dashboard_targets_for_filters(targets, selected_month, selected_sub_activity)
    elsif selected_month.present?
      dashboard_targets_for_month(targets, selected_month)
    else
      targets
    end

    @training_target_status = selected_status
    @training_target_status_title = training_target_status_label(selected_status)
    @training_target_status_caption = training_target_status_caption(selected_status)
    @training_target_status_rows = training_target_status_rows(filtered_targets)
      .select { |row| row[:status_class] == selected_status }
    @training_target_status_totals = training_target_status_counts(filtered_targets)
    @training_selected_month = selected_month
    @training_selected_sub_activity = selected_sub_activity

    respond_to do |format|
      format.html
      format.csv do
        send_data(
          training_target_status_rows_csv(@training_target_status_rows),
          filename: "farmer-training-target-#{selected_status}-#{Time.current.strftime("%Y%m%d%H%M")}.csv",
          type: "text/csv"
        )
      end
    end
  end

  def show
    load_module!
    redirect_to users_path and return if @slug == "all-user"
    redirect_to new_user_path and return if @slug == "new-user"

    @records = module_records
    prepare_lg_directory_data if @slug == "lg-directory-list"
    prepare_vrp_bill_data if @slug == "vrp-bill-add"
    prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
    prepare_jeevika_jankar_bill_list if @slug == "jeevika-jankar-bill-list"
  end

  def edit
    load_module!
    @record = ModuleRecord.find(params[:id])
    @records = module_records
    prepare_approval_channel_form(@record) if record_source_slug == "approval-master"
    prepare_vrp_bill_data if @slug == "vrp-bill-add"
    prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
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

    data_errors = module_data_error_messages(record.data)
    if data_errors.any?
      @records = module_records
      prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
      flash.now[:alert] = data_errors.to_sentence
      render :show, status: :unprocessable_entity
      return
    end

    if duplicate_access_control_record?(record.data)
      @records = module_records
      prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
      flash.now[:alert] = "Access control for this stakeholder and role already exists."
      render :show, status: :unprocessable_entity
      return
    end

    if record.save
      sync_vrp_master_record(record)
      redirect_to module_path(module_redirect_slug), notice: "#{@module[:title]} saved successfully."
    else
      @records = module_records
      prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
      flash.now[:alert] = record.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  def update
    load_module!
    record = ModuleRecord.find(params[:id])

    if record_source_slug == "approval-master" && approval_channel_params?
      update_approval_channel(record)
      return
    end

    previous_data = record.data.dup

    next_data = record.data.merge(normalized_module_data)

    data_errors = module_data_error_messages(next_data)
    if data_errors.any?
      @record = record
      @records = module_records
      prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
      flash.now[:alert] = data_errors.to_sentence
      render :show, status: :unprocessable_entity
      return
    end

    if duplicate_access_control_record?(next_data, except_id: record.id)
      @record = record
      @records = module_records
      prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
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
      prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
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

  def send_bill_for_approval
    load_module!
    record = ModuleRecord.find(params[:id])
    unless ["jeevika-jankar-bill-process", "jeevika-jankar-bill-list"].include?(record.module_slug) || record_source_slug == "jeevika-jankar-bill-process"
      redirect_to module_path(@slug), alert: "Send for approval is available only for Jeevika Jankar bills." and return
    end

    step = jeevika_bill_approval_steps(record).first
    redirect_to module_path("jeevika-jankar-bill-list"), alert: "Please create Jeevika Jankar Bill approval channel first." and return unless step

    update_bill_status!(record, "Pending at #{step.data["approver_approved_by"]}", current_sequence: approval_sequence_from_level(step.data["approval_level"]))
    create_bill_approval_history(record, "Sent for Approval", step)
    redirect_to module_path("jeevika-jankar-bill-list"), notice: "Jeevika Jankar bill sent for approval."
  end

  def set_bill_state
    load_module!
    record = ModuleRecord.find(params[:id])
    state = params[:state].presence_in(["Active", "Inactive"]) || "Active"
    record.update!(data: record.data.merge("record_state" => state))
    redirect_to module_path("jeevika-jankar-bill-list"), notice: "Bill marked #{state}."
  end

  def approve_bill
    update_bill_approval("Approved")
  end

  def reject_bill
    update_bill_approval("Rejected")
  end

  def return_bill
    update_bill_approval("Returned")
  end

  def download_bill
    load_module!
    @record = ModuleRecord.find(params[:id])
    @bill_print_mode = true
    @records = []
    render :show, layout: "bill_print"
  end

  private

  def prepare_vrp_dashboard
    @vrp_dashboard = true
    @dashboard_generated_at = Time.current
    @vrp = current_vrp_record
    selected_month = dashboard_selected_training_month_name
    selected_sub_activity = dashboard_selected_training_sub_activity_name

    unless @vrp
      @dashboard_cards = []
      @vrp_target_rows = []
      @vrp_village_rows = []
      @vrp_farmer_followup = empty_vrp_farmer_followup
      return
    end

    mappings = vrp_dashboard_mappings(@vrp)
    targets = vrp_dashboard_targets(@vrp)
    filtered_targets = dashboard_targets_for_month(targets, selected_month)
    training_targets = dashboard_targets_for_filters(targets, selected_month, selected_sub_activity)
    bills = vrp_dashboard_bills(@vrp)
    targeted_farmer_ids = vrp_targeted_farmer_ids(filtered_targets)
    mapped_farmer_count = targeted_farmer_ids.any? ? targeted_farmer_ids.size : vrp_mapped_farmer_count(mappings)
    main_activity_count = filtered_targets.map { |target| normalize_dashboard_text(target.main_activity_name) }.reject(&:blank?).uniq.size
    sub_activity_count = filtered_targets.map { |target| normalize_dashboard_text(target.activity_name) }.reject(&:blank?).uniq.size
    target_total = filtered_targets.sum { |target| target.target_quantity.to_f }
    @vrp_village_rows = vrp_dashboard_village_rows(@vrp, mappings, filtered_targets)
    @training_selected_month = selected_month
    @training_selected_sub_activity = selected_sub_activity
    @training_month_options = dashboard_month_options_for_targets(targets)
    @training_sub_activity_options = dashboard_sub_activity_options_for_targets(filtered_targets, selected_month)
    participation_status_targets = if selected_month.present? && selected_sub_activity.present?
      training_targets
    elsif selected_month.present?
      filtered_targets
    else
      targets
    end
    @training_participation_status_cards = training_participation_status_cards(participation_status_targets, month_name: selected_month, sub_activity_name: selected_sub_activity)
    @training_target_status_cards = training_target_status_cards(training_targets, month_name: selected_month, sub_activity_name: selected_sub_activity)
    @training_participation = training_participation_summary(training_targets, month_name: selected_month)
    @farmer_training_dashboard_rows = farmer_training_dashboard_rows(training_targets, month_name: selected_month)
    village_count = @vrp_village_rows.map { |row| normalize_dashboard_text(row[:village]) }.reject(&:blank?).uniq.size

    @vrp_target_rows = targets.map do |target|
      completed = vrp_target_completed_quantity(target, bills)
      target_quantity = target.target_quantity.to_f
      pending = [target_quantity - completed, 0].max

      {
        month: target.month_name,
        completion_date: target.completion_date&.strftime("%d-%m-%Y") || "-",
        completion_date_sort: target.completion_date,
        fco: target.fco_name.presence || target.fco_id,
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
    assigned_target_total = @vrp_target_rows.sum { |row| row[:target].to_f }
    achieved_target_total = @vrp_target_rows.sum { |row| row[:completed].to_f }
    pending_target_total = @vrp_target_rows.sum { |row| row[:pending].to_f }

    @dashboard_cards = [
      dashboard_card("Mapped Farmers", mapped_farmer_count, "Unique farmers linked to your target rows", dashboard_path(anchor: "vrp_mapped_villages")),
      dashboard_card("Mapped Villages", village_count, "Villages assigned for field work", dashboard_path(anchor: "vrp_mapped_villages")),
      dashboard_card("Main Activities", main_activity_count, "Main activities mapped to your targets", target_mappings_path),
      dashboard_card("Sub Activities", sub_activity_count, "Sub activities mapped to your targets", target_mappings_path),
      dashboard_card("Assigned Target", dashboard_quantity(assigned_target_total), "Total target quantity assigned to you", target_mappings_path),
      dashboard_card("Achieved Target", dashboard_quantity(achieved_target_total), "Target completed so far", dashboard_path(anchor: "vrp_target_progress")),
      dashboard_card("Pending Target", dashboard_quantity(pending_target_total), "Target left to complete", dashboard_path(anchor: "vrp_target_progress"))
    ]
    @vrp_farmer_followup = empty_vrp_farmer_followup
  end

  def vrp_login_user?
    current_app_user&.dig("record_type").to_s == "Vrp"
  end

  def current_vrp_record
    return unless model_ready?(:Vrp)

    return @current_vrp_record if defined?(@current_vrp_record)

    @current_vrp_record = begin
      user = current_app_user || {}
      id_values = [user["id"], user["vrp_id"]].compact_blank.map(&:to_s).select { |value| value.match?(/\A\d+\z/) }
      user_names = [user["username"], user["user_name"], user["name"]].compact_blank.map { |value| value.to_s.strip.downcase }.uniq
      mobile_values = [user["mobile_no"], user["mobile"], user["phone"]].compact_blank.map { |value| value.to_s.gsub(/\D/, "").last(10) }.reject(&:blank?).uniq
      email = user["email"].to_s.strip.downcase

      vrp = Vrp.where(id: id_values).first if vrp_login_user? && id_values.any?
      vrp ||= Vrp.where("LOWER(user_name) IN (?)", user_names).first if user_names.any? && Vrp.column_names.include?("user_name")
      vrp ||= Vrp.where(mobile_no: mobile_values).first if mobile_values.any? && Vrp.column_names.include?("mobile_no")
      vrp ||= Vrp.where("LOWER(email) = ?", email).first if email.present? && Vrp.column_names.include?("email")
      vrp ||= Vrp.where(id: id_values).first if vrp.blank? && id_values.any?
      vrp
    end
  end

  def vrp_dashboard_mappings(vrp)
    return [] unless model_ready?(:VrpIcsMapping)

    VrpIcsMapping.where(vrp_id: vrp.id).order(:village_name, :id).to_a
  end

  def module_record_label_for_dashboard(module_slug, id, field_key)
    return "" if id.blank? || !model_ready?(:ModuleRecord)

    @module_record_label_cache ||= {}
    cache_key = [module_slug.to_s, id.to_s, field_key.to_s]
    return @module_record_label_cache[cache_key] if @module_record_label_cache.key?(cache_key)

    record = ModuleRecord.find_by(module_slug: module_slug, id: id)
    label = module_record_display_label_for_dashboard(module_slug, record, field_key)
    label = id.to_s.match?(/\A\d+\z/) ? "" : id.to_s if label.blank?

    @module_record_label_cache[cache_key] = label
  end

  def module_record_labels_for_dashboard(module_slug, ids, field_key)
    Array(ids)
      .filter_map { |id| module_record_label_for_dashboard(module_slug, id, field_key).presence }
      .join(", ")
  end

  def module_record_display_label_for_dashboard(module_slug, record, field_key)
    return "" unless record

    case module_slug
    when "gram-panchayat-master"
      gram_panchayat_name_from_record(record)
    when "village-master"
      first_present_data(record, "village_name", "village", "name")
    else
      Array(field_key).filter_map { |key| record.data[key].presence }.first
    end.to_s
  end

  def gram_panchayat_label_for_village(village_id)
    return "" if village_id.blank? || !model_ready?(:ModuleRecord)

    village_record = ModuleRecord.find_by(module_slug: "village-master", id: village_id)
    return "" unless village_record

    gram_panchayat = first_non_code_data(village_record, "gram_panchayat_name", "gram_panchayat", "gp_name", "gram_name", "gp_code", "gram_code")
    return module_record_label_for_dashboard("gram-panchayat-master", gram_panchayat, "gram_panchayat_name") if gram_panchayat.to_s.match?(/\A\d+\z/)

    gram_panchayat.to_s
  end

  def vrp_dashboard_village_rows(vrp, mappings, targets)
    targets_by_village = targets.group_by { |target| target.village_id.to_s }

    mapping_rows = mappings.map do |mapping|
      village_targets = targets_by_village[mapping.village_id.to_s] || []
      target_farmer_ids = village_targets.flat_map { |target| target.respond_to?(:afl_ids) ? Array(target.afl_ids).map(&:to_s) : [] }.reject(&:blank?).uniq
      village = mapping.village_name.presence || module_record_label_for_dashboard("village-master", mapping.village_id, "village_name")

      {
        fco: mapping.fco_name.presence || mapping.fco_id,
        gram_panchayat: gram_panchayat_label_for_village(mapping.village_id),
        village: village.presence || mapping.village_id,
        farmers: target_farmer_ids.any? ? target_farmer_ids.size : mapping.farmer_count,
        targets: village_targets.size,
        target_quantity: village_targets.sum { |target| target.target_quantity.to_f }
      }
    end

    registration_rows = Array(vrp.village_ids).reject(&:blank?).map do |village_id|
      village_targets = targets_by_village[village_id.to_s] || []
      {
        fco: "-",
        gram_panchayat: gram_panchayat_label_for_village(village_id).presence || module_record_labels_for_dashboard("gram-panchayat-master", vrp.gram_panchayat_ids, "gram_panchayat_name"),
        village: module_record_label_for_dashboard("village-master", village_id, "village_name").presence || village_id,
        farmers: 0,
        targets: village_targets.size,
        target_quantity: village_targets.sum { |target| target.target_quantity.to_f }
      }
    end

    (mapping_rows + registration_rows)
      .uniq { |row| [normalize_dashboard_text(row[:gram_panchayat]), normalize_dashboard_text(row[:village])] }
  end

  def vrp_dashboard_targets(vrp)
    return [] unless model_ready?(:TargetMapping)

    TargetMapping.where(vrp_id: vrp.id).order(Arel.sql("completion_date ASC NULLS LAST"), :month_name, :main_activity_name, :activity_name, :id).to_a
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

  def vrp_targeted_farmer_ids(targets)
    targets.flat_map { |target| target.respond_to?(:afl_ids) ? Array(target.afl_ids).map(&:to_s) : [] }.reject(&:blank?).uniq
  end

  def vrp_farmer_followup(mappings)
    mapped_farmer_ids = mappings.flat_map { |mapping| Array(mapping.afl_ids).map(&:to_s) }.reject(&:blank?).uniq
    vrp_farmer_followup_for_ids(mapped_farmer_ids)
  end

  def vrp_farmer_followup_for_ids(mapped_farmer_ids)
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
    hierarchy_summary = user_hierarchy_dashboard_summary
    approved_vrps = dashboard_approved_vrps(vrps).size
    pending_approvals = dashboard_pending_approval_vrps(vrps).size
    activity_count = targets.map { |target| [normalize_dashboard_text(target.main_activity_name), normalize_dashboard_text(target.activity_name)] }
      .reject { |main_activity, sub_activity| main_activity.blank? && sub_activity.blank? }
      .uniq
      .size

    cards = [
      dashboard_card("Total Registered VRP", vrps.size, admin_dashboard_user? ? "All VRP records saved in registration" : "VRP records visible to you", vrps_path),
      dashboard_card("Final Approved VRP", approved_vrps, "VRP records with final approval", vrps_path),
      dashboard_card("VRP Pending Approval", pending_approvals, admin_dashboard_user? ? "All VRP records currently pending" : "VRP records pending in your visible approval scope", approvals_vrps_path),
      dashboard_card("VRP Targets Assigned", targets.size, "Target records assigned in VRP Targets", target_mappings_path),
      dashboard_card("Activities Assigned", activity_count, "Activities assigned in visible VRP targets", target_mappings_path)
    ]

    cards.insert(0, dashboard_card("Level 2 Users", hierarchy_summary[:level_2_total], "Users directly mapped under you", dashboard_path(anchor: "user_hierarchy_report"))) if hierarchy_summary[:level_2_total].positive?

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
      reports.insert(0, vrp_assigned_target_report.merge(collapsible: true, collapsed: true))
      reports.insert(0, vrp_declaration_acceptance_report.merge(collapsible: true, collapsed: true))
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

  def dashboard_participation_targets
    if vrp_login_user?
      current_vrp_record.present? ? vrp_dashboard_targets(current_vrp_record) : []
    else
      dashboard_target_mappings
    end
  end

  def training_participation_status_cards(targets, month_name: nil, sub_activity_name: nil)
    counts = training_participation_status_counts(targets, month_name: month_name)

    %w[green yellow red pending].map do |status|
      path_params = { status: status }
      path_params[:training_month] = month_name if month_name.present?
      path_params[:training_sub_activity] = sub_activity_name if sub_activity_name.present?

      {
        status: status,
        title: training_participation_status_label(status),
        value: counts[status.to_sym].to_i,
        caption: training_participation_status_caption(status),
        path: farmer_training_participation_path(path_params)
      }
    end
  end

  def training_participation_status_counts(targets, month_name: nil)
    rows = training_participation_farmer_rows(targets, month_name: month_name)

    {
      green: rows.count { |row| row[:status] == "green" },
      yellow: rows.count { |row| row[:status] == "yellow" },
      red: rows.count { |row| row[:status] == "red" },
      pending: rows.count { |row| row[:status] == "pending" },
      total: rows.size
    }
  end

  def training_participation_farmer_rows(targets, month_name: nil)
    targets = Array(targets)
    return [] if targets.blank?

    memberships = training_participation_target_memberships(targets)
    return [] if memberships.blank?

    attendance_details = training_attendance_details_for_targets(targets, month_name: month_name)
    farmers_by_id = training_farmers_by_id(memberships.values.map { |membership| membership[:farmer_id] })

    memberships.map do |membership_key, membership|
      farmer_id = membership[:farmer_id]
      farmer = farmers_by_id[farmer_id]
      details = attendance_details[membership_key] || { attendance_count: 0, training_dates: [] }
      attendance_count = details[:attendance_count].to_i
      status = training_participation_status_for_count(attendance_count, pending_available: membership[:pending_available])

      {
        farmer_id: farmer_id,
        farmer_name: farmer&.farmer_name.presence || "Farmer ##{farmer_id}",
        father_name: farmer&.father_name,
        mobile_no: farmer&.mobile_no,
        tracenet_no: farmer&.tracenet_no,
        khasara_no: farmer&.khasara_no,
        ics: membership[:ics].presence || farmer&.ics_name.presence || farmer&.ics_id.presence || "-",
        village: membership[:village].presence || farmer&.village_name.presence || farmer&.village_id.presence || "-",
        vrp: membership[:vrp].presence || "-",
        months: membership[:months].presence || "-",
        main_activities: membership[:main_activities].presence || "-",
        sub_activities: membership[:sub_activities].presence || "-",
        attendance_count: attendance_count,
        status: status,
        status_label: training_participation_status_label(status),
        training_dates: details[:training_dates].presence || "-",
        last_training_date: details[:last_training_date].presence || "-"
      }
    end.sort_by { |row| [row[:status], -row[:attendance_count], row[:farmer_name].to_s.downcase] }
  end

  def training_participation_target_memberships(targets)
    Array(targets).each_with_object({}) do |target, memberships|
      target_farmer_ids(target).each do |farmer_id|
        membership_key = training_participation_membership_key(farmer_id, target.month_name)
        memberships[membership_key] ||= {
          farmer_id: farmer_id,
          months: [],
          ics: [],
          village: [],
          vrp: [],
          main_activities: [],
          sub_activities: [],
          pending_available: false
        }

        memberships[membership_key][:months] |= [target.month_name.to_s.strip].reject(&:blank?)
        memberships[membership_key][:ics] |= [target_ics_label(target).to_s.strip].reject(&:blank?)
        memberships[membership_key][:village] |= [target_village_label(target).to_s.strip].reject(&:blank?)
        memberships[membership_key][:vrp] |= [target.vrp&.name.to_s.strip].reject(&:blank?)
        memberships[membership_key][:main_activities] |= [target.main_activity_name.to_s.strip].reject(&:blank?)
        memberships[membership_key][:sub_activities] |= [target.activity_name.to_s.strip].reject(&:blank?)
        memberships[membership_key][:pending_available] ||= training_participation_month_open?(target.month_name)
      end
    end.transform_values do |membership|
      membership.transform_values do |values|
        values.is_a?(Array) ? values.uniq.join(", ") : values
      end
    end
  end

  def training_attendance_details_for_targets(targets, month_name: nil)
    return {} unless model_ready?(:ModuleRecord)

    target_sets = Array(targets).filter_map do |target|
      farmer_ids = target_farmer_ids(target)
      farmer_ids.blank? ? nil : [target, farmer_ids]
    end
    return {} if target_sets.blank?

    ModuleRecord
      .where(module_slug: "training-form")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .select { |record| month_name.blank? || normalize_dashboard_text(training_record_month_name(record)) == normalize_dashboard_text(month_name) }
      .each_with_object(Hash.new { |hash, key| hash[key] = { attendance_count: 0, training_dates: [] } }) do |record, details|
        matching_membership_keys = target_sets.each_with_object([]) do |(target, farmer_ids), keys|
          next unless training_record_matches_dashboard_target?(record, target, farmer_ids)

          (training_record_selected_farmer_ids(record) & farmer_ids).each do |farmer_id|
            keys << training_participation_membership_key(farmer_id, target.month_name)
          end
        end.uniq
        next if matching_membership_keys.blank?

        training_date = bill_display_date(training_summary(record)[:training_date]).presence || bill_display_date(record.created_at)
        matching_membership_keys.each do |membership_key|
          details[membership_key][:attendance_count] += 1
          details[membership_key][:training_dates] |= [training_date].reject(&:blank?)
        end
      end.transform_values do |detail|
        dates = detail[:training_dates].sort_by { |date| parse_module_date(date)&.to_time || Time.zone.local(1900, 1, 1) }
        detail.merge(training_dates: dates.join(", "), last_training_date: dates.last)
      end
  end

  def training_farmers_by_id(farmer_ids)
    return {} unless model_ready?(:Afl)

    ids = Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq
    return {} if ids.blank?

    Afl.where(id: ids).index_by { |farmer| farmer.id.to_s }
  end

  def training_participation_membership_key(farmer_id, month_name)
    [farmer_id.to_s, normalize_dashboard_text(month_name)].join("|")
  end

  def training_participation_status_for_count(count, pending_available: false)
    count = count.to_i
    return "green" if count >= 3
    return "yellow" if count.positive?
    return "pending" if pending_available

    "red"
  end

  def normalize_training_participation_status(status)
    value = status.to_s.strip.downcase
    %w[total green yellow red pending].include?(value) ? value : nil
  end

  def training_participation_status_label(status)
    {
      "total" => "Total Mapped",
      "green" => "Green",
      "yellow" => "Yellow",
      "red" => "Red",
      "pending" => "Pending"
    }[status.to_s] || "Farmer"
  end

  def training_participation_status_caption(status)
    {
      "total" => "Farmer Target Form ke selected farmers.",
      "green" => "Farmer attended 3 or more trainings.",
      "yellow" => "Farmer attended 1-2 trainings.",
      "red" => "Month closed and farmer did not attend any training.",
      "pending" => "Month open and farmer training is still pending."
    }[status.to_s] || "Farmer training participation status."
  end

  def training_participation_rows_csv(rows)
    CSV.generate(headers: true) do |csv|
      csv << [
        "Farmer ID",
        "Farmer",
        "Father Name",
        "Mobile",
        "TraceNet No",
        "ICS",
        "Village",
        "VRP",
        "Target Months",
        "Main Activities",
        "Sub Activities",
        "Training Count",
        "Status",
        "Training Dates",
        "Last Training Date"
      ]

      Array(rows).each do |row|
        csv << [
          row[:farmer_id],
          row[:farmer_name],
          row[:father_name],
          row[:mobile_no],
          row[:tracenet_no],
          row[:ics],
          row[:village],
          row[:vrp],
          row[:months],
          row[:main_activities],
          row[:sub_activities],
          row[:attendance_count],
          row[:status_label],
          row[:training_dates],
          row[:last_training_date]
        ]
      end
    end
  end

  def training_target_status_cards(targets, month_name: nil, sub_activity_name: nil)
    counts = training_target_status_counts(targets)

    %w[green yellow red].map do |status|
      path_params = { status: status }
      path_params[:training_month] = month_name if month_name.present?
      path_params[:training_sub_activity] = sub_activity_name if sub_activity_name.present?

      {
        status: status,
        title: training_target_status_label(status),
        value: counts[status.to_sym].to_i,
        caption: training_target_status_caption(status),
        path: farmer_training_target_status_path(path_params)
      }
    end
  end

  def training_target_status_rows(targets)
    Array(targets)
      .map { |target| training_target_detail_row(target) }
      .sort_by do |row|
        [
          dashboard_month_index(row[:month]),
          row[:completion_date_sort].presence || Date.new(9999, 12, 31),
          row[:vrp].to_s,
          row[:ics].to_s,
          row[:village].to_s,
          row[:main_activity].to_s,
          row[:sub_activity].to_s
        ]
      end
  end

  def training_target_status_counts(targets)
    rows = training_target_status_rows(targets)

    {
      green: rows.count { |row| row[:status_class] == "green" },
      yellow: rows.count { |row| row[:status_class] == "yellow" },
      red: rows.count { |row| row[:status_class] == "red" },
      total: rows.size
    }
  end

  def training_target_status_label(status)
    {
      "green" => "Green",
      "yellow" => "Yellow",
      "red" => "Red"
    }[status.to_s] || "Target"
  end

  def training_target_status_caption(status)
    {
      "green" => "Target 100% completed by Completion Date.",
      "yellow" => "Target progress is 75% to 99%.",
      "red" => "Target progress is below 75% or no training done."
    }[status.to_s] || "Target completion status."
  end

  def normalize_training_target_status(status)
    value = status.to_s.strip.downcase
    %w[green yellow red].include?(value) ? value : nil
  end

  def training_target_status_for_percent(percent)
    value = percent.to_f
    return "green" if value >= 100
    return "yellow" if value >= 75

    "red"
  end

  def training_target_status_rows_csv(rows)
    CSV.generate(headers: true) do |csv|
      csv << [
        "Target Mapping ID",
        "VRP",
        "Month",
        "Completion Date",
        "ICS",
        "Village",
        "Main Activity",
        "Sub Activity",
        "Target",
        "Completed",
        "Pending",
        "Progress %",
        "Status"
      ]

      Array(rows).each do |row|
        csv << [
          row[:target_mapping_id],
          row[:vrp],
          row[:month],
          row[:completion_date],
          row[:ics],
          row[:village],
          row[:main_activity],
          row[:sub_activity],
          dashboard_quantity(row[:target_quantity]),
          dashboard_quantity(row[:completed_quantity]),
          dashboard_quantity(row[:pending_quantity]),
          row[:progress_percent],
          row[:status_label]
        ]
      end
    end
  end

  def training_participation_summary(targets, month_name: nil)
    targets = Array(targets)
    attendance_counts = training_attendance_counts_for_targets(targets, month_name: month_name)
    ics_memberships = Hash.new { |hash, key| hash[key] = { label: "", farmer_ids: [] } }
    village_memberships = Hash.new { |hash, key| hash[key] = { ics: "", village: "", farmer_ids: [] } }

    targets.each do |target|
      farmer_ids = Array(target.respond_to?(:afl_ids) ? target.afl_ids : []).map(&:to_s).reject(&:blank?).uniq
      next if farmer_ids.blank?

      ics = target_ics_label(target)
      village = target_village_label(target)
      ics_key = normalize_dashboard_text(ics)
      village_key = [ics_key, normalize_dashboard_text(village)].join("|")

      ics_memberships[ics_key][:label] = ics
      ics_memberships[ics_key][:farmer_ids].concat(farmer_ids)
      village_memberships[village_key][:ics] = ics
      village_memberships[village_key][:village] = village
      village_memberships[village_key][:farmer_ids].concat(farmer_ids)
    end

    ics_rows = ics_memberships.values.map do |row|
      counts = training_status_counts(row[:farmer_ids].uniq, attendance_counts)
      row.merge(counts)
    end.sort_by { |row| row[:label].to_s }

    village_rows = village_memberships.values.map do |row|
      counts = training_status_counts(row[:farmer_ids].uniq, attendance_counts)
      row.merge(counts)
    end.sort_by { |row| [row[:ics].to_s, row[:village].to_s] }

    {
      totals: training_status_counts(ics_memberships.values.flat_map { |row| row[:farmer_ids] }.uniq, attendance_counts).merge(
        cumulative_participants: attendance_counts.values.sum,
        monthly_unique: attendance_counts.keys.size
      ),
      ics_rows: ics_rows,
      village_rows: village_rows
    }
  end

  def training_attendance_counts_for_targets(targets, month_name: nil)
    return {} unless model_ready?(:ModuleRecord)

    target_sets = Array(targets).filter_map do |target|
      farmer_ids = target_farmer_ids(target)
      farmer_ids.blank? ? nil : [target, farmer_ids]
    end
    return {} if target_sets.blank?

    ModuleRecord
      .where(module_slug: "training-form")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .select { |record| month_name.blank? || normalize_dashboard_text(training_record_month_name(record)) == normalize_dashboard_text(month_name) }
      .each_with_object(Hash.new(0)) do |record, counts|
        matching_farmer_ids = target_sets.each_with_object([]) do |(target, farmer_ids), ids|
          next unless training_record_matches_dashboard_target?(record, target, farmer_ids)

          ids.concat(training_record_selected_farmer_ids(record) & farmer_ids)
        end.uniq

        matching_farmer_ids.each { |farmer_id| counts[farmer_id] += 1 }
      end
  end

  def training_status_counts(farmer_ids, attendance_counts)
    counts = { green: 0, yellow: 0, red: 0, total: farmer_ids.size }

    farmer_ids.each do |farmer_id|
      attended = attendance_counts[farmer_id].to_i
      if attended >= 3
        counts[:green] += 1
      elsif attended.positive?
        counts[:yellow] += 1
      else
        counts[:red] += 1
      end
    end

    counts
  end

  def farmer_training_dashboard_rows(targets, month_name: nil)
    targets = Array(targets)
    return [] if targets.blank? || !model_ready?(:ModuleRecord)

    training_records = ModuleRecord
      .where(module_slug: "training-form")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .select { |record| month_name.blank? || normalize_dashboard_text(training_record_month_name(record)) == normalize_dashboard_text(month_name) }

    grouped_targets = targets.each_with_object({}) do |target, groups|
      farmer_ids = target_farmer_ids(target)
      next if farmer_ids.blank?

      key = [
        normalize_dashboard_text(target.month_name),
        normalize_dashboard_text(target_ics_label(target)),
        normalize_dashboard_text(target_village_label(target)),
        normalize_dashboard_text(target.main_activity_name),
        normalize_dashboard_text(target.activity_name)
      ]
      groups[key] ||= {
        month: target.month_name.presence || "-",
        ics: target_ics_label(target),
        village: target_village_label(target),
        activity: target.main_activity_name.presence || "Farmer Training",
        sub_activity: target.activity_name.presence || "-",
        farmer_ids: [],
        target_quantity: 0.0,
        targets: []
      }
      groups[key][:farmer_ids] |= farmer_ids
      groups[key][:target_quantity] += target.target_quantity.to_f
      groups[key][:targets] << target
    end

    grouped_targets.values.map do |group|
      farmer_ids = group[:farmer_ids].uniq
      matching_records = training_records.select do |record|
        group[:targets].any? { |target| training_record_matches_dashboard_target?(record, target, farmer_ids) }
      end.uniq(&:id)
      session_participants = matching_records.flat_map { |record| training_record_selected_farmer_ids(record) & farmer_ids }
      unique_participants = session_participants.uniq
      target_quantity = group[:target_quantity].to_f
      target_detail_rows = group[:targets].map { |target| training_target_detail_row(target) }
      status_counts = training_target_status_counts_for_rows(target_detail_rows)
      farmer_rows = farmer_rows_for_training_group(group[:targets])

      group.merge(
        sessions: matching_records.size,
        training_photo_count: matching_records.count { |record| module_upload_present?(record.data["training_photo_upload_with_geo_tag"]) },
        register_count: matching_records.count { |record| module_upload_present?(record.data["training_register_upload"]) },
        male_count: matching_records.sum { |record| dashboard_numeric(record.data["male_count"]) },
        female_count: matching_records.sum { |record| dashboard_numeric(record.data["female_count"]) },
        cumulative_participants: session_participants.size,
        unique_monthly: unique_participants.size,
        target_quantity: target_quantity,
        achievement_percent: farmer_rows[:progress_percent],
        training_dates: matching_records.filter_map { |record| bill_display_date(record.data["training_date"]) if record.data["training_date"].present? }.uniq,
        green: status_counts[:green],
        yellow: status_counts[:yellow],
        red: status_counts[:red],
        total: status_counts[:total],
        target_rows: target_detail_rows,
        completed_farmers: farmer_rows[:completed_farmers],
        pending_farmers: farmer_rows[:pending_farmers],
        completed_quantity: farmer_rows[:completed_quantity],
        pending_quantity: farmer_rows[:pending_quantity],
        progress_percent: farmer_rows[:progress_percent]
      )
    end.sort_by do |row|
      [dashboard_month_index(row[:month]), row[:ics].to_s, row[:village].to_s, row[:activity].to_s, row[:sub_activity].to_s]
    end
  end

  def training_target_detail_row(target)
    farmer_ids = target_farmer_ids(target)
    completed_farmer_ids = completed_training_farmer_ids_for_target_deadline(target, farmer_ids)
    pending_farmer_ids = farmer_ids - completed_farmer_ids
    target_quantity = target.target_quantity.to_f
    completed_quantity = completed_farmer_ids.size.to_f
    pending_quantity = [target_quantity - completed_quantity, 0].max
    progress_percent = target_quantity.positive? ? ((completed_quantity / target_quantity) * 100).round : 0
    status_class = training_target_status_for_percent(progress_percent)

    {
      target_mapping_id: target.id.to_s,
      month: target.month_name.presence || "-",
      vrp: target.vrp&.name.presence || "VRP ##{target.vrp_id}",
      ics: target.ics_name.presence || target.ics_id.presence || "-",
      village: target.village_name.presence || target.village_id.presence || "-",
      main_activity: target.main_activity_name.presence || "Farmer Training",
      sub_activity: target.activity_name.presence || "-",
      completion_date: target.completion_date&.strftime("%d-%m-%Y") || "-",
      completion_date_sort: target.completion_date,
      target_quantity: target_quantity,
      completed_quantity: completed_quantity,
      pending_quantity: pending_quantity,
      progress_percent: progress_percent,
      status_label: training_target_status_label(status_class),
      status_class: status_class,
      completed_farmers: training_farmers_for_ids(completed_farmer_ids).map { |farmer| farmer.merge(status_label: "Completed", status_class: "green") },
      pending_farmers: training_farmers_for_ids(pending_farmer_ids).map { |farmer| farmer.merge(status_label: "Pending", status_class: "red") }
    }
  end

  def training_target_status_counts_for_rows(rows)
    rows = Array(rows)

    {
      green: rows.count { |row| row[:status_class] == "green" },
      yellow: rows.count { |row| row[:status_class] == "yellow" },
      red: rows.count { |row| row[:status_class] == "red" },
      total: rows.size
    }
  end

  def farmer_rows_for_training_group(targets)
    target_rows = Array(targets)
    return {
      completed_farmers: [],
      pending_farmers: [],
      completed_quantity: 0,
      pending_quantity: 0,
      progress_percent: 0
    } if target_rows.blank?

    completed_farmer_ids = target_rows.flat_map do |target|
      completed_training_farmer_ids_for_target_deadline(target, target_farmer_ids(target))
    end.uniq
    target_farmer_ids = target_rows.flat_map { |target| target_farmer_ids(target) }.uniq
    pending_farmer_ids = target_farmer_ids - completed_farmer_ids
    completed_quantity = completed_farmer_ids.size
    pending_quantity = pending_farmer_ids.size
    total_quantity = target_farmer_ids.size
    progress_percent = total_quantity.positive? ? ((completed_quantity.to_f / total_quantity) * 100).round : 0

    {
      completed_farmers: training_farmers_for_ids(completed_farmer_ids).map { |farmer| farmer.merge(status_label: "Completed", status_class: "green") },
      pending_farmers: training_farmers_for_ids(pending_farmer_ids).map { |farmer| farmer.merge(status_label: "Pending", status_class: "red") },
      completed_quantity: completed_quantity,
      pending_quantity: pending_quantity,
      progress_percent: progress_percent
    }
  end

  def target_farmer_ids(target)
    Array(target.respond_to?(:afl_ids) ? target.afl_ids : []).map(&:to_s).reject(&:blank?).uniq
  end

  def dashboard_selected_training_month_name
    params[:training_month].presence || params[:dashboard_month].presence
  end

  def dashboard_selected_training_sub_activity_name
    params[:training_sub_activity].presence
  end

  def dashboard_targets_for_filters(targets, month_name, sub_activity_name)
    return [] if month_name.blank? || sub_activity_name.blank?

    month_targets = dashboard_targets_for_month(targets, month_name)
    month_targets.select { |target| normalize_dashboard_text(target.activity_name) == normalize_dashboard_text(sub_activity_name) }
  end

  def dashboard_targets_for_month(targets, month_name)
    targets = Array(targets)
    return targets if month_name.blank?

    targets.select { |target| normalize_dashboard_text(target.month_name) == normalize_dashboard_text(month_name) }
  end

  def dashboard_sub_activity_options_for_targets(targets, month_name)
    return [] if month_name.blank?

    Array(targets)
      .map { |target| target.activity_name.to_s.strip }
      .reject(&:blank?)
      .uniq
      .sort_by { |sub_activity| sub_activity.downcase }
  end

  def dashboard_month_options_for_targets(targets)
    Array(targets)
      .map { |target| target.month_name.to_s.strip }
      .reject(&:blank?)
      .uniq
      .sort_by { |month| [dashboard_month_index(month), month] }
  end

  def training_record_selected_farmer_ids(record)
    Array(record.data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?).uniq
  end

  def training_record_matches_dashboard_target?(record, target, target_farmer_ids)
    selected_farmer_ids = training_record_selected_farmer_ids(record)
    return false if (selected_farmer_ids & target_farmer_ids).blank?
    return false unless training_record_matches_month?(record, target.month_name)
    return false unless training_record_vrp_scope_matches?(record, target.vrp)

    summary = training_summary(record)
    topic = normalize_dashboard_text(summary[:training_topic])
    subject = normalize_dashboard_text(summary[:training_subject])
    target_topic = normalize_dashboard_text(target.main_activity_name)
    target_subject = normalize_dashboard_text(target.activity_name)

    topic_matches = topic.blank? || target_topic.blank? || topic == target_topic
    subject_matches = subject.blank? || target_subject.blank? || subject == target_subject
    topic_matches && subject_matches
  end

  def training_record_vrp_scope_matches?(record, vrp)
    return true unless vrp

    record_values = [
      record.data["jeevika_jankar_id"],
      record.data["vrp_id"],
      record.data["select_vrp"],
      record.data["vrp_name"],
      record.data["jeevika_jankar_name"],
      record.data["trainer_contact"],
      record.data["trainer_name"]
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)
    return true if record_values.blank?

    vrp_values = [
      vrp.id,
      vrp.name,
      vrp.user_name,
      vrp.mobile_no,
      [vrp.name, vrp.mobile_no.presence].compact_blank.join(" - ")
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)

    (record_values & vrp_values).any?
  end

  def module_upload_present?(value)
    case value
    when Array then value.any? { |item| module_upload_present?(item) }
    when Hash then value.values.any? { |item| module_upload_present?(item) }
    else value.to_s.strip.present?
    end
  end

  def dashboard_month_index(month_name)
    Date::MONTHNAMES.index(month_name.to_s.strip.capitalize) || 13
  end

  def training_participation_month_open?(month_name)
    month_index = dashboard_month_index(month_name)
    return false if month_index > 12

    today = Time.zone.today
    month_end = Date.civil(today.year, month_index, -1)
    today <= month_end
  end

  def target_ics_label(target)
    target.ics_name.presence || module_record_label_for_dashboard("ics-master", target.ics_id, "ics_name").presence || target.ics_id.presence || "-"
  end

  def target_village_label(target)
    target.village_name.presence || module_record_label_for_dashboard("village-master", target.village_id, "village_name").presence || target.village_id.presence || "-"
  end

  def user_hierarchy_dashboard_report(summary)
    {
      title: "User Hierarchy",
      dom_id: "user_hierarchy_report",
      headers: ["Name", "Reports To", "Level"],
      rows: summary[:rows].presence || [["No mapped user", "-", "-"]]
    }
  end

  def user_hierarchy_dashboard_summary
    @user_hierarchy_dashboard_summary ||= begin
      rows = user_hierarchy_dashboard_rows
      {
        level_2_total: rows.size,
        level_3_total: 0,
        total: rows.size,
        rows: rows
      }
    end
  end

  def user_hierarchy_dashboard_rows
    return [] unless model_ready?(:ModuleRecord)

    current_labels = current_dashboard_user_labels
    return [] if current_labels.blank?

    rows = []
    ModuleRecord
      .where(module_slug: "user-hierarchy-mapping")
      .order(updated_at: :desc)
      .select { |record| active_module_record?(record) }
      .each do |record|
        level_1_user = record.data["level_1_user"].to_s.strip
        hierarchy_mappings_for_dashboard(record).each do |mapping|
          level_2_user = mapping["level_2_user"].to_s.strip

          if dashboard_user_label_matches?(level_1_user, current_labels)
            rows << [level_2_user, level_1_user, "Level 2"] if level_2_user.present?
          end
        end
      end

    rows.reject { |row| row[0].blank? }
  end

  def hierarchy_mappings_for_dashboard(record)
    raw_mappings = record.data["level_2_mappings"]
    raw_mappings = raw_mappings.values if raw_mappings.is_a?(Hash)
    mappings = Array(raw_mappings).filter_map do |mapping|
      mapping = mapping.to_h if mapping.respond_to?(:to_h)
      next unless mapping.is_a?(Hash)

      users = collapsed_hierarchy_users(mapping["level_2_user"], mapping["level_3_users"])
      users.map { |user| { "level_2_user" => user, "level_3_users" => [] } }
    end
    mappings.flatten!

    return mappings if mappings.any?

    collapsed_hierarchy_users(record.data["level_2_users"].presence || record.data["level_2_user"], record.data["level_3_users"].presence || record.data["level_3_user"]).map do |level_2_user|
      {
        "level_2_user" => level_2_user,
        "level_3_users" => []
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

  def dashboard_current_user_title
    current_app_user&.dig("name").presence ||
      current_app_user&.dig("username").presence ||
      current_app_user&.dig("user_name").presence ||
      "Dashboard"
  end

  def dashboard_vrps
    return [] unless model_ready?(:Vrp)
    return Vrp.all.to_a if current_app_user.blank? || current_app_user["user_type"].to_s.casecmp("admin").zero?
    return (module_cluster_visible_vrps + dashboard_approval_related_vrps).uniq if module_cluster_incharge_login?

    (dashboard_own_vrps.to_a + dashboard_hierarchy_vrps + dashboard_approval_related_vrps).uniq
  end

  def dashboard_approved_vrps(vrps)
    Array(vrps).select { |vrp| vrp.status.to_i == 55 || vrp_approval_complete?(vrp) }
  end

  def dashboard_pending_approval_vrps(vrps)
    Array(vrps).select do |vrp|
      next false unless vrp_approval_pending?(vrp)
      next true if admin_dashboard_user?
      next true if dashboard_current_user_current_approver?(vrp)

      dashboard_user_owns_vrp?(vrp)
    end
  end

  def dashboard_user_owns_vrp?(vrp)
    dashboard_own_vrps.to_a.any? { |own_vrp| own_vrp.id == vrp.id }
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

  def dashboard_hierarchy_vrps
    return [] unless model_ready?(:Vrp)

    labels = dashboard_under_user_labels
    return [] if labels.blank?

    ids = dashboard_user_ids_for_labels(labels)
    legacy_ids = dashboard_legacy_user_ids_for_labels(labels)
    emails = dashboard_user_emails_for_labels(labels)
    scope = Vrp.none

    creator_ids = (ids + legacy_ids).compact_blank.uniq
    if creator_ids.any?
      scope = scope.or(Vrp.where(created_by_id: creator_ids))
      scope = scope.or(Vrp.where(user_id: ids)) if ids.any? && Vrp.column_names.include?("user_id")
    end

    if emails.any?
      email_scope = Vrp.where("LOWER(email) IN (?)", emails)
      scope = scope.or(email_scope)
    end

    cluster_vrps = Vrp.where.not(cluster_incharge: [nil, ""]).select do |vrp|
      labels.any? { |label| normalize_dashboard_user_label(label) == normalize_dashboard_user_label(vrp.cluster_incharge) }
    end

    (scope.to_a + cluster_vrps).uniq
  end

  def dashboard_under_user_labels
    @dashboard_under_user_labels ||= user_hierarchy_dashboard_rows.map { |row| row[0] }.compact_blank.uniq
  end

  def dashboard_user_ids_for_labels(labels)
    return [] unless model_ready?(:User)

    normalized_labels = Array(labels).map { |label| normalize_dashboard_user_label(label) }.reject(&:blank?).uniq
    return [] if normalized_labels.blank?

    User.all.select do |user|
      user_labels = [
        user.respond_to?(:full_name) ? user.full_name : nil,
        user.respond_to?(:user_name) ? user.user_name : nil,
        user.respond_to?(:name) ? user.name : nil
      ].compact_blank.map { |label| normalize_dashboard_user_label(label) }

      (user_labels & normalized_labels).any?
    end.map(&:id)
  end

  def dashboard_legacy_user_ids_for_labels(labels)
    return [] unless model_ready?(:ModuleRecord)

    normalized_labels = Array(labels).map { |label| normalize_dashboard_user_label(label) }.reject(&:blank?).uniq
    return [] if normalized_labels.blank?

    ModuleRecord.where(module_slug: "new-user").select do |record|
      full_name = [record.data["first_name"], record.data["last_name"]].compact_blank.join(" ")
      record_labels = [
        full_name,
        record.data["user_name"],
        record.data["name"]
      ].compact_blank.map { |label| normalize_dashboard_user_label(label) }

      (record_labels & normalized_labels).any?
    end.map(&:id)
  end

  def dashboard_user_emails_for_labels(labels)
    emails = []
    normalized_labels = Array(labels).map { |label| normalize_dashboard_user_label(label) }.reject(&:blank?).uniq
    return emails if normalized_labels.blank?

    if model_ready?(:User)
      User.all.each do |user|
        user_labels = [
          user.respond_to?(:full_name) ? user.full_name : nil,
          user.respond_to?(:user_name) ? user.user_name : nil,
          user.respond_to?(:name) ? user.name : nil
        ].compact_blank.map { |label| normalize_dashboard_user_label(label) }
        emails << user.email if (user_labels & normalized_labels).any? && user.respond_to?(:email)
      end
    end

    if model_ready?(:ModuleRecord)
      ModuleRecord.where(module_slug: "new-user").each do |record|
        full_name = [record.data["first_name"], record.data["last_name"]].compact_blank.join(" ")
        record_labels = [full_name, record.data["user_name"], record.data["name"]].compact_blank.map { |label| normalize_dashboard_user_label(label) }
        emails << record.data["email"] if (record_labels & normalized_labels).any?
      end
    end

    emails.compact_blank.map { |email| email.to_s.strip.downcase }.uniq
  end

  def dashboard_approval_related_vrps
    return [] unless model_ready?(:Vrp)

    @dashboard_approval_related_vrps ||= Vrp.all.select do |vrp|
      vrp_approval_sent?(vrp) && dashboard_current_user_in_approval_channel?(vrp)
    end
  end

  def dashboard_current_user_in_approval_channel?(vrp)
    current_labels = current_dashboard_user_labels
    return false if current_labels.blank?

    dashboard_approval_steps_for_visibility(vrp).any? do |step|
      dashboard_user_label_matches?(step.data["approver_approved_by"], current_labels)
    end ||
      vrp_approval_history_for(vrp).any? do |record|
        dashboard_user_label_matches?(record.data["approver"], current_labels) ||
          dashboard_user_label_matches?(record.data["action_by"], current_labels)
      end
  end

  def dashboard_current_user_current_approver?(vrp)
    current_labels = current_dashboard_user_labels
    return false if current_labels.blank?

    step = dashboard_current_approval_step_for_visibility(vrp)
    return false unless step

    dashboard_user_label_matches?(step.data["approver_approved_by"], current_labels)
  end

  def dashboard_approval_steps_for_visibility(vrp)
    return [] unless model_ready?(:ModuleRecord)

    @dashboard_approval_steps_for_visibility_cache ||= {}
    cache_key = vrp.id
    return @dashboard_approval_steps_for_visibility_cache[cache_key] if @dashboard_approval_steps_for_visibility_cache.key?(cache_key)

    identities = vrp_creator_identities_for_dashboard(vrp)
    return @dashboard_approval_steps_for_visibility_cache[cache_key] = [] if identities.blank?

    @dashboard_approval_visibility_steps ||= ModuleRecord.where(module_slug: "approval-master").order(created_at: :asc).to_a
    @dashboard_approval_steps_for_visibility_cache[cache_key] = @dashboard_approval_visibility_steps
      .select do |record|
        record.data["status"].to_s != "Inactive" &&
          approval_registration_module?(record.data["module_name"]) &&
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

  def dashboard_current_approval_step_for_visibility(vrp)
    dashboard_approval_steps_for_visibility(vrp).find do |step|
      !vrp_approval_step_closed?(vrp, step)
    end
  end

  def dashboard_current_app_user_ids
    @dashboard_current_app_user_ids ||= ([current_app_user&.dig("id")] + dashboard_legacy_current_app_user_ids).compact.uniq
  end

  def dashboard_legacy_current_app_user_ids
    return [] unless model_ready?(:ModuleRecord)

    @dashboard_legacy_current_app_user_ids ||= begin
      username = current_app_user&.dig("username").to_s
      emails = dashboard_current_app_user_emails
      if username.blank? && emails.blank?
        []
      else
        ModuleRecord.where(module_slug: "new-user").select do |record|
          record.data["user_name"].to_s == username ||
            emails.include?(record.data["email"].to_s.strip.downcase)
        end.map(&:id)
      end
    end
  end

  def dashboard_current_app_user_emails
    @dashboard_current_app_user_emails ||= begin
      emails = [current_app_user&.dig("email")]

      if model_ready?(:User)
        user = User.find_by(user_name: current_app_user&.dig("username")) || User.find_by(id: current_app_user&.dig("id"))
        emails << user&.email
      end

      emails.compact_blank.map { |email| email.to_s.strip.downcase }.uniq
    end
  end

  def module_records_for_dashboard(slug)
    return [] unless model_ready?(:ModuleRecord)

    @module_records_for_dashboard_cache ||= {}
    @module_records_for_dashboard_cache[slug.to_s] ||= ModuleRecord.where(module_slug: slug).order(created_at: :desc).to_a
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
          approval_registration_module?(record.data["module_name"]) &&
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
      user_name: current_app_user&.dig("username").presence || current_app_user&.dig("user_name"),
      user_names: [current_app_user&.dig("username"), current_app_user&.dig("user_name"), current_app_user&.dig("name")]
    } if vrp.created_by_id.blank?

    identities
      .select { |identity| identity[:stakeholder].present? && (identity[:role].present? || identity_user_name_values(identity).present?) }
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
      user_name: user.user_name,
      user_names: [user.user_name, user.full_name]
    }
  end

  def record_dashboard_identity(record)
    full_name = [record.data["first_name"], record.data["last_name"]].compact_blank.join(" ")

    {
      role: record.data["role"],
      stakeholder: record.data["stakeholder"],
      stakeholder_role: record.data["stakeholder_role"],
      user_management_role: record.data["user_management_role"],
      person_type: record.data["person_type"],
      office: record.data["sub_office_name"].presence || record.data["office"],
      office_category: record.data["office_category"].presence || record.data["office_name"],
      user_name: record.data["user_name"],
      user_names: [record.data["user_name"], full_name, record.data["name"]]
    }
  end

  def vrp_approval_sequence(record)
    approval_sequence_from_level(record.data["approval_level"])
  end

  def approval_sequence_from_level(level)
    approval_level_sequence_from_text(level).presence || 1
  end

  def approval_level_sequence_from_text(value)
    normalized = value.to_s.downcase.gsub(/\s+/, " ").strip
    return if normalized.blank?

    {
      "first approval" => 1,
      "second approval" => 2,
      "third approval" => 3,
      "fourth approval" => 4,
      "fifth approval" => 5,
      "sixth approval" => 6,
      "seventh approval" => 7,
      "eighth approval" => 8,
      "ninth approval" => 9,
      "tenth approval" => 10
    }.each do |label, sequence|
      return sequence if normalized.include?(label)
    end

    normalized[/\bapproval\s*(\d+)\b/, 1]&.to_i.presence ||
      normalized[/\b(\d+)\b/, 1]&.to_i.presence
  end

  def normalize_approval_label(label)
    label.to_s.sub(/\s*\([^)]*\)\s*\z/, "").strip.downcase
  end

  def dashboard_value_matches?(expected, actual)
    return true if expected.blank?

    expected.to_s.strip.casecmp(actual.to_s.strip).zero?
  end

  def approval_registration_module?(module_name)
    module_name.blank? || APPROVAL_REGISTRATION_MODULES.any? { |name| dashboard_value_matches?(module_name, name) }
  end

  def approval_identity_filters_match?(record, identity)
    approval_value_matches?(approval_record_office(record), identity[:office]) &&
      approval_value_matches?(record.data["office_category"], identity[:office_category]) &&
      approval_user_name_matches?(record.data["user_name"], identity_user_name_values(identity))
  end

  def approval_value_matches?(expected, actual)
    expected.blank? || actual.blank? || dashboard_value_matches?(expected, actual)
  end

  def approval_user_name_matches?(expected, actual)
    return true if expected.blank?

    Array(actual).compact_blank.any? { |value| dashboard_value_matches?(expected, value) }
  end

  def identity_user_name_values(identity)
    (Array(identity[:user_names]) + [identity[:user_name]]).compact_blank.uniq
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

    records = ModuleRecord.where(module_slug: record_source_slug).to_a
    records = records.select { |record| jeevika_jankar_bill_record_visible?(record) } if record_source_slug == "jeevika-jankar-bill-process"
    records = records.select { |record| other_target_record_visible?(record) } if other_target_record_source?
    records.sort_by { |record| module_record_sort_value(record) }
  end

  def other_target_record_source?
    OTHER_TARGET_MODULE_SLUGS.include?(record_source_slug)
  end

  def other_target_record_visible?(record)
    return true if admin_dashboard_user?

    vrp_id = record.data["jeevika_jankar_id"].presence || record.data["vrp_id"].presence || record.data["select_vrp"].presence
    if vrp_login_user?
      return false unless current_vrp_record.present?

      return true if vrp_id.to_s == current_vrp_record.id.to_s
      return other_target_record_matches_vrp?(record, current_vrp_record)
    end

    return true unless module_cluster_incharge_login?

    visible_ids = module_cluster_visible_vrp_ids.map(&:to_s)
    return visible_ids.include?(vrp_id.to_s) if vrp_id.present?

    module_cluster_visible_vrps.any? { |vrp| other_target_record_matches_vrp?(record, vrp) }
  end

  def other_target_record_matches_vrp?(record, vrp)
    values = [
      record.data["jeevika_jankar_name"],
      record.data["vrp_name"],
      record.data["select_vrp"]
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)

    labels = [
      vrp.id,
      vrp.name,
      vrp.user_name,
      vrp.mobile_no,
      [vrp.name, vrp.mobile_no.presence].compact_blank.join(" - ")
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)

    (values & labels).any?
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
    @bill_financial_year_options = month_master_financial_year_options(month_master_rows)
    @bill_month_options = month_master_month_options(month_master_rows)
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

  def prepare_jeevika_jankar_bill_data
    month_master_rows = active_month_master_rows
    @jeevika_jankar_vrp_options = approved_vrp_id_options
    @jeevika_jankar_month_options = month_master_month_options(month_master_rows)
    @jeevika_jankar_financial_year_options = month_master_financial_year_options(month_master_rows)
    @jeevika_jankar_invoice_no = @record&.data&.[]("invoice_no").presence || generated_jeevika_jankar_invoice_no
    @jeevika_jankar_invoice_date = @record&.data&.[]("invoice_date").presence || Date.current.to_s
    @jeevika_jankar_bill_rows = jeevika_jankar_bill_rows
    @jeevika_jankar_achievement_summary = jeevika_jankar_achievement_summary(@jeevika_jankar_bill_rows)
    @jeevika_jankar_saved_items = jeevika_jankar_saved_items
  end

  def prepare_jeevika_jankar_bill_list
    @bill_detail_record = ModuleRecord.find_by(id: params[:view_id]) if params[:view_id].present?
  end

  def jeevika_bill_rows(records)
    Array(records).map do |record|
      data = record.data
      summary = jeevika_bill_summary(record)
      approval_history = jeevika_bill_approval_history(record)
      {
        id: record.id,
        edit_path: edit_module_record_path("jeevika-jankar-bill-process", record),
        view_path: module_path("jeevika-jankar-bill-list", view_id: record.id),
        download_path: download_bill_module_record_path("jeevika-jankar-bill-list", record),
        send_path: send_for_approval_module_record_path("jeevika-jankar-bill-list", record),
        approve_path: approve_bill_module_record_path("jeevika-jankar-bill-list", record),
        reject_path: reject_bill_module_record_path("jeevika-jankar-bill-list", record),
        active_path: set_bill_state_module_record_path("jeevika-jankar-bill-list", record, state: "Active"),
        inactive_path: set_bill_state_module_record_path("jeevika-jankar-bill-list", record, state: "Inactive"),
        delete_path: module_record_path("jeevika-jankar-bill-list", record),
        status: jeevika_bill_status_label(record),
        status_class: jeevika_bill_status_class(record),
        current_approver: jeevika_bill_current_approver?(record),
        approval_remarks: bill_approval_remarks_text(approval_history),
        record_state: data["record_state"].presence || "Active",
        bill_id: record.id,
        vrp_id: data["select_vrp"],
        name: jeevika_jankar_display_name(data["select_vrp_name"].presence || jeevika_jankar_vrp_label(data["select_vrp"])),
        financial_year: data["financial_year"].presence || "-",
        bill_month: data["bill_month"].presence || "-",
        activity_groups: summary[:activity_groups].presence || "-",
        activity_names: summary[:activity_names].presence || "-",
        target: data["total_target"].presence || "0",
        achievement: data["total_achievement"].presence || "0",
        amount: data["grand_total"].presence || "0.00"
      }
    end
  end

  def jeevika_bill_detail_rows(record)
    raw_items = record&.data&.[]("bill_items")
    raw_items = raw_items.values if raw_items.is_a?(Hash)
    Array(raw_items).select { |item| item.respond_to?(:[]) }
  end

  def jeevika_bill_summary(record)
    data = record&.data || {}
    items = jeevika_bill_detail_rows(record)
    amount = data["grand_total"].presence || items.sum { |item| item["amount"].to_f }
    deduction = data["deduction_amount"].presence || data["deduction"].presence
    payable = amount.to_f - deduction.to_f

    {
      to: first_present_data(data, "to", "to_name", "to_office").presence || first_present_from_items(items, "to", "to_name", "to_office"),
      fco: first_present_data(data, "fco", "fco_name").presence || first_present_from_items(items, "fco", "fco_name"),
      projects: first_present_data(data, "projects", "project", "select_project").presence || first_present_from_items(items, "project", "projects"),
      activity_groups: items.filter_map { |item| item["main_activity"].presence }.uniq.join(", "),
      activity_names: items.filter_map { |item| item["activity"].presence }.uniq.join(", "),
      total_amount: amount,
      deduction_amount: deduction,
      total_payable: payable
    }
  end

  def jeevika_bill_attachment_rows(record)
    vrp = jeevika_bill_vrp(record)
    [
      ["VRP Photo", vrp&.photo],
      ["VRP Aadhaar Card", vrp&.aadhar_upload],
      ["VRP Bank Passbook", vrp&.bank_passbook_upload]
    ]
  end

  def jeevika_bill_time_slot_rows(record)
    jeevika_bill_detail_rows(record).flat_map do |item|
      dates = item["timesheet_dates"].to_s.split(",").map(&:strip).reject(&:blank?)
      dates = Array(item["farmer_details"]).filter_map { |farmer| farmer["training_date"].presence }.uniq if dates.blank?
      dates = ["-"] if dates.blank?

      dates.map do |date|
        {
          working_date: bill_display_date(date),
          village: item["village"].presence || "-",
          activity: item["main_activity"].presence || "-",
          tci: item["activity"].presence || "-",
          number: item["achievement_count"].presence || item["assigned_count"].presence || "0"
        }
      end
    end
  end

  def jeevika_bill_description_rows(record)
    jeevika_bill_detail_rows(record)
      .group_by { |item| item["main_activity"].presence || item["activity"].presence || "Activity" }
      .map.with_index do |(description, rows), index|
        {
          index: index + 1,
          description: description,
          rate: rows.find { |item| item["rate"].present? }&.[]("rate").presence || "0.00",
          number: dashboard_quantity(rows.sum { |item| item["achievement_count"].to_f }),
          total: rows.sum { |item| item["amount"].to_f }
        }
      end
  end

  def jeevika_bill_bank_rows(record)
    vrp = jeevika_bill_vrp(record)
    return [] unless vrp

    [
      {
        bank_name: vrp.bank_name.presence || (vrp.vrp_bank_master&.name).presence || "-",
        account_number: vrp.account_no.presence || "-",
        ifsc_code: vrp.ifsc_code.presence || "-",
        address: vrp.address.presence || vrp.branch.presence || "-"
      }
    ]
  end

  def jeevika_bill_prepared_by(record)
    sent_history = jeevika_bill_approval_history(record).find { |history| history.data["action"].to_s == "Sent for Approval" }
    {
      name: sent_history&.data&.[]("action_by").presence || "-",
      at: bill_display_datetime(sent_history&.data&.[]("action_at").presence || record.created_at)
    }
  end

  def jeevika_bill_approved_by_rows(record)
    jeevika_bill_approval_history(record)
      .select { |history| history.data["action"].to_s == "Approved" }
      .map do |history|
        [
          history.data["approval_level"].presence || "Approval",
          history.data["approver"].presence || history.data["action_by"].presence || "-",
          bill_display_datetime(history.data["action_at"]),
          history.data["action_by"].presence
        ]
      end
  end

  def jeevika_bill_status_label(record)
    record.data["status"].presence || "Submitted (Not sent for approval)"
  end

  def jeevika_bill_status_class(record)
    status = jeevika_bill_status_label(record).downcase
    return "approved" if status.include?("final approved")
    return "returned" if status.include?("returned")
    return "rejected" if status.include?("rejected")
    return "pending" if status.include?("pending")

    "submitted"
  end

  def bill_approval_remarks_text(history)
    Array(history)
      .reject { |record| record.data["remarks"].to_s.strip.blank? }
      .map do |record|
        [
          record.data["approval_level"].presence || "Approval",
          record.data["action"].presence,
          record.data["action_by"].presence || record.data["approver"].presence,
          record.data["remarks"].presence
        ].compact.join(" - ")
      end
      .join(" | ")
      .presence || "-"
  end

  def jeevika_bill_approval_steps(record)
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "approval-master")
      .order(created_at: :asc)
      .select { |step| active_module_record?(step) }
      .select { |step| ["Jeevika Jankar Bill", "VRP Bill"].any? { |name| dashboard_value_matches?(step.data["module_name"], name) } }
      .sort_by { |step| approval_sequence_from_level(step.data["approval_level"]) }
  end

  def jeevika_bill_approval_history(record)
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "jeevika-jankar-bill-approval-history")
      .order(created_at: :asc)
      .select { |history| history.data["bill_id"].to_s == record.id.to_s }
  end

  def jeevika_bill_current_approval_step(record)
    sequence = record.data["approval_current_sequence"].to_i
    sequence = 1 if sequence.zero?
    jeevika_bill_approval_steps(record).find { |step| approval_sequence_from_level(step.data["approval_level"]) == sequence }
  end

  def jeevika_bill_current_approver?(record)
    step = jeevika_bill_current_approval_step(record)
    return false unless step

    current_labels = [
      current_app_user&.dig("username"),
      current_app_user&.dig("user_name"),
      current_app_user&.dig("name")
    ].map { |value| normalize_approval_label(value) }.reject(&:blank?)
    current_labels.include?(normalize_approval_label(step.data["approver_approved_by"]))
  end

  def update_bill_approval(action)
    load_module!
    record = ModuleRecord.find(params[:id])
    step = jeevika_bill_current_approval_step(record)
    redirect_to module_path("jeevika-jankar-bill-list", view_id: record.id), alert: "Approval channel not found." and return unless step
    redirect_to module_path("jeevika-jankar-bill-list", view_id: record.id), alert: "Please enter remarks." and return if params[:remarks].to_s.strip.blank?

    if ["Rejected", "Returned"].include?(action)
      create_bill_approval_history(record, action, step)
      update_bill_status!(record, action, current_sequence: approval_sequence_from_level(step.data["approval_level"]))
      redirect_to module_path("jeevika-jankar-bill-list", view_id: record.id), notice: "Bill #{action.downcase}."
      return
    end

    create_bill_approval_history(record, action, step)
    next_step = jeevika_bill_approval_steps(record).find { |candidate| approval_sequence_from_level(candidate.data["approval_level"]) > approval_sequence_from_level(step.data["approval_level"]) }

    if next_step
      update_bill_status!(record, "Pending at #{next_step.data["approver_approved_by"]}", current_sequence: approval_sequence_from_level(next_step.data["approval_level"]))
    else
      update_bill_status!(record, "Final Approved", current_sequence: approval_sequence_from_level(step.data["approval_level"]))
    end

    redirect_to module_path("jeevika-jankar-bill-list", view_id: record.id), notice: "Bill approved."
  end

  def update_bill_status!(record, status, current_sequence:)
    record.update!(data: record.data.merge("status" => status, "approval_current_sequence" => current_sequence.to_s))
  end

  def create_bill_approval_history(record, action, step)
    ModuleRecord.create!(
      module_slug: "jeevika-jankar-bill-approval-history",
      data: {
        "bill_id" => record.id.to_s,
        "action" => action,
        "approval_level" => step.data["approval_level"],
        "approver" => step.data["approver_approved_by"],
        "remarks" => params[:remarks].to_s,
        "action_by" => current_app_user&.dig("name").presence || current_app_user&.dig("username").to_s,
        "action_at" => Time.current.iso8601
      }
    )
  end

  def approved_vrp_id_options
    return [] unless model_ready?(:Vrp)

    scope = Vrp.where(status: 55)
    scope = scope.where(is_active: true) if Vrp.column_names.include?("is_active")
    scope = scope.where(id: current_vrp_record.id) if vrp_login_user? && current_vrp_record.present?

    vrps = scope.order(:name).to_a
    vrps = vrps.select { |vrp| module_cluster_vrp_visible?(vrp) } if module_cluster_incharge_login?

    vrps.map do |vrp|
      label = vrp.name.presence || vrp.user_name.presence
      [label.presence || "VRP ##{vrp.id}", vrp.id.to_s]
    end
  end

  def module_cluster_incharge_login?
    return false if admin_dashboard_user? || vrp_login_user?

    current_role = [
      current_app_user&.dig("role"),
      current_app_user&.dig("role_name")
    ].compact_blank.join(" ")
    return true if current_role.downcase.include?("cluster")

    mapped_labels = hierarchy_cluster_incharge_labels.map { |label| normalize_cluster_label(label) }
    current_labels = current_cluster_incharge_labels.map { |label| normalize_cluster_label(label) }
    (mapped_labels & current_labels).any?
  end

  def module_cluster_vrp_visible?(vrp)
    labels = current_cluster_incharge_labels.map { |label| normalize_cluster_label(label) }.reject(&:blank?).uniq
    return false if labels.blank?

    labels.include?(normalize_cluster_label(vrp.cluster_incharge))
  end

  def module_cluster_visible_vrp_ids
    module_cluster_visible_vrps.map(&:id)
  end

  def module_cluster_visible_vrps
    return [] unless model_ready?(:Vrp)

    @module_cluster_visible_vrps ||= Vrp
      .where.not(cluster_incharge: [nil, ""])
      .order(:name, :id)
      .select { |vrp| module_cluster_vrp_visible?(vrp) }
  end

  def current_cluster_incharge_labels
    labels = [
      current_app_user&.dig("name"),
      current_app_user&.dig("username"),
      current_app_user&.dig("user_name")
    ]

    labels.concat(user_model_cluster_labels)
    labels.concat(legacy_user_cluster_labels)
    labels.compact_blank.uniq
  end

  def user_model_cluster_labels
    return [] unless model_ready?(:User)

    user = User.find_by(user_name: current_app_user&.dig("username")) || User.find_by(id: current_app_user&.dig("id"))
    return [] unless user

    full_name = user.respond_to?(:full_name) ? user.full_name : nil
    user_name = user.respond_to?(:user_name) ? user.user_name : nil
    [full_name, user_name]
  end

  def legacy_user_cluster_labels
    return [] unless model_ready?(:ModuleRecord)

    username = current_app_user&.dig("username").to_s
    return [] if username.blank?

    record = ModuleRecord
      .where(module_slug: "new-user")
      .order(created_at: :desc)
      .detect { |row| row.data["user_name"].to_s == username }
    return [] unless record

    full_name = [record.data["first_name"], record.data["last_name"]].compact_blank.join(" ").presence
    [full_name, record.data["user_name"], record.data["name"]]
  end

  def normalize_cluster_label(label)
    normalize_dashboard_text(label.to_s.sub(/\s*\([^)]*\)\s*\z/, ""))
  end

  def generated_jeevika_jankar_invoice_no
    "JJB-#{Time.current.strftime("%Y%m%d%H%M")}"
  end

  def jeevika_jankar_achievement_summary(rows)
    Array(rows).each_with_object({}) do |row, summary|
      vrp_id = row[:vrp_id].to_s
      month_key = normalize_dashboard_text(row[:month_name])
      next if vrp_id.blank?

      summary[vrp_id] ||= {}
      summary[vrp_id]["__all"] = summary[vrp_id].fetch("__all", 0) + row[:achievement_count].to_i
      summary[vrp_id][month_key] = summary[vrp_id].fetch(month_key, 0) + row[:achievement_count].to_i if month_key.present?
    end
  end

  def jeevika_jankar_saved_items
    raw_items = @record&.data&.[]("bill_items")
    raw_items = raw_items.values if raw_items.is_a?(Hash)
    Array(raw_items).select { |item| item.respond_to?(:[]) }
  end

  def approved_other_target_achievement_index
    return {} unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: OTHER_TARGET_MODULE_SLUGS)
      .order(updated_at: :desc)
      .select { |record| approved_other_target_record?(record) }
      .each_with_object({}) do |record, index|
        target_mapping_id = record.data["target_mapping_id"].to_s
        next if target_mapping_id.blank? || index.key?(target_mapping_id)

        achievement = decimal_value(record.data["achievement"])
        next if achievement.nil?

        index[target_mapping_id] = {
          achievement: achievement.to_f,
          source_module: record.module_slug,
          source_record_id: record.id.to_s,
          achieved_at: (parse_module_date(record.data["achievement_date"]) || record.updated_at.to_date).to_s
        }
      end
  end

  def approved_other_target_record?(record)
    return false if truthy_module_flag?(record.data["deleted"]) ||
      truthy_module_flag?(record.data["is_deleted"]) ||
      truthy_module_flag?(record.data["discarded"])

    status = record.data["approval_status"].presence || record.data["approval_state"].presence || record.data["status"].presence
    return true if status.blank?

    normalized_status = normalize_dashboard_text(status)
    return false if normalized_status.include?("reject") ||
      normalized_status.include?("return") ||
      normalized_status.include?("pending") ||
      normalized_status == "inactive"

    normalized_status == "active" || normalized_status.include?("approved")
  end

  def jeevika_jankar_bill_rows
    return [] unless model_ready?(:TargetMapping)

    targets = TargetMapping.includes(:vrp)
    targets = targets.where(vrp_id: current_vrp_record.id) if vrp_login_user? && current_vrp_record.present?
    targets = targets.where(vrp_id: module_cluster_visible_vrp_ids) if module_cluster_incharge_login?
    targets = targets.order(:month_name, :vrp_id, :village_name, :main_activity_name, :activity_name, :id)
    farmers_by_id = jeevika_jankar_farmers_by_id(targets)
    training_index = jeevika_jankar_training_index(targets)
    activity_settings = jeevika_jankar_main_activity_settings
    sub_activity_settings = jeevika_jankar_sub_activity_settings(activity_settings)
    other_target_achievement_index = approved_other_target_achievement_index

    targets.map do |target|
      activity_setting = jeevika_jankar_activity_setting_for(target, activity_settings, sub_activity_settings)
      main_activity_type = activity_setting&.dig(:main_activity_type).presence || "Training"
      achievement_entry_mode = activity_setting&.dig(:achievement_entry_mode).presence || "Auto Fill"
      farmer_ids = Array(target.afl_ids).map(&:to_s).reject(&:blank?).uniq
      target_quantity = target.target_quantity.to_f
      assigned_count = farmer_ids.any? ? farmer_ids.size : target.farmer_count.to_i
      farmer_rows = farmer_ids.map do |farmer_id|
        farmer = farmers_by_id[farmer_id]
        training_rows = Array(training_index[[target.vrp_id.to_s, target.month_name.to_s, farmer_id]])
        best_training = best_training_for_target(target, training_rows)
        same_activity = training_matches_target_activity?(target, best_training)

        {
          id: farmer_id,
          name: farmer&.farmer_name.presence || "Farmer ##{farmer_id}",
          father_name: farmer&.father_name,
          mobile_no: farmer&.mobile_no,
          tracenet_no: farmer&.tracenet_no,
          department: best_training&.dig(:department),
          training_topic: best_training&.dig(:training_topic),
          training_subject: best_training&.dig(:training_subject),
          training_date: best_training&.dig(:training_date),
          status: best_training.blank? ? "Pending" : (same_activity ? "Trained in Same Activity" : "Trained in Other Activity")
        }
      end

      trained_rows = farmer_rows.reject { |row| row[:status] == "Pending" }
      same_count = farmer_rows.count { |row| row[:status] == "Trained in Same Activity" }
      other_count = farmer_rows.count { |row| row[:status] == "Trained in Other Activity" }
      achievement_count = trained_rows.size
      other_target_achievement = other_target_achievement_index[target.id.to_s]

      unless training_main_activity_type?(main_activity_type)
        if other_target_achievement.present?
          achievement_count = other_target_achievement[:achievement]
          other_count = achievement_count
          achievement_entry_mode = "Auto Fill"
        else
          achievement_count = 0
          other_count = 0
          achievement_entry_mode = "Self"
        end
      end
      pending_base = training_main_activity_type?(main_activity_type) ? assigned_count : target_quantity

      {
        target_mapping_id: target.id.to_s,
        vrp_id: target.vrp_id.to_s,
        vrp_name: target.vrp&.name.presence || "VRP ##{target.vrp_id}",
        month_name: target.month_name,
        fco: target.fco_name.presence || target.fco_id,
        ics: target.ics_name.presence || target.ics_id,
        village: target.village_name.presence || target.village_id,
        main_activity: target.main_activity_name,
        main_activity_type: main_activity_type,
        activity: target.activity_name,
        target_quantity: target_quantity,
        assigned_count: assigned_count,
        achievement_count: achievement_count,
        achievement_entry_mode: achievement_entry_mode,
        same_activity_count: same_count,
        other_activity_count: other_count,
        pending_count: [pending_base - achievement_count, 0].max,
        timesheet_dates: (other_target_achievement&.dig(:achieved_at).presence || trained_rows.filter_map { |row| row[:training_date].presence }.uniq.join(", ")),
        farmer_details: farmer_rows
      }
    end
  end

  def jeevika_jankar_main_activity_settings
    return {} unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "add-activity-group")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .each_with_object({}) do |record, settings|
        name = normalize_dashboard_text(record.data["main_activity_name"].presence || record.data["activity_group_name"])
        next if name.blank? || settings.key?(name)

        settings[name] = {
          main_activity_name: record.data["main_activity_name"].presence || record.data["activity_group_name"],
          main_activity_type: record.data["main_activity_type"].presence || "Training",
          achievement_entry_mode: record.data["achievement_fill"].presence || record.data["achievement_entry_mode"].presence || "Auto Fill"
        }
      end
  end

  def training_setup_sub_activities_by_main
    return {} unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "add-vrp-activity")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |record, result|
        main_activity = first_present_data(record, "main_activity", "activity_group", "activity_group_name", "group_name").to_s.strip
        sub_activity = first_present_data(record, "sub_activity_name", "activity_name", "vrp_activity_name", "activity").to_s.strip
        next if main_activity.blank? || sub_activity.blank?

        result[normalize_dashboard_text(main_activity)] |= [sub_activity]
      end
  end

  def jeevika_jankar_sub_activity_settings(activity_settings)
    return {} unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "add-vrp-activity")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .each_with_object({}) do |record, settings|
        main_activity_key = normalize_dashboard_text(first_present_data(record, "main_activity", "activity_group", "activity_group_name", "group_name"))
        sub_activity_key = normalize_dashboard_text(first_present_data(record, "sub_activity_name", "activity_name", "vrp_activity_name", "activity"))
        next if main_activity_key.blank? || sub_activity_key.blank? || settings.key?(sub_activity_key)

        main_setting = activity_settings[main_activity_key]
        settings[sub_activity_key] = main_setting if main_setting.present?
      end
  end

  def jeevika_jankar_activity_setting_for(target, activity_settings, sub_activity_settings)
    main_key = normalize_dashboard_text(target.main_activity_name)
    sub_key = normalize_dashboard_text(target.activity_name)

    activity_settings[main_key] ||
      activity_settings[sub_key] ||
      sub_activity_settings[sub_key] ||
      sub_activity_settings[main_key]
  end

  def jeevika_jankar_farmers_by_id(targets)
    return {} unless model_ready?(:Afl)

    farmer_ids = targets.flat_map { |target| Array(target.afl_ids).map(&:to_s) }.reject(&:blank?).uniq
    return {} if farmer_ids.blank?

    Afl.where(id: farmer_ids).index_by { |farmer| farmer.id.to_s }
  end

  def jeevika_jankar_training_index(targets)
    return {} unless model_ready?(:ModuleRecord)

    vrps = targets.map(&:vrp).compact.uniq(&:id)
    target_farmer_ids = targets.flat_map { |target| Array(target.afl_ids).map(&:to_s) }.reject(&:blank?).uniq
    target_farmer_ids_by_vrp = targets.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |target, result|
      result[target.vrp_id.to_s] |= Array(target.afl_ids).map(&:to_s).reject(&:blank?)
    end
    target_months = targets.map { |target| target.month_name.to_s }.reject(&:blank?).uniq
    records = ModuleRecord.where(module_slug: "training-form").order(created_at: :desc).select { |record| active_module_record?(record) }

    records.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |record, index|
      farmer_ids = Array(record.data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?) & target_farmer_ids
      next if farmer_ids.blank?

      matching_vrps = vrps.select { |vrp| training_record_matches_vrp?(record, vrp) }
      if matching_vrps.blank?
        matching_vrps = vrps.select { |vrp| (target_farmer_ids_by_vrp[vrp.id.to_s] & farmer_ids).any? }
      end
      next if matching_vrps.blank?

      target_months.each do |month_name|
        matching_vrps.each do |vrp|
          vrp_farmer_ids = farmer_ids & target_farmer_ids_by_vrp[vrp.id.to_s]
          vrp_farmer_ids.each do |farmer_id|
            index[[vrp.id.to_s, month_name.to_s, farmer_id]] << training_summary(record)
          end
        end
      end
    end
  end

  def training_record_matches_vrp?(record, vrp)
    values = [
      record.data["trainer_contact"],
      record.data["trainer_name"],
      record.data["select_vrp"],
      record.data["vrp_name"]
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)

    labels = [
      vrp.id,
      vrp.name,
      vrp.mobile_no,
      vrp.user_name,
      [vrp.name, vrp.mobile_no.presence].compact_blank.join(" - ")
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)

    (values & labels).any?
  end

  def training_record_matches_month?(record, month_name)
    return true if month_name.blank?

    record_month = record.data["month"].presence
    return normalize_dashboard_text(record_month) == normalize_dashboard_text(month_name) if record_month.present?

    training_date = parse_module_date(record.data["training_date"])
    return true if training_date.blank?

    normalize_dashboard_text(training_date.strftime("%B")) == normalize_dashboard_text(month_name)
  end

  def parse_module_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def training_summary(record)
    {
      department: record.data["department"].presence || record.data["trainee_department"],
      month: record.data["month"].presence || parse_module_date(record.data["training_date"])&.strftime("%B"),
      training_topic: record.data["main_activity"].presence || record.data["training_topic"],
      training_subject: record.data["sub_activity"].presence || record.data["training_subject"],
      training_date: record.data["training_date"]
    }
  end

  def training_record_month_name(record)
    training_summary(record)[:month]
  end

  def best_training_for_target(target, training_rows)
    Array(training_rows).find { |row| training_matches_target_activity?(target, row) } || Array(training_rows).first
  end

  def training_matches_target_activity?(target, training_row)
    return false if training_row.blank?

    topic_matches = normalize_dashboard_text(training_row[:training_topic]) == normalize_dashboard_text(target.main_activity_name)
    subject_matches = normalize_dashboard_text(training_row[:training_subject]) == normalize_dashboard_text(target.activity_name)
    topic_matches && subject_matches
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

  def month_master_month_options(records = active_month_master_rows)
    Array(records)
      .filter_map { |record| first_present_data(record, "month_name", "month", "name", "select_bill_month") }
      .map(&:to_s)
      .map(&:strip)
      .reject(&:blank?)
      .uniq
      .sort_by { |month| [dashboard_month_index(month), month] }
  end

  def month_master_financial_year_options(records = active_month_master_rows)
    Array(records)
      .filter_map { |record| first_present_data(record, "financial_year", "year", "fy") }
      .map(&:to_s)
      .map(&:strip)
      .reject(&:blank?)
      .uniq
      .sort
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
    data = record.respond_to?(:data) ? record.data : record
    data ||= {}
    keys.filter_map { |key| data[key].presence }.first
  end

  def record_source_slug
    slug = @slug || current_slug
    RECORD_SOURCE_SLUGS.fetch(slug, slug)
  end

  def module_redirect_slug
    {
      "training-form" => "training-form-list",
      "vrp-bill-add" => "vrp-bill-list",
      "jeevika-jankar-bill-process" => "jeevika-jankar-bill-list",
      "seed-distribution-target" => "seed-distribution-target-list",
      "papl360-target" => "papl360-target-list"
    }.fetch(record_source_slug, @slug)
  end

  def module_record_sort_value(record)
    visible_fields = @module&.dig(:fields) || []
    sort_field = visible_fields.reject { |field| field == "Status" }.first
    sort_key = sort_field&.parameterize(separator: "_")

    module_record_field_value(record, sort_field).presence ||
      record.data[sort_key].presence ||
      record.data.values.find(&:present?).to_s
  end

  def module_record_field_value(record, field)
    return nil if field.blank?
    return village_master_gram_panchayat_name(record) if record.module_slug == "village-master" && field == "Gram Panchayat"

    keys = [
      field.parameterize(separator: "_"),
      *module_field_aliases(field)
    ].compact.uniq
    value = first_present_data(record, *keys)
    return approval_level_display_label(value) if field == "Approval Level"

    value
  end

  def village_master_gram_panchayat_name(record)
    direct_name = first_non_code_data(record, "gram_panchayat_name", "gp_name", "gram_name", "gram_panchayat")
    return direct_name if direct_name.present? && !code_like_location_value?(direct_name)

    code = first_present_data(record, "gp_code", "gram_code", "gram_panchayat_code", "gram_panchayat_id", "gram_panchayat", "gram_panchayat_name", "gp_name", "gram_name")
    return direct_name.presence || code if code.blank?

    gram_panchayat_name_lookup[code.to_s.strip.downcase].presence ||
      gram_panchayat_name_by_location(record, code).presence ||
      (direct_name.present? && !code_like_location_value?(direct_name) ? direct_name : nil) ||
      (code_like_location_value?(code) ? "-" : code)
  end

  def gram_panchayat_name_lookup
    @gram_panchayat_name_lookup ||= ModuleRecord
      .where(module_slug: ["gram-panchayat-master", "lg-directory-list", "village-master"])
      .select { |record| active_module_record?(record) }
      .each_with_object({}) do |record, lookup|
        label = gram_panchayat_name_from_record(record)
        next if label.blank? || code_like_location_value?(label)

        %w[gp_code gram_code gram_panchayat_code gram_panchayat_id gram_panchayat gram_panchayat_name gp_name gram_name name].each do |key|
          value = record.data[key].to_s.strip
          lookup[value.downcase] = label if value.present? && code_like_location_value?(value)
        end
      end
  end

  def gram_panchayat_name_by_location(record, code)
    normalized_code = normalize_dashboard_text(code)
    return "" if normalized_code.blank?

    state = normalize_dashboard_text(first_present_data(record, "state", "state_name"))
    district = normalize_dashboard_text(first_present_data(record, "district", "district_name"))
    block = normalize_dashboard_text(first_present_data(record, "block", "block_name", "cd_block_name"))
    return "" if state.blank? || district.blank? || block.blank?

    ModuleRecord
      .where(module_slug: ["gram-panchayat-master", "lg-directory-list"])
      .select { |candidate| active_module_record?(candidate) }
      .find do |candidate|
        code_matches = %w[gp_code gram_code gram_panchayat_code gram_panchayat_id gram_panchayat gram_panchayat_name gp_name gram_name name].any? do |key|
          normalize_dashboard_text(candidate.data[key]) == normalized_code
        end

        code_matches &&
        normalize_dashboard_text(first_present_data(candidate, "state", "state_name")) == state &&
          normalize_dashboard_text(first_present_data(candidate, "district", "district_name")) == district &&
          normalize_dashboard_text(first_present_data(candidate, "block", "block_name", "cd_block_name")) == block &&
          !code_like_location_value?(gram_panchayat_name_from_record(candidate))
      end
      &.then { |candidate| gram_panchayat_name_from_record(candidate) }
  end

  def module_field_aliases(field)
    {
      "GP Code" => ["gp_code", "gram_code"],
      "Gram Code" => ["gp_code", "gram_code"],
      "Gram Panchayat Name" => ["gram_panchayat_name", "gram_panchayat", "gram_name"],
      "Gram Panchayat" => ["gram_panchayat", "gram_panchayat_name", "gram_name"],
      "Completion Date" => ["completion_date", "date"],
      "Date" => ["completion_date", "date"],
      "Village Name" => ["village_name", "village", "name"],
      "Village Code" => ["village_code"],
      "Block Name" => ["block_name", "block", "cd_block_name"],
      "Block Code" => ["block_code", "cd_block_code"],
      "District Name" => ["district_name", "district"],
      "District Code" => ["district_code"],
      "Jeevika Jankar Type" => ["jeevika_jankar_type", "vrp_type", "select_vrp_type"],
      "Jeevika Jankar Type Name" => ["jeevika_jankar_type_name", "vrp_type_name", "position_type_name"],
      "Main Activity" => ["main_activity", "training_topic", "activity_group", "activity_group_name"],
      "Sub Activity" => ["sub_activity", "training_subject", "activity_name", "vrp_activity_name"],
      "State Name" => ["state_name", "state"],
      "State Code" => ["state_code"]
    }.fetch(field.to_s, [])
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
      data["vrp_type"] = data["jeevika_jankar_type"] if data["jeevika_jankar_type"].present?
      data["jeevika_jankar_type"] = data["vrp_type"].presence || data["select_vrp_type"] if data["jeevika_jankar_type"].blank?
    end

    if record_source_slug == "user-hierarchy-mapping"
      level_2_mappings = normalize_user_hierarchy_mappings(data)
      level_2_users = level_2_mappings.filter_map { |mapping| mapping["level_2_user"].presence }.uniq

      data["level_2_mappings"] = level_2_mappings
      data["level_2_users"] = level_2_users
      data["level_2_user"] = level_2_users.join(", ")
      data["level_3_users"] = []
      data["level_3_user"] = ""
      data["status"] = data["status"].presence || "Active"
    end

    if record_source_slug == "parent-office-add"
      data["parent_office_type"] = data["parent_office_type"].presence || (data["parent_office"].present? ? "Sub Parent Office" : "Parent Office")
      data["parent_office"] = "" if data["parent_office_type"] == "Parent Office"
    end

    data = normalize_training_form_data(data) if record_source_slug == "training-form"
    data = normalize_seed_distribution_target_data(data) if other_target_record_source?
    data = normalize_jeevika_jankar_bill_data(data) if record_source_slug == "jeevika-jankar-bill-process"

    data
  end

  def normalize_jeevika_jankar_bill_data(data)
    bill_items = data["bill_items"]
    bill_items = bill_items.values if bill_items.is_a?(Hash)
    bill_items = Array(bill_items).filter_map do |item|
      next unless item.respond_to?(:to_h)

      item = item.to_h
      item["farmer_details"] = parse_bill_farmer_details(item["farmer_details"])
      item["achievement_count"] = numeric_string(item["achievement_count"])
      item["target_quantity"] = numeric_string(item["target_quantity"])
      item["assigned_count"] = numeric_string(item["assigned_count"])
      item["same_activity_count"] = numeric_string(item["same_activity_count"])
      item["other_activity_count"] = numeric_string(item["other_activity_count"])
      item["main_activity_type"] = item["main_activity_type"].presence || data["main_activity_type"].presence || "Training"
      item["achievement_entry_mode"] = item["achievement_entry_mode"].presence || data["achievement_entry_mode"].presence || "Auto Fill"
      item["pending_count"] = dashboard_quantity([item["assigned_count"].to_f - item["achievement_count"].to_f, 0].max)
      item["rate"] = decimal_string(item["rate"])
      item["amount"] = decimal_string(item["achievement_count"].to_f * item["rate"].to_f)
      item
    end

    total_target = bill_items.sum { |item| item["target_quantity"].to_f }
    total_achievement = bill_items.sum { |item| item["achievement_count"].to_f }
    grand_total = bill_items.sum { |item| item["amount"].to_f }

    data["invoice_no"] = data["invoice_no"].presence || generated_jeevika_jankar_invoice_no
    data["invoice_date"] = data["invoice_date"].presence || Date.current.to_s
    data["select_vrp_name"] = jeevika_jankar_vrp_label(data["select_vrp"])
    data["main_activity_type"] = data["main_activity_type"].presence || "Training"
    data["achievement_entry_mode"] = data["achievement_entry_mode"].presence || "Auto Fill"
    data["bill_items"] = bill_items
    data["total_target"] = dashboard_quantity(total_target)
    data["total_achievement"] = dashboard_quantity(total_achievement)
    data["grand_total"] = format("%.2f", grand_total)
    data["status"] = data["status"].presence || "Submitted (Not sent for approval)"
    data["record_state"] = data["record_state"].presence || "Active"
    data
  end

  def jeevika_jankar_vrp_label(vrp_id)
    return "" if vrp_id.blank? || !model_ready?(:Vrp)

    vrp = Vrp.find_by(id: vrp_id)
    return "" unless vrp

    vrp&.name.presence || vrp&.user_name.presence || "Jeevika Jankar ##{vrp.id}"
  end

  def jeevika_jankar_display_name(value)
    value.to_s.strip.sub(/\s*-\s*\d{6,}\z/, "")
  end

  def bill_display_date(value)
    parse_module_date(value)&.strftime("%d/%m/%Y") || value.to_s.presence || "-"
  end

  def bill_display_datetime(value)
    Time.zone.parse(value.to_s)&.strftime("%d-%b-%Y %I:%M %p")
  rescue ArgumentError, TypeError
    value.respond_to?(:strftime) ? value.strftime("%d-%b-%Y %I:%M %p") : "-"
  end

  def jeevika_bill_vrp(record)
    return nil unless model_ready?(:Vrp)

    Vrp.find_by(id: record&.data&.[]("select_vrp"))
  end

  def first_present_from_items(items, *keys)
    items.each do |item|
      keys.each do |key|
        value = item[key].presence
        return value if value.present?
      end
    end

    nil
  end

  def jeevika_jankar_bill_record_visible?(record)
    if module_cluster_incharge_login?
      return module_cluster_visible_vrp_ids.map(&:to_s).include?(record.data["select_vrp"].to_s)
    end

    return true unless vrp_login_user?
    return false unless current_vrp_record.present?

    record.data["select_vrp"].to_s == current_vrp_record.id.to_s
  end

  def parse_bill_farmer_details(value)
    return value if value.is_a?(Array)

    JSON.parse(value.to_s)
  rescue JSON::ParserError
    []
  end

  def numeric_string(value)
    number = value.to_s.gsub(",", "").to_f
    number == number.to_i ? number.to_i.to_s : number.to_s
  end

  def decimal_string(value)
    format("%.2f", value.to_s.gsub(",", "").to_f)
  end

  def normalize_training_form_data(data)
    trainer_name, trainer_contact = training_trainer_defaults
    data["trainer_name"] = trainer_name if trainer_name.present?
    data["trainer_contact"] = trainer_contact if trainer_contact.present?
    data["trainee_department"] = training_trainee_department_default if data["trainee_department"].blank?
    data["main_activity_type"] = data["main_activity_type"].presence || "Training"
    data["main_activity"] = data["main_activity"].presence || data["training_topic"].presence
    data["sub_activity"] = data["sub_activity"].presence || data["training_subject"].presence
    data["training_topic"] = data["main_activity"] if data["main_activity"].present?
    data["training_subject"] = data["sub_activity"] if data["sub_activity"].present?

    selected_farmer_ids = Array(data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?).uniq
    if training_form_activity_scope_present?(data)
      pending_farmer_ids = pending_training_farmer_ids_for(data)
      selected_farmer_ids &= pending_farmer_ids unless pending_farmer_ids.nil?
    end
    data["selected_farmer_ids"] = selected_farmer_ids
    data["selected_farmer_names"] = training_farmer_names(selected_farmer_ids)
    data["farmer_count"] = selected_farmer_ids.size.to_s if selected_farmer_ids.any?
    data.delete("status")
    data
  end

  def normalize_seed_distribution_target_data(data)
    data["main_activity_type"] = "Other"
    data["training_topic"] = data["training_topic"].presence || data["main_activity"].presence
    data["training_subject"] = data["training_subject"].presence || data["sub_activity"].presence
    data["completion_date"] = data["completion_date"].presence || data["date"].presence || Date.current.to_s

    if (mapping = seed_distribution_target_match(data))
      data["target_mapping_id"] = mapping[:target_mapping_id]
      data["jeevika_jankar_id"] = mapping[:vrp_id]
      data["jeevika_jankar_name"] = mapping[:jeevika_jankar_name]
      data["contact_number"] = mapping[:contact_number]
      data["jeevika_jankar_contact"] = mapping[:contact_number]
      data["department"] = mapping[:department]
      data["fcoc_name"] = mapping[:department]
      data["target"] = mapping[:target].to_s if data["target"].blank?
      data["main_activity"] = mapping[:training_topic]
      data["sub_activity"] = mapping[:training_subject]
    end

    if record_source_slug == "seed-distribution-target"
      selected_farmer_ids = Array(data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?).uniq
      if data["target_mapping_id"].present?
        pending_farmer_ids = pending_other_target_farmer_ids_for(data["target_mapping_id"])
        selected_farmer_ids &= pending_farmer_ids unless pending_farmer_ids.nil?
      end
      data["selected_farmer_ids"] = selected_farmer_ids
      data["selected_farmer_names"] = training_farmer_names(selected_farmer_ids)
      data["farmer_count"] = selected_farmer_ids.size.to_s if selected_farmer_ids.any?
    else
      data.delete("selected_farmer_ids")
      data.delete("selected_farmer_names")
      data.delete("farmer_count")
    end

    data["achievement"] = numeric_string(data["achievement"]) if data["achievement"].present?
    data["target"] = numeric_string(data["target"]) if data["target"].present?
    data.delete("status")
    data
  end

  def seed_distribution_target_match(data)
    selected_vrp = normalize_dashboard_text(data["jeevika_jankar_id"].presence || data["jeevika_jankar_name"])
    selected_month = normalize_dashboard_text(data["month"])
    selected_ics = normalize_dashboard_text(data["ics"])
    selected_village = normalize_dashboard_text(data["village"])
    selected_topic = normalize_dashboard_text(data["training_topic"])
    selected_subject = normalize_dashboard_text(data["training_subject"])

    seed_distribution_target_mappings.find do |mapping|
      seed_distribution_vrp_matches?(mapping, selected_vrp) &&
        normalize_dashboard_text(mapping[:month]) == selected_month &&
        normalize_dashboard_text(mapping[:ics]) == selected_ics &&
        normalize_dashboard_text(mapping[:village]) == selected_village &&
        normalize_dashboard_text(mapping[:training_topic]) == selected_topic &&
        normalize_dashboard_text(mapping[:training_subject]) == selected_subject
    end
  end

  def seed_distribution_vrp_matches?(mapping, selected_vrp)
    return false if selected_vrp.blank?

    [
      mapping[:vrp_id],
      mapping[:jeevika_jankar_name]
    ].any? { |value| normalize_dashboard_text(value) == selected_vrp }
  end

  def pending_other_target_farmer_ids_for(target_mapping_id)
    return nil unless model_ready?(:TargetMapping)

    target = TargetMapping.find_by(id: target_mapping_id)
    return [] unless target

    target_farmer_ids(target) - other_target_completed_farmer_ids_for(target.id)
  end

  def training_form_activity_scope_present?(data)
    data["month"].present? && data["gram_name"].present? && data["main_activity"].present? && data["sub_activity"].present?
  end

  def pending_training_farmer_ids_for(data)
    return nil unless model_ready?(:TargetMapping)

    selected_month = normalize_dashboard_text(data["month"])
    selected_ics = normalize_dashboard_text(data["ics_block"])
    selected_village = normalize_dashboard_text(data["gram_name"])
    selected_main_activity_type = normalize_dashboard_text(data["main_activity_type"])
    selected_main_activity = normalize_dashboard_text(data["main_activity"])
    selected_sub_activity = normalize_dashboard_text(data["sub_activity"])
    activity_settings = jeevika_jankar_main_activity_settings

    training_target_scope.each_with_object([]) do |target, ids|
      activity_setting = activity_settings[normalize_dashboard_text(target.main_activity_name)]
      next if activity_setting.blank? || !training_main_activity_type?(activity_setting[:main_activity_type])

      target_main_activity_type = normalize_dashboard_text(activity_setting[:main_activity_type].presence || "Training")
      next if normalize_dashboard_text(target.month_name) != selected_month
      next if selected_ics.present? && normalize_dashboard_text(target.ics_name.presence || target.ics_id) != selected_ics
      next if normalize_dashboard_text(target.village_name.presence || target.village_id) != selected_village
      next if selected_main_activity_type.present? && target_main_activity_type != selected_main_activity_type
      next if normalize_dashboard_text(target.main_activity_name) != selected_main_activity
      next if normalize_dashboard_text(target.activity_name) != selected_sub_activity

      farmer_ids = Array(target.afl_ids).map(&:to_s).reject(&:blank?).uniq
      ids.concat(farmer_ids - completed_training_farmer_ids_for(target, farmer_ids))
    end.uniq
  end

  def training_trainer_defaults
    if vrp_login_user? && current_vrp_record.present?
      return [current_vrp_record.name, current_vrp_record.mobile_no]
    end

    [current_app_user&.dig("name"), current_app_user&.dig("mobile_no")]
  end

  def training_trainee_department_default
    [
      registered_vrp_fcoc(current_vrp_record),
      current_app_user&.dig("fcoc"),
      current_app_user&.dig("fcoc_name")
    ].compact_blank.first.to_s
  end

  def registered_vrp_fcoc(vrp)
    vrp&.fcoc.to_s.strip
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

      users = collapsed_hierarchy_users(mapping["level_2_user"], mapping["level_3_users"])
      next if users.blank?

      users.map do |level_2_user|
        {
          "level_2_user" => level_2_user,
          "level_3_users" => []
        }
      end
    end
    mappings.flatten!

    return mappings if mappings.any?

    collapsed_hierarchy_users(data["level_2_users"], data["level_3_users"]).map do |level_2_user|
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
    vrp_type = normalized_access_value(data["jeevika_jankar_type"].presence || data["vrp_type"].presence || data["select_vrp_type"])
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
          normalized_access_value(record.data["jeevika_jankar_type"].presence || record.data["vrp_type"].presence || record.data["select_vrp_type"]) == vrp_type &&
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

  def update_approval_channel(record)
    data = normalized_module_data
    steps = data.delete("approval_steps").to_h
    channel_records = approval_channel_records_for(record)
    records_by_sequence = channel_records.group_by { |approval_record| approval_sequence_from_level(approval_record.data["approval_level"]) }
    saved_records = []

    steps.each do |level, approver|
      next if approver.blank?

      sequence = approval_sequence_from_level(level)
      approval_record = records_by_sequence[sequence]&.shift || ModuleRecord.new(module_slug: "approval-master")
      approval_record.data = data.merge(
        "approval_level" => level,
        "approver_approved_by" => approver,
        "status" => data["status"].presence || "Active"
      )
      approval_record.save!
      saved_records << approval_record
    end

    if saved_records.blank?
      @record = record
      @records = module_records
      prepare_approval_channel_form(record)
      flash.now[:alert] = "Please select at least one approval user."
      render :show, status: :unprocessable_entity
      return
    end

    stale_records = (channel_records - saved_records)
    stale_records.each(&:destroy)

    redirect_to module_path("approval-list"), notice: "Approval channel updated successfully."
  rescue ActiveRecord::RecordInvalid => e
    @record = record
    @records = module_records
    prepare_approval_channel_form(record)
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :show, status: :unprocessable_entity
  end

  def prepare_approval_channel_form(record)
    @approval_channel_records = approval_channel_records_for(record)
  end

  def approval_channel_records_for(record)
    return [] unless record

    data = record.data
    ModuleRecord
      .where(module_slug: "approval-master")
      .order(created_at: :asc)
      .select { |approval_record| same_approval_channel?(approval_record.data, data) }
  end

  def same_approval_channel?(left_data, right_data)
    ["module_name", "stakeholder_name", "user_name"].all? do |key|
      left_data[key].to_s.strip.casecmp(right_data[key].to_s.strip).zero?
    end
  end

  def user_hierarchy_list_rows(records)
    records.flat_map do |record|
      base = {
        id: record.id,
        edit_path: edit_module_record_path("user-hierarchy-mapping", record),
        stakeholder: record.data["stakeholder_category"].presence || "-",
        level_1_user: record.data["level_1_user"].presence || "-",
        status: record.data["status"].presence || "Active"
      }

      mappings = normalized_user_hierarchy_list_mappings(record)
      if mappings.blank?
        users = collapsed_hierarchy_users(record.data["level_2_users"].presence || record.data["level_2_user"], record.data["level_3_users"].presence || record.data["level_3_user"])
        users = users.select { |level_2_user| cluster_incharge_user_label?(level_2_user) }
        users.map { |level_2_user| base.merge(level_2_user: level_2_user) }
      else
        mappings
          .select { |mapping| cluster_incharge_user_label?(mapping["level_2_user"]) }
          .map { |mapping| base.merge(level_2_user: mapping["level_2_user"].presence || "-") }
      end
    end
  end

  def normalized_user_hierarchy_list_mappings(record)
    mappings = record.data["level_2_mappings"]
    mappings = mappings.values if mappings.is_a?(Hash)

    Array(mappings).filter_map do |mapping|
      next unless mapping.respond_to?(:[])

      collapsed_hierarchy_users(mapping["level_2_user"], mapping["level_3_users"]).map do |level_2_user|
        { "level_2_user" => level_2_user, "level_3_users" => [] }
      end
    end
      .flatten
  end

  def collapsed_hierarchy_users(*values)
    values.flatten.flat_map do |value|
      value.to_s.split(";").flat_map do |segment|
        user_segment = segment.include?("->") ? segment.split("->", 2).last : segment
        user_segment.to_s.split(",")
      end
    end.map(&:strip).compact_blank.uniq
  end

  def cluster_incharge_user_label?(label)
    role_text = label.to_s[/\(([^)]*)\)\s*\z/, 1].to_s
    role_text.downcase.include?("cluster")
  end

  def hierarchy_cluster_incharge_labels
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "user-hierarchy-mapping")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .flat_map { |record| user_hierarchy_list_rows([record]).map { |row| row[:level_2_user] } }
      .select { |label| cluster_incharge_user_label?(label) }
      .compact_blank
      .uniq
  end

  def jeevika_jankar_cluster_rows
    return [] unless model_ready?(:Vrp)

    mapped_cluster_labels = hierarchy_cluster_incharge_labels.map { |label| normalize_dashboard_text(label.to_s.sub(/\s*\([^)]*\)\s*\z/, "")) }

    Vrp.where.not(cluster_incharge: [nil, ""]).order(updated_at: :desc, id: :desc).filter_map do |vrp|
      next if mapped_cluster_labels.any? && !mapped_cluster_labels.include?(normalize_dashboard_text(vrp.cluster_incharge))

      {
        id: vrp.id,
        name: vrp.name.presence || vrp.user_name.presence || "Jeevika Jankar ##{vrp.id}",
        user_name: vrp.user_name.presence || "-",
        mobile_no: vrp.mobile_no.presence || "-",
        office_name: vrp.fcoc.presence || vrp.to_name.presence || "-",
        cluster_incharge: vrp.cluster_incharge.presence || "-",
        status: vrp_status_for_hierarchy_list(vrp)
      }
    end
  end

  def vrp_status_for_hierarchy_list(vrp)
    return "Inactive" if vrp.respond_to?(:is_active) && vrp.is_active == false
    return "Final Approved" if vrp.status.to_i == 55
    return "Pending Approval" if vrp.status.to_i >= 25

    "Active"
  end

  def valid_module_data?(data)
    module_data_error_messages(data).blank?
  end

  def module_data_error_messages(data)
    case record_source_slug
    when "new-user"
      data["password"].to_s == data["confirmed_password"].to_s ? [] : ["Password and Confirmed Password must match."]
    when "training-form"
      training_form_error_messages(data)
    when *OTHER_TARGET_MODULE_SLUGS
      seed_distribution_target_error_messages(data)
    else
      []
    end
  end

  def training_form_error_messages(data)
    required_fields = {
      "month" => "Month",
      "ics_block" => "ICS Name",
      "gram_name" => "Village Name",
      "trainee_department" => "Trainee Department",
      "trainer_name" => "Trainer Name",
      "trainer_contact" => "Trainer Contact",
      "training_date" => "Training Date",
      "training_location" => "Training Location",
      "main_activity" => "Main Activity",
      "sub_activity" => "Sub Activity",
      "training_description" => "Training Description",
      "farmer_count" => "Farmer Count",
      "male_count" => "Male Count",
      "female_count" => "Female Count",
      "next_farmer_training_date" => "Next Farmer Training Date",
      "training_register_upload" => "Training Register Upload",
      "training_photo_upload_with_geo_tag" => "Training Photo Upload with Geo Tag"
    }

    errors = missing_required_data_errors(data, required_fields)
    selected_farmer_ids = Array(data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?).uniq
    errors << "Target Farmers select karein." if selected_farmer_ids.blank?

    farmer_count = whole_number_value(data["farmer_count"])
    male_count = whole_number_value(data["male_count"])
    female_count = whole_number_value(data["female_count"])
    errors << "Farmer Count valid whole number hona chahiye." if farmer_count.nil?
    errors << "Male Count valid whole number hona chahiye." if male_count.nil?
    errors << "Female Count valid whole number hona chahiye." if female_count.nil?

    if farmer_count && male_count && male_count > farmer_count
      errors << "Male Count Farmer Count se jyada nahi ho sakta."
    end

    if farmer_count && female_count && female_count > farmer_count
      errors << "Female Count Farmer Count se jyada nahi ho sakta."
    end

    if farmer_count && selected_farmer_ids.any? && farmer_count != selected_farmer_ids.size
      errors << "Farmer Count selected farmers ke count ke equal hona chahiye."
    end

    if farmer_count && male_count && female_count && farmer_count != male_count + female_count
      errors << "Male Count aur Female Count ka total Farmer Count ke equal hona chahiye."
    end

    errors
  end

  def seed_distribution_target_error_messages(data)
    errors = missing_required_data_errors(
      data,
      "jeevika_jankar_name" => "Jeevika Jankar Name",
      "contact_number" => "Contact Number",
      "month" => "Month",
      "ics" => "ICS",
      "village" => "Village",
      "training_topic" => "Main Activity",
      "training_subject" => "Sub Activity",
      "date" => "Date",
      "target" => "Target",
      "achievement" => "Achievement"
    )

    target = decimal_value(data["target"])
    achievement = decimal_value(data["achievement"])
    errors << "Target valid number hona chahiye." if target.nil?
    errors << "Achievement valid number hona chahiye." if achievement.nil?
    errors << "Target zero se kam nahi ho sakta." if target && target.negative?
    errors << "Achievement zero se kam nahi ho sakta." if achievement && achievement.negative?
    errors << "Achievement Target se jyada nahi ho sakta." if target && achievement && achievement > target

    if record_source_slug == "seed-distribution-target"
      farmer_count = whole_number_value(data["farmer_count"])
      selected_farmer_ids = Array(data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?).uniq
      errors << "Farmer Count required hai." if data["farmer_count"].blank?
      errors << "Mapped Farmers select karein." if selected_farmer_ids.blank?
      errors << "Farmer Count valid whole number hona chahiye." if farmer_count.nil?
      errors << "Farmer Count selected farmers ke count ke equal hona chahiye." if farmer_count && selected_farmer_ids.any? && farmer_count != selected_farmer_ids.size
      errors << "Farmer Count Target se jyada nahi ho sakta." if target && farmer_count && farmer_count > target
    end

    errors << "Mapped Other activity target select karein." if seed_distribution_target_match(data).blank?
    errors << "Contact Number valid 10 digit hona chahiye." if data["contact_number"].present? && data["contact_number"].to_s.gsub(/\D/, "").length != 10
    errors
  end

  def missing_required_data_errors(data, fields)
    fields.filter_map do |key, label|
      "#{label} required hai." if data[key].blank?
    end
  end

  def whole_number_value(value)
    string = value.to_s.strip
    return nil if string.blank? || !string.match?(/\A\d+\z/)

    string.to_i
  end

  def decimal_value(value)
    string = value.to_s.strip
    return nil if string.blank?

    BigDecimal(string)
  rescue ArgumentError
    nil
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
    return false if record_source_slug == "training-form" && field == "Trainee Department"
    return false if other_target_record_source? && field == "Department"
    return true if current_slug == "parent-office-add" && field == "Parent Office"
    return true if training_target_field?(field)
    return true if training_activity_field?(field)
    return true if seed_distribution_target_field?(field)

    source = field_sources[field]
    (source.present? && source[:module] != (@slug || current_slug)) || static_field_options(field).any?
  end

  def module_field_options(field)
    return parent_office_parent_options if current_slug == "parent-office-add" && field == "Parent Office"
    return training_target_field_options(field) if training_target_field?(field)
    return training_activity_field_options(field) if training_activity_field?(field)
    return seed_distribution_target_field_options(field) if seed_distribution_target_field?(field)

    source = field_sources[field]
    return [] unless ModuleRecord.table_exists?

    if source
      return [] if source[:module] == (@slug || current_slug)

      return values_from_module(source[:module], source[:field])
    end

    generic_field_options(field)
  end

  def training_target_field?(field)
    record_source_slug == "training-form" && ["Month", "ICS / Block", "Gram Name"].include?(field)
  end

  def training_activity_field?(field)
    record_source_slug == "training-form" && ["Main Activity", "Sub Activity"].include?(field)
  end

  def seed_distribution_target_field?(field)
    other_target_record_source? && ["Jeevika Jankar Name", "Month", "ICS", "Village", "Main Activity", "Sub Activity"].include?(field)
  end

  def seed_distribution_target_field_options(field)
    case field
    when "Jeevika Jankar Name"
      seed_distribution_target_mappings.filter_map { |mapping| mapping[:jeevika_jankar_name].presence }.uniq
    when "Month"
      seed_distribution_target_month_options
    when "ICS"
      seed_distribution_target_mappings.filter_map { |mapping| mapping[:ics].presence }.uniq
    when "Village"
      seed_distribution_target_mappings.filter_map { |mapping| mapping[:village].presence }.uniq
    when "Main Activity"
      seed_distribution_target_mappings.filter_map { |mapping| mapping[:training_topic].presence }.uniq
    when "Sub Activity"
      seed_distribution_target_mappings.filter_map { |mapping| mapping[:training_subject].presence }.uniq
    else
      []
    end
  end

  def training_target_field_options(field)
    case field
    when "Month"
      training_target_month_options
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
    when "Main Activity"
      training_target_mappings.filter_map { |mapping| mapping[:main_activity].presence }.uniq
    when "Sub Activity"
      training_target_mappings.filter_map { |mapping| mapping[:sub_activity].presence }.uniq
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

  def training_activity_setup_mappings
    activity_settings = jeevika_jankar_main_activity_settings
    sub_activities_by_main = training_setup_sub_activities_by_main

    activity_settings.filter_map do |normalized_name, setting|
      next unless training_main_activity_type?(setting[:main_activity_type])

      main_activity = setting[:main_activity_name].presence || normalized_name
      {
        main_activity: main_activity,
        main_activity_type: "Training",
        sub_activities: sub_activities_by_main[normalized_name] || []
      }
    end
  end

  def training_target_mappings
    return [] unless model_ready?(:TargetMapping)

    activity_settings = jeevika_jankar_main_activity_settings

    training_target_scope
      .order(:ics_name, :ics_id, :village_name, :village_id, :id)
      .filter_map do |target|
        activity_setting = activity_settings[normalize_dashboard_text(target.main_activity_name)]
        next if activity_setting.blank? || !training_main_activity_type?(activity_setting[:main_activity_type])

        farmer_ids = Array(target.afl_ids).map(&:to_s).reject(&:blank?).uniq
        {
          target_mapping_id: target.id.to_s,
          vrp_id: target.vrp_id.to_s,
          jeevika_jankar_name: target.vrp&.name.presence || target.vrp&.user_name.presence || "Jeevika Jankar ##{target.vrp_id}",
          contact_number: target.vrp&.mobile_no.to_s.gsub(/\D/, "").last(10),
          month: target.month_name.to_s.strip,
          ics: target.ics_name.presence || target.ics_id,
          village: target.village_name.presence || target.village_id,
          main_activity_type: "Training",
          main_activity: target.main_activity_name.to_s.strip,
          sub_activity: target.activity_name.to_s.strip,
          completed_farmer_ids: completed_training_farmer_ids_for(target, farmer_ids),
          farmers: training_farmers_for_ids(farmer_ids)
        }
      end
      .reject { |mapping| mapping[:ics].blank? && mapping[:village].blank? }
      .uniq
  end

  def seed_distribution_target_mappings
    return [] unless model_ready?(:TargetMapping)

    activity_settings = jeevika_jankar_main_activity_settings
    sub_activity_settings = jeevika_jankar_sub_activity_settings(activity_settings)

    training_target_scope
      .order(:ics_name, :ics_id, :village_name, :village_id, :id)
      .filter_map do |target|
        activity_setting = jeevika_jankar_activity_setting_for(target, activity_settings, sub_activity_settings)
        next unless activity_setting.present? && !training_main_activity_type?(activity_setting[:main_activity_type])

        farmer_ids = target_farmer_ids(target)
        {
          target_mapping_id: target.id.to_s,
          vrp_id: target.vrp_id.to_s,
          jeevika_jankar_name: target.vrp&.name.presence || target.vrp&.user_name.presence || "Jeevika Jankar ##{target.vrp_id}",
          contact_number: target.vrp&.mobile_no.to_s.gsub(/\D/, "").last(10),
          department: registered_vrp_fcoc(target.vrp),
          month: target.month_name.to_s.strip,
          ics: target.ics_name.presence || target.ics_id,
          village: target.village_name.presence || target.village_id,
          main_activity_type: "Other",
          training_topic: target.main_activity_name.to_s.strip,
          training_subject: target.activity_name.to_s.strip,
          target: target.target_quantity.to_s,
          completed_farmer_ids: other_target_completed_farmer_ids_for(target.id),
          farmers: training_farmers_for_ids(farmer_ids)
        }
      end
      .reject { |mapping| mapping[:ics].blank? && mapping[:village].blank? }
      .uniq
  end

  def training_main_activity_type?(value)
    normalize_dashboard_text(value.presence || "Training") == normalize_dashboard_text("Training")
  end

  def other_target_completed_farmer_ids_for(target_mapping_id)
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: record_source_slug)
      .order(created_at: :asc)
      .reject { |record| record.id.to_s == params[:id].to_s }
      .select { |record| approved_other_target_record?(record) || normalize_dashboard_text(record.data["status"]).include?("pending") || record.data["status"].blank? }
      .select { |record| record.data["target_mapping_id"].to_s == target_mapping_id.to_s }
      .flat_map { |record| Array(record.data["selected_farmer_ids"]).map(&:to_s) }
      .reject(&:blank?)
      .uniq
  end

  def training_target_month_options
    target_months = if model_ready?(:TargetMapping)
      training_target_scope
        .where.not(month_name: [nil, ""])
        .distinct
        .pluck(:month_name)
    else
      []
    end

    master_months = active_month_master_rows.filter_map { |record| record.data["month_name"].presence }

    (master_months + target_months)
      .map(&:to_s)
      .map(&:strip)
      .reject(&:blank?)
      .uniq
      .sort_by { |month| [dashboard_month_index(month), month] }
  end

  def seed_distribution_target_month_options
    target_months = seed_distribution_target_mappings.filter_map { |mapping| mapping[:month].presence }
    master_months = active_month_master_rows.filter_map { |record| record.data["month_name"].presence }

    (master_months + target_months)
      .map(&:to_s)
      .map(&:strip)
      .reject(&:blank?)
      .uniq
      .sort_by { |month| [dashboard_month_index(month), month] }
  end

  def training_target_scope
    scope = TargetMapping.all
    scope = scope.where(vrp_id: current_vrp_record.id) if vrp_login_user? && current_vrp_record.present?
    scope = scope.where(vrp_id: module_cluster_visible_vrp_ids) if module_cluster_incharge_login?
    scope
  end

  def completed_training_farmer_ids_for(target, farmer_ids)
    farmer_ids = Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq
    return [] if farmer_ids.blank?

    key = training_activity_key(target.month_name, target.main_activity_name, target.activity_name)
    Array(training_completion_index[key]) & farmer_ids
  end

  def completed_training_farmer_ids_for_target_deadline(target, farmer_ids)
    farmer_ids = Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq
    return [] if farmer_ids.blank?
    return completed_training_farmer_ids_for(target, farmer_ids) if target.completion_date.blank?
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "training-form")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .select { |record| training_record_matches_dashboard_target?(record, target, farmer_ids) }
      .select { |record| training_record_within_completion_date?(record, target.completion_date) }
      .flat_map { |record| training_record_selected_farmer_ids(record) & farmer_ids }
      .uniq
  end

  def training_record_within_completion_date?(record, completion_date)
    deadline = parse_module_date(completion_date)
    return true if deadline.blank?

    record_date = parse_module_date(training_summary(record)[:training_date]) ||
      (record.created_at.to_date if record.respond_to?(:created_at) && record.created_at.present?)
    return false if record_date.blank?

    record_date <= deadline
  end

  def training_completion_index
    return @training_completion_index if defined?(@training_completion_index)

    @training_completion_index = Hash.new { |hash, key| hash[key] = [] }
    return @training_completion_index unless model_ready?(:ModuleRecord)

    records = ModuleRecord
      .where(module_slug: "training-form")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }

    records.each do |record|
      next if @record&.id.present? && record.id == @record.id

      summary = training_summary(record)
      key = training_activity_key(summary[:month], summary[:training_topic], summary[:training_subject])
      next if key.all?(&:blank?)

      @training_completion_index[key] |= training_record_selected_farmer_ids(record)
    end

    @training_completion_index
  end

  def training_activity_key(month, main_activity, sub_activity = nil)
    [
      normalize_dashboard_text(month),
      normalize_dashboard_text(main_activity),
      normalize_dashboard_text(sub_activity)
    ]
  end

  def training_farmers_for_ids(farmer_ids)
    return [] unless model_ready?(:Afl)

    farmer_ids = Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq
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
    when "Jeevika Jankar Type"
      return (module_field_options("Jeevika Jankar Type") + [selected_value]).compact_blank.uniq
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

    [value]
  end

  def joined_type_labels(role, user_management_role, person_type)
    base = [role, user_management_role, person_type].compact_blank.join("-")
    return [] if base.blank?
    [base]
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
        gram_panchayat: gram_panchayat_name_from_record(record),
        village: first_present_data(record, "village_name", "village", "name"))
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
    first_non_code_data(record, "gram_panchayat_name", "gram_panchayat", "gram_panchayat_id", "gp_name", "gram_name", "name", "gp_code", "gram_code")
  end

  def first_non_code_data(record, *keys)
    values = keys.filter_map { |key| record.data[key].to_s.strip.presence }
    values.find { |value| !code_like_location_value?(value) } || values.first
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
      "Main Activity Type" => ["Training", "Other"],
      "Achievement Fill" => ["Auto Fill", "Self"],
      "Office Level" => ["State", "District", "Block", "Gram Panchayat", "Village"],
      "Parent Office Type" => ["Parent Office", "Sub Parent Office"],
      "Module Name" => ["Jeevika Jankar Registration", "Jeevika Jankar Bill"],
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
      "Jeevika Jankar Type" => { module: "add-vrp-type", field: "jeevika_jankar_type_name" },
      "Jeevika Jankar Type Name" => { module: "add-vrp-type", field: "jeevika_jankar_type_name" },
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

  def approval_level_display_label(value)
    text = value.to_s.strip
    return text if text.blank?

    sequence = approval_level_sequence_from_text(text)
    sequence ? approval_level_label_for_sequence(sequence) : text
  end

  def approval_level_label_for_sequence(sequence)
    ordinal = {
      1 => "First",
      2 => "Second",
      3 => "Third",
      4 => "Fourth",
      5 => "Fifth",
      6 => "Sixth",
      7 => "Seventh",
      8 => "Eighth",
      9 => "Ninth",
      10 => "Tenth"
    }[sequence.to_i]

    ordinal ? "#{ordinal} Approval" : "Approval #{sequence.to_i}"
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
    field_keys << "vrp_type_name" if module_slug == "add-vrp-type" && field_key == "jeevika_jankar_type_name"
    field_keys << "jeevika_jankar_type_name" if module_slug == "add-vrp-type" && field_key == "vrp_type_name"

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

    type_name = (record.data["position_type_name"].presence || record.data["jeevika_jankar_type_name"].presence || record.data["vrp_type_name"]).to_s.strip
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
