class VrpsController < ApplicationController
  helper_method :blank_display, :module_record_label, :module_record_labels, :vrp_type_labels,
                :approval_step_closed?, :closing_approval_history

  before_action :set_form_dependencies, only: [:new, :create]
  before_action :set_edit_dependencies, only: [:edit, :update]

  def index
    @data = visible_vrps.map do |vrp|
      {
        id: vrp.id,
        user_name: vrp.user_name,
        status: vrp.status,
        name: vrp.name,
        father_husband_name: vrp.father_husband_name,
        gender: vrp.gender,
        date_of_birth: vrp.date_of_birth&.strftime("%d-%m-%Y"),
        date_of_joining: vrp.date_of_joining&.strftime("%d-%m-%Y"),
        aadhar_no: vrp.aadhar_no.to_s.gsub(/\d(?=\d{4})/, "x"),
        account_no: vrp.account_no,
        ifsc_code: vrp.ifsc_code,
        bank_name: vrp.bank_name.presence || vrp.vrp_bank_master&.name,
        address: vrp.address,
        mobile_no: vrp.mobile_no,
        email: vrp.email,
        registered_by: registered_by_name(vrp),
        status_label: vrp_status_label(vrp)
      }
    end
  end

  def new
    @vrp = Vrp.new
    @vrp.build_vrp_profile
  end

  def create
    @vrp = Vrp.new(vrp_params)
    @vrp.created_by_id = current_app_user_id if @vrp.respond_to?(:created_by_id=)
    @vrp.status = 10 if @vrp.respond_to?(:status=)

    unless vrp_password_confirmed?(@vrp)
      @vrp.build_vrp_profile unless @vrp.vrp_profile
      @vrp.errors.add(:password, "and Confirm Password must match")
      render :new, status: :unprocessable_entity
      return
    end

    if @vrp.save
      redirect_to vrps_path, notice: "VRP registration successfully."
    else
      @vrp.build_vrp_profile unless @vrp.vrp_profile
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    unless vrp_password_confirmed?(@vrp)
      @vrp.errors.add(:password, "and Confirm Password must match")
      render :edit, status: :unprocessable_entity
      return
    end

    if @vrp.update(vrp_params)
      redirect_to vrps_path, notice: "VRP updated successfully."
    else
      @vrp.build_vrp_profile unless @vrp.vrp_profile
      render :edit, status: :unprocessable_entity
    end
  end

  def show
    @vrp = (visible_vrps.to_a + approval_queue).uniq.find { |vrp| vrp.id == params[:id].to_i }
    if @vrp
      @can_approve = current_user_can_approve?(@vrp)
      @approval_history = approval_history_for(@vrp)
      @approval_steps = approval_steps_for(@vrp)
      @current_approval_step = current_approval_step(@vrp)
      @status_label = vrp_status_label(@vrp)
      return
    end

    redirect_to vrps_path, alert: "VRP record not found."
  end

  def destroy
    @vrp = find_visible_vrp(params[:id])

    if @vrp
      @vrp.update_columns(is_deleted: true, updated_at: Time.current)
      redirect_to vrps_path, notice: "VRP deleted successfully."
    else
      redirect_to vrps_path, alert: "VRP record not found."
    end
  end

  def set_active
    @vrp = find_visible_vrp(params[:id])

    unless @vrp
      redirect_to vrps_path, alert: "VRP record not found."
      return
    end

    active = ActiveModel::Type::Boolean.new.cast(params[:active])
    @vrp.update_columns(is_active: active, updated_at: Time.current)
    redirect_to vrps_path, notice: "VRP marked #{active ? "active" : "inactive"}."
  end

  def approvals
    @approval_rows = approval_queue.map do |vrp|
      step = current_approval_step(vrp)
      {
        vrp: vrp,
        approval_level: step&.data&.[]("approval_level").presence || "Approval #{current_approval_sequence(vrp)}",
        approver: step&.data&.[]("approver_approved_by").presence || "-",
        status_label: vrp_status_label(vrp),
        can_act: current_user_can_approve?(vrp)
      }
    end
  end

  def send_for_approval
    vrp = own_vrps.find_by(id: params[:id])

    unless vrp
      redirect_to vrps_path, alert: "VRP record not found."
      return
    end

    steps = approval_steps_for(vrp)
    first_step = steps.first

    unless first_step
      redirect_to vrps_path, alert: "Approval channel is not configured for your role."
      return
    end

    if approval_sent?(vrp) || [31, 32, 55].include?(vrp.status.to_i)
      redirect_to vrps_path, alert: "This VRP is already in approval process."
      return
    end

    update_vrp_status!(vrp, 25)
    log_approval_history(vrp, first_step, "Sent for Approval", "Pending at #{approval_approver_name(first_step)}")

    redirect_to vrps_path, notice: "VRP sent for approval. Pending at #{approval_approver_name(first_step)}."
  end

  def approve
    vrp = approvable_vrps.find { |record| record.id == params[:id].to_i }

    unless vrp
      redirect_to approvals_vrps_path, alert: "This VRP is not pending for your approval."
      return
    end

    step = current_approval_step(vrp)
    next_sequence = next_approval_sequence(vrp)
    next_status = next_sequence.present? ? 29 + next_sequence : 55

    update_vrp_status!(vrp, next_status)
    log_approval_history(vrp, step, "Approved", params[:remarks])

    message = if next_sequence.present?
      next_step = current_approval_step(vrp)
      "Approved and moved to #{approval_approver_name(next_step)}."
    else
      "VRP final approved."
    end

    redirect_to vrp_path(vrp), notice: message
  end

  def reject
    vrp = approvable_vrps.find { |record| record.id == params[:id].to_i }

    unless vrp
      redirect_to approvals_vrps_path, alert: "This VRP is not pending for your approval."
      return
    end

    step = current_approval_step(vrp)
    update_vrp_status!(vrp, 99)
    log_approval_history(vrp, step, "Rejected", params[:remarks])
    redirect_to vrp_path(vrp), notice: "VRP rejected."
  end

  private

  def set_form_dependencies
    set_master_options
  end

  def set_edit_dependencies
    set_form_dependencies
    @vrp = find_visible_vrp(params[:id])
    redirect_to vrps_path, alert: "VRP record not found." unless @vrp
  end

  def vrp_params
    params.require(:vrp).permit(
      :name,
      :father_husband_name,
      :gender,
      :date_of_birth,
      :date_of_joining,
      :aadhar_no,
      :account_no,
      :bank_name,
      :branch,
      :ifsc_code,
      :vrp_bank_master_id,
      :address,
      :mobile_no,
      :emergency_no,
      :email,
      :stakeholder,
      :stakeholder_role,
      :role,
      :user_management_role,
      :user_name,
      :password,
      :experience_in_years,
      :user_id,
      :is_deleted,
      :is_active,
      :photo,
      :aadhar_upload,
      :bank_passbook_upload,
      project_master_ids: [],
      ics_master_ids: [],
      vrp_type_ids: [],
      village_ids: [],
      gram_panchayat_ids: [],
      vrp_profile_attributes: [
        :id,
        :state_id,
        :district_id,
        :block_id,
        :gram_panchayat_id,
        :village_id,
        :vrp_id,
        :_destroy
      ]
    )
  end

  def vrp_password_confirmed?(vrp)
    confirmed_password = params.dig(:vrp, :confirmed_password).to_s
    return true if vrp.password.to_s.blank? && confirmed_password.blank?

    vrp.password.to_s == confirmed_password
  end

  def controller_current_user
    current_user if respond_to?(:current_user, true)
  end

  def current_app_user_id
    current_app_user&.dig("id") || controller_current_user&.id
  end

  def current_app_user_ids
    ([current_app_user_id] + legacy_current_app_user_ids).compact.uniq
  end

  def legacy_current_app_user_ids
    return [] unless model_ready?(:ModuleRecord)

    username = current_app_user&.dig("username").to_s
    emails = current_app_user_emails
    return [] if username.blank? && emails.blank?

    ModuleRecord.where(module_slug: "new-user").select do |record|
      record.data["user_name"].to_s == username ||
        emails.include?(record.data["email"].to_s.strip.downcase)
    end.map(&:id)
  end

  def admin_user?
    current_app_user&.dig("user_type").to_s.casecmp("admin").zero?
  end

  def own_vrps
    return Vrp.all if current_app_user.blank? || admin_user?

    ids = current_app_user_ids
    emails = current_app_user_emails
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

  def current_app_user_emails
    emails = [current_app_user&.dig("email")]

    if model_ready?(:User)
      user = User.find_by(user_name: current_app_user&.dig("username")) || User.find_by(id: current_app_user_id)
      emails << user&.email
    end

    emails.compact_blank.map { |email| email.to_s.strip.downcase }.uniq
  end

  def registered_by_name(vrp)
    creator = registered_by_user(vrp)
    return creator.full_name.presence || creator.user_name if creator.respond_to?(:full_name)

    if creator
      full_name = [creator.data["first_name"], creator.data["last_name"]].compact_blank.join(" ")
      return full_name.presence || creator.data["user_name"].presence
    end

    "Unknown"
  end

  def registered_by_user(vrp)
    if vrp.created_by_id.present?
      user = User.find_by(id: vrp.created_by_id) if model_ready?(:User)
      return user if user

      record = ModuleRecord.find_by(id: vrp.created_by_id) if model_ready?(:ModuleRecord)
      return record if record
    end

    if model_ready?(:User)
      user = User.find_by("LOWER(email) = ?", vrp.email.to_s.strip.downcase)
      return user if user
    end

    return unless model_ready?(:ModuleRecord)

    ModuleRecord.where(module_slug: "new-user").order(created_at: :desc).detect do |record|
      record.data["email"].to_s.strip.casecmp(vrp.email.to_s.strip).zero?
    end
  end

  def visible_vrps
    return Vrp.all if current_app_user.blank? || admin_user?

    (own_vrps.to_a + approval_related_vrps).uniq
  end

  def find_visible_vrp(id)
    visible_vrps.to_a.find { |vrp| vrp.id == id.to_i }
  end

  def approval_queue
    scope = Vrp.all.reject do |vrp|
      [55, 99].include?(vrp.status.to_i) ||
        approval_complete?(vrp) ||
        approval_rejected?(vrp) ||
        vrp.status.to_i < 25 ||
        (vrp.status.to_i == 25 && !approval_sent?(vrp))
    end
    return scope if admin_user?

    scope.select { |vrp| current_user_can_approve?(vrp) }
  end

  def approvable_vrps
    Vrp.all.reject do |vrp|
      [55, 99].include?(vrp.status.to_i) ||
        approval_complete?(vrp) ||
        approval_rejected?(vrp) ||
        vrp.status.to_i < 25 ||
        (vrp.status.to_i == 25 && !approval_sent?(vrp))
    end.select { |vrp| current_user_can_approve?(vrp) }
  end

  def approval_related_vrps
    Vrp.all.select do |vrp|
      approval_sent?(vrp) && current_user_in_approval_channel?(vrp)
    end
  end

  def current_user_can_approve?(vrp)
    step = current_approval_step(vrp)
    return false unless step
    return false if approval_step_closed?(vrp, step)

    approver_matches_current_user?(step.data["approver_approved_by"].to_s) ||
      approver_matches_current_user?(approval_approver_name(step))
  end

  def current_user_in_approval_channel?(vrp)
    approval_steps_for(vrp).any? do |step|
      approver_matches_current_user?(step.data["approver_approved_by"].to_s)
    end
  end

  def current_approval_step(vrp)
    sequence = current_approval_sequence(vrp)
    approval_steps_for(vrp).find { |record| approval_sequence(record) == sequence }
  end

  def current_approval_sequence(vrp)
    return nil if [55, 99].include?(vrp.status.to_i) || approval_rejected?(vrp)
    return nil unless approval_sent?(vrp)

    approval_steps_for(vrp)
      .find { |step| !approval_step_closed?(vrp, step) }
      &.then { |step| approval_sequence(step) }
  end

  def next_approval_sequence(vrp)
    sequence = current_approval_sequence(vrp).to_i
    approved_sequences = approved_approval_sequences(vrp)

    approval_steps_for(vrp)
      .select { |record| approval_sequence(record) > sequence }
      .find { |step| !approved_sequences.include?(approval_sequence(step)) && !approval_step_closed?(vrp, step) }
      &.then { |step| approval_sequence(step) }
  end

  def approval_steps_for(vrp)
    return [] unless model_ready?(:ModuleRecord)

    creator_identities = vrp_creator_identities(vrp)
    return [] if creator_identities.blank?

    matching_records = ModuleRecord
      .where(module_slug: "approval-master")
      .order(created_at: :asc)
      .select do |record|
        record_role = record.data["role_name"].to_s
        record_stakeholder = record.data["stakeholder_name"].to_s
        record_stakeholder_role = record.data["stakeholder_role"].to_s
        record_user_management_role = record.data["user_management_role"].to_s
        record_office = record.data["office"].to_s

        active_module_record?(record) &&
          ["Farmer Registration", "VRP Registration"].include?(record.data["module_name"].to_s) &&
          creator_identities.any? do |identity|
            module_value_matches?(record_role, identity[:role]) &&
              module_value_matches?(record_stakeholder, identity[:stakeholder]) &&
              module_value_matches?(record_stakeholder_role, identity[:stakeholder_role]) &&
              module_value_matches?(record_user_management_role, identity[:user_management_role]) &&
              (record_office.blank? || module_value_matches?(record_office, identity[:office]))
          end
      end

    matching_records
      .group_by { |record| approval_sequence(record) }
      .values
      .map { |records| records.max_by(&:id) }
      .sort_by { |record| approval_sequence(record) }
  end

  def approval_sequence(record)
    approval_sequence_from_level(record.data["approval_level"])
  end

  def approval_sequence_from_level(level)
    level = level.to_s.downcase
    return 1 if level.include?("first")
    return 2 if level.include?("second")
    return 3 if level.include?("third")

    level[/\d+/].to_i.presence || 1
  end

  def approver_labels
    name = current_app_user&.dig("name").to_s
    username = current_app_user&.dig("username").to_s
    role = current_app_user&.dig("role").to_s
    office = current_app_user&.dig("office").to_s

    labels = [
      name,
      username,
      role.present? && name.present? ? "#{name} (#{role})" : nil,
      role.present? && username.present? ? "#{username} (#{role})" : nil,
      office.present? && name.present? ? "#{name} (#{office})" : nil
    ]
    labels.concat(user_model_approver_labels)
    labels.concat(legacy_user_approver_labels)

    labels
      .compact_blank
      .uniq
  end

  def user_model_approver_labels
    return [] unless model_ready?(:User)

    user = User.find_by(user_name: current_app_user&.dig("username")) || User.find_by(id: current_app_user_id)
    return [] unless user

    full_name = user.full_name.presence
    [
      full_name,
      user.user_name,
      user.role.present? && full_name.present? ? "#{full_name} (#{user.role})" : nil,
      user.role.present? && user.user_name.present? ? "#{user.user_name} (#{user.role})" : nil,
      user.office.present? && full_name.present? ? "#{full_name} (#{user.office})" : nil
    ]
  end

  def legacy_user_approver_labels
    return [] unless model_ready?(:ModuleRecord)

    username = current_app_user&.dig("username").to_s
    return [] if username.blank?

    record = ModuleRecord
      .where(module_slug: "new-user")
      .order(created_at: :desc)
      .detect { |row| row.data["user_name"].to_s == username }
    return [] unless record

    full_name = [record.data["first_name"], record.data["last_name"]].compact_blank.join(" ").presence
    role = record.data["role"].presence
    office = record.data["office"].presence
    [
      full_name,
      record.data["user_name"].presence,
      role.present? && full_name.present? ? "#{full_name} (#{role})" : nil,
      role.present? && record.data["user_name"].present? ? "#{record.data["user_name"]} (#{role})" : nil,
      office.present? && full_name.present? ? "#{full_name} (#{office})" : nil
    ]
  end

  def approver_matches_current_user?(approver)
    normalized_approver = normalize_approver_label(approver)

    approver_labels.any? do |label|
      normalized_label = normalize_approver_label(label)
      approver.to_s == label.to_s ||
        normalized_approver == normalized_label ||
        normalized_approver.include?(normalized_label) ||
        normalized_label.include?(normalized_approver)
    end
  end

  def normalize_approver_label(label)
    label.to_s.sub(/\s*\([^)]*\)\s*\z/, "").strip.downcase
  end

  def module_value_matches?(expected, actual)
    return true if expected.blank?

    expected.to_s.strip.casecmp(actual.to_s.strip).zero?
  end

  def vrp_status_label(vrp)
    return "Rejected" if vrp.status.to_i == 99 || approval_rejected?(vrp)
    return "Final Approved" if vrp.status.to_i == 55 || approval_complete?(vrp)

    if approval_sent?(vrp)
      "Pending at #{approval_approver_name(current_approval_step(vrp))}"
    else
      "Submitted"
    end
  end

  def approval_approver_name(step)
    step&.data&.[]("approver_approved_by").presence || "Approver"
  end

  def vrp_creator_role(vrp)
    return current_app_user&.dig("role") if vrp.created_by_id.blank?

    if model_ready?(:User)
      role = User.find_by(id: vrp.created_by_id)&.role
      return role if role.present?
    end

    return current_app_user&.dig("role") unless model_ready?(:ModuleRecord)

    ModuleRecord.find_by(id: vrp.created_by_id)&.data&.[]("role").presence ||
      current_app_user&.dig("role")
  end

  def vrp_creator_stakeholder(vrp)
    return current_app_user&.dig("stakeholder") if vrp.created_by_id.blank?

    if model_ready?(:User)
      stakeholder = User.find_by(id: vrp.created_by_id)&.stakeholder
      return stakeholder if stakeholder.present?
    end

    return current_app_user&.dig("stakeholder") unless model_ready?(:ModuleRecord)

    ModuleRecord.find_by(id: vrp.created_by_id)&.data&.[]("stakeholder").presence || current_app_user&.dig("stakeholder")
  end

  def vrp_creator_identities(vrp)
    identities = []

    if vrp.created_by_id.present? && model_ready?(:User)
      user = User.find_by(id: vrp.created_by_id)
      identities << user_approval_identity(user) if user
    end

    if model_ready?(:User)
      matched_users = []
      matched_users << User.find_by(email: vrp.email) if vrp.email.present?
      matched_users << User.find_by(mobile_no: vrp.mobile_no) if vrp.mobile_no.present?
      matched_users.compact.uniq.each do |user|
        identities << user_approval_identity(user)
      end
    end

    if vrp.created_by_id.present? && model_ready?(:ModuleRecord)
      record = ModuleRecord.find_by(id: vrp.created_by_id)
      identities << record_approval_identity(record) if record
    end

    if model_ready?(:ModuleRecord)
      matched_records = ModuleRecord.where(module_slug: "new-user").select do |record|
        (vrp.email.present? && record.data["email"].to_s.casecmp(vrp.email.to_s).zero?) ||
          (vrp.mobile_no.present? && record.data["mobile_no"].to_s == vrp.mobile_no.to_s)
      end
      matched_records.each do |record|
        identities << record_approval_identity(record)
      end
    end

    identities << {
      role: current_app_user&.dig("role"),
      stakeholder: current_app_user&.dig("stakeholder"),
      stakeholder_role: current_app_user&.dig("stakeholder_role"),
      user_management_role: current_app_user&.dig("user_management_role"),
      office: current_app_user&.dig("office")
    } if vrp.created_by_id.blank?

    identities
      .select { |identity| identity[:role].present? && identity[:stakeholder].present? }
      .uniq
  end

  def user_approval_identity(user)
    {
      role: user.role,
      stakeholder: user.stakeholder,
      stakeholder_role: user.stakeholder_role,
      user_management_role: user.user_management_role,
      office: user.office
    }
  end

  def record_approval_identity(record)
    {
      role: record.data["role"],
      stakeholder: record.data["stakeholder"],
      stakeholder_role: record.data["stakeholder_role"],
      user_management_role: record.data["user_management_role"],
      office: record.data["office"]
    }
  end

  def approval_history_for(vrp)
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "vrp-approval-history")
      .order(created_at: :asc)
      .select { |record| record.data["vrp_id"].to_i == vrp.id }
  end

  def approval_sent?(vrp)
    approval_history_for(vrp).any? do |record|
      ["Sent for Approval", "Approved", "Rejected"].include?(record.data["action"].to_s)
    end
  end

  def approval_rejected?(vrp)
    approval_history_for(vrp).any? { |record| record.data["action"].to_s == "Rejected" }
  end

  def approval_complete?(vrp)
    steps = approval_steps_for(vrp)
    return false if steps.blank?

    steps.all? { |step| approval_step_closed?(vrp, step) }
  end

  def approved_approval_sequences(vrp)
    approval_history_for(vrp)
      .select { |record| record.data["action"].to_s == "Approved" }
      .map { |record| approval_sequence_from_level(record.data["approval_level"]) }
      .uniq
  end

  def approval_step_closed?(vrp, step)
    closing_approval_history(vrp, step).present?
  end

  def closing_approval_history(vrp, step)
    step_sequence = approval_sequence(step)
    step_approver = normalize_approver_label(approval_approver_name(step))

    approval_history_for(vrp).find do |record|
      ["Approved", "Rejected"].include?(record.data["action"].to_s) &&
        (
          approval_sequence_from_level(record.data["approval_level"]) == step_sequence ||
            normalize_approver_label(record.data["approver"]) == step_approver
        )
    end
  end

  def update_vrp_status!(vrp, status)
    vrp.update_columns(status: status, updated_at: Time.current)
    vrp.status = status
  end

  def log_approval_history(vrp, step, action, remarks)
    return unless model_ready?(:ModuleRecord)

    ModuleRecord.create!(
      module_slug: "vrp-approval-history",
      data: {
        "vrp_id" => vrp.id,
        "approval_level" => step&.data&.[]("approval_level").presence || "Approval",
        "approver" => approval_approver_name(step),
        "action" => action,
        "remarks" => remarks.to_s,
        "status" => vrp_status_label(vrp),
        "action_by" => current_app_user&.dig("name").presence || current_app_user&.dig("username").to_s
      }
    )
  end

  def set_master_options
    sync_existing_vrp_master_records

    @stakeholder_options = text_module_record_options("stakeholder-master", "stakeholder_name_in_english")
    @stakeholder_role_options = text_module_record_options("stakeholder-role", "stakeholder_role")
    @role_options = text_module_record_options("role-management", "role_name")
    @user_management_role_options = text_module_record_options("user-management-role", "user_management_role")
    @role_management_mappings = role_management_mappings
    @vrp_type_options = vrp_type_options
    @state_options = module_record_options("state-master", "state_name")
    @district_options = module_record_options("district-master", "district_name")
    @block_options = module_record_options("block-master", "block_name")
    @gram_panchayat_options = module_record_options("gram-panchayat-master", "gram_panchayat_name")
    @village_options = module_record_options("village-master", "village_name")
    @location_hierarchy_mappings = location_hierarchy_mappings
  end

  def vrp_type_options
    if model_ready?(:VrpType)
      options = VrpType.where(is_active: true, is_deleted: false).order(:type_name).pluck(:type_name, :id)
      return options if options.any?
    end

    module_record_options("add-vrp-type", "vrp_type_name").presence ||
      module_record_options("position-type", "position_type_name")
  end

  def ics_options
    module_record_options("ics-master", "ics_name")
  end

  def module_record_options(module_slug, field_key)
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: module_slug)
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .filter_map do |record|
        label = record.data[field_key].presence
        [label, record.id] if label
      end
      .uniq { |label, _value| label }
  end

  def text_module_record_options(module_slug, field_key)
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: module_slug)
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .filter_map { |record| record.data[field_key].presence }
      .uniq
  end

  def role_management_mappings
    return [] unless model_ready?(:ModuleRecord)

    stakeholder_role_mappings = ModuleRecord
      .where(module_slug: "stakeholder-role")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .map do |record|
        {
          stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
          stakeholder_role: first_present_data(record, "stakeholder_role").to_s.strip,
          role: "",
          user_management_role: ""
        }
      end

    role_mappings = ModuleRecord
      .where(module_slug: "role-management")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .map do |record|
        {
          stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
          stakeholder_role: first_present_data(record, "stakeholder_role").to_s.strip,
          role: first_present_data(record, "role_name", "role").to_s.strip,
          user_management_role: ""
        }
      end

    user_management_role_mappings = ModuleRecord
      .where(module_slug: "user-management-role")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .map do |record|
        {
          stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
          stakeholder_role: first_present_data(record, "stakeholder_role").to_s.strip,
          role: first_present_data(record, "role_name", "role").to_s.strip,
          user_management_role: first_present_data(record, "user_management_role").to_s.strip
        }
      end

    (stakeholder_role_mappings + role_mappings + user_management_role_mappings)
      .reject { |mapping| mapping[:stakeholder_role].blank? && mapping[:role].blank? && mapping[:user_management_role].blank? }
      .uniq
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

  def first_present_data(record, *keys)
    keys.filter_map { |key| record.data[key].presence }.first
  end

  def active_module_record?(record)
    record.data["status"].blank? || record.data["status"] == "Active"
  end

  def blank_display(value)
    value.presence || ""
  end

  def module_record_label(module_slug, id, field_key)
    return "" if id.blank? || !model_ready?(:ModuleRecord)

    record = ModuleRecord.find_by(module_slug: module_slug, id: id)
    return record.data[field_key].to_s if record&.data&.[](field_key).present?

    id.to_s.match?(/\A\d+\z/) ? "" : id.to_s
  end

  def module_record_labels(module_slug, ids, field_key)
    Array(ids)
      .filter_map { |id| module_record_label(module_slug, id, field_key).presence }
      .join(", ")
  end

  def vrp_type_labels(ids)
    ids = Array(ids).reject(&:blank?)
    return "" if ids.blank?

    if model_ready?(:VrpType)
      labels = VrpType.where(id: ids).pluck(:type_name)
      return labels.join(", ") if labels.any?
    end

    module_record_labels("add-vrp-type", ids, "vrp_type_name")
  end

  def sync_existing_vrp_master_records
    return unless model_ready?(:ModuleRecord)

    ModuleRecord.where(module_slug: ["bank-master", "position-type", "add-vrp-type"]).find_each do |record|
      case record.module_slug
      when "bank-master"
        sync_bank_master(record)
      when "position-type", "add-vrp-type"
        sync_vrp_type(record)
      end
    end
  end

  def sync_bank_master(record)
    return unless model_ready?(:VrpBankMaster)

    name = record.data["bank_name"].to_s.strip
    return if name.blank?

    bank = VrpBankMaster.find_or_initialize_by(name: name)
    bank.is_active = record.data["status"].to_s != "Inactive" if bank.respond_to?(:is_active=)
    bank.is_deleted = false if bank.respond_to?(:is_deleted=)
    bank.save(validate: false)
  end

  def sync_vrp_type(record)
    return unless model_ready?(:VrpType)

    type_name = (record.data["position_type_name"].presence || record.data["vrp_type_name"]).to_s.strip
    return if type_name.blank?

    vrp_type = VrpType.find_or_initialize_by(type_name: type_name)
    vrp_type.is_active = record.data["status"].to_s != "Inactive" if vrp_type.respond_to?(:is_active=)
    vrp_type.is_deleted = false if vrp_type.respond_to?(:is_deleted=)
    vrp_type.save(validate: false)
  end

  def model_ready?(name)
    klass = name.to_s.safe_constantize
    klass.present? && (!klass.respond_to?(:table_exists?) || klass.table_exists?)
  end
end
