module ApplicationHelper
  SIDEBAR_SECTIONS = [
    {
      title: "LG Directory",
      icon: "▦",
      links: [
        ["All List", :module, "lg-directory-list"],
        ["State Entry", :module, "state-master"],
        ["District Entry", :module, "district-master"],
        ["Block Entry", :module, "block-master"],
        ["GP Entry", :module, "gram-panchayat-master"],
        ["Village Entry", :module, "village-master"],
        ["Month Entry", :module, "month-master"]
      ]
    },
    {
      title: "Stakeholder",
      icon: "▩",
      links: [
        ["Stakeholder Name", :module, "stakeholder-master"],
        ["Office Category Add", :module, "office-category-add"],
        ["Stakeholder Person Type", :module, "stakeholder-role"],
        ["Role", :module, "role-name"]
      ]
    },
    {
      title: "Activity Setup",
      icon: "▤",
      links: [
        ["Main Activity", :module, "add-activity-group"],
        ["Main Activity List", :module, "activity-group-list"],
        ["Sub Activity", :module, "add-vrp-activity"],
        ["Sub Activity List", :module, "vrp-activity-list"]
      ]
    },
    {
      title: "User Register",
      icon: "▩",
      links: [
        ["All User", :route, :users_path],
        ["Registration", :route, :new_user_path]
      ]
    },
    {
      title: "User Mapping",
      icon: "▧",
      links: [
        ["User Hierarchy Mapping", :module, "user-hierarchy-mapping"]
      ]
    },
    {
      title: "Resource Person Type",
      icon: "▧",
      links: [
        # ["Resource Person Type", :module, "role-management"],
        # ["User Management Person Type", :module, "user-management-role"],
        # ["Person Type", :module, "person-type"],
        ["Access Control", :module, "access-control"],
        ["Access Control List", :module, "access-control-list"]
      ]
    },
    {
      title: "VRP Registration",
      icon: "▥",
      links: [
        ["VRP Type", :module, "add-vrp-type"],
        ["VRP Registration", :route, :new_vrp_path],
        ["VRP List", :route, :vrps_path],
        ["VRP Approval Queue", :route, :approvals_vrps_path],
        ["VRP Approval Form", :module, "approval-master"],
        ["VRP Approval List", :module, "approval-list"]
      ]
    },
    # {
    #   title: "Bill Management",
    #   icon: "▧",
    #   links: [
    #     ["Bill Entry", :module, "vrp-bill-add"],
    #     ["Bill List", :module, "vrp-bill-list"]
    #   ]
    # },
    # {
    #   title: "Weekly Target",
    #   icon: "▨",
    #   links: [
    #     ["Target Entry", :module, "weekly-target-add"],
    #     ["Target List", :module, "weekly-target-list"],
    #     ["Progress Report", :module, "weekly-progress-report"]
    #   ]
    # },
    {
      title: "AFL",
      icon: "▤",
      links: [
        ["AFL Upload", :route, :afls_path],
        ["VRP ICS Mapping", :route, :vrp_ics_mappings_path]
      ]
    },
    {
      title: "Training",
      icon: "▥",
      links: [
        ["Training Form", :module, "training-form"],
        ["Training List", :module, "training-form-list"]
      ]
    },
    {
      title: "VRP Targets",
      icon: "▨",
      links: [
        ["VRP Targets", :route, :target_mappings_path]
      ]
    }
  ].freeze

  def sidebar_sections
    return vrp_sidebar_sections if vrp_login_user?

    allowed_keys = allowed_sidebar_keys
    return SIDEBAR_SECTIONS if allowed_keys.nil?

    visible_sections = SIDEBAR_SECTIONS.filter_map do |section|
      allowed_links = section[:links].select { |link| allowed_keys.include?(sidebar_access_key(link)) }
      section.merge(links: allowed_links) if allowed_links.any?
    end

    visible_sections
  end

  def sidebar_link_path(link)
    _label, type, target = link
    type == :module ? module_path(target) : public_send(target)
  end

  def sidebar_link_active?(link)
    _label, type, target = link

    if type == :module
      request.path.include?(target)
    else
      request.path == public_send(target)
    end
  end

  def sidebar_section_active?(section)
    section[:links].any? { |link| sidebar_link_active?(link) }
  end

  def sidebar_access_key(link)
    label, _type, _target = link
    label.parameterize
  end

  def resource_person_label(label)
    {
      "Stakeholder" => "Stakeholder Category",
      "Role" => "Role",
      "Role Name" => "Role Name",
      "Stakeholder Role" => "Stakeholder Person Type",
      "User Management Role" => "User Management Person Type",
      "Person Type" => "Person Type",
      "ICS / Block" => "ICS Name",
      "Gram Name" => "Village Name",
      "Activity Group" => "Main Activity",
      "Activity Group Name" => "Main Activity Name",
      "Activity Name" => "Sub Activity Name",
      "VRP Activity" => "Sub Activity"
    }.fetch(label.to_s, label)
  end

  def allowed_sidebar_keys
    return nil unless current_app_user.present?
    return nil if admin_access_user?
    return [] unless defined?(ModuleRecord) && ModuleRecord.table_exists?

    access_records = ModuleRecord
      .where(module_slug: "access-control")
      .order(created_at: :desc)
      .select { |record| record.data["status"].blank? || record.data["status"].to_s.casecmp("Active").zero? }
      .select do |record|
        record_stakeholder = record.data["stakeholder_name"].presence || record.data["stakeholder"]
        stakeholder_match = access_value_matches?(record_stakeholder, current_app_user["stakeholder"])
        record_stakeholder_role = record.data["stakeholder_role"].presence || record.data["stakeholder_person_type"]
        stakeholder_role_match = access_value_matches?(record_stakeholder_role, current_app_user["stakeholder_role"])
        record_role = record.data["role"].presence || record.data["role_name"]
        role_match = access_value_matches?(record_role, current_app_user["role"])
        record_role_name = record.data["role"].present? ? record.data["role_name"] : nil
        role_name_match = access_value_matches?(record_role_name, current_app_user["role_name"])
        record_user_management_role = record.data["user_management_role"].presence || record.data["user_management_person_type"]
        user_management_role_match = access_value_matches?(record_user_management_role, current_app_user["user_management_role"])
        record_person_type = record.data["person_type"]
        person_type_match = access_value_matches?(record_person_type, current_app_user["person_type"])
        record_vrp_type = record.data["vrp_type"].presence || record.data["select_vrp_type"]
        vrp_type_match = access_value_matches_any?(record_vrp_type, current_app_user["vrp_types"])
        can_view = record.data["can_view"].blank? || record.data["can_view"].to_s.casecmp("Yes").zero?
        stakeholder_match && stakeholder_role_match && role_match && role_name_match && user_management_role_match && person_type_match && vrp_type_match && can_view
      end

    access_records.flat_map do |record|
      access_values(record.data["sub_module_names"].presence || record.data["sub_module_name"])
        .flat_map { |name| sidebar_access_name_keys(name) }
    end.uniq
  end

  def sidebar_access_name_keys(name)
    keys = [name.presence&.parameterize].compact
    keys << "vrp-approval-queue" if name.to_s.strip == "VRP Approval"
    keys << "vrp-approval" if name.to_s.strip == "VRP Approval Queue"
    keys.uniq
  end

  def access_values(value)
    Array(value)
      .flat_map { |item| item.to_s.split(",") }
      .map(&:strip)
      .reject(&:blank?)
  end

  def access_value_matches?(record_value, user_value)
    record_value.blank? || (user_value.present? && record_value.to_s.strip.casecmp(user_value.to_s.strip).zero?)
  end

  def access_value_matches_any?(record_value, user_values)
    return true if record_value.blank?

    Array(user_values).any? { |value| value.to_s.strip.casecmp(record_value.to_s.strip).zero? }
  end

  def admin_access_user?
    current_app_user["user_type"].to_s.strip.casecmp("admin").zero?
  end

  def vrp_login_user?
    current_app_user&.dig("record_type").to_s == "Vrp"
  end

  def current_vrp_identity_url
    return unless vrp_login_user?

    vrp_id = current_app_user&.dig("id").presence
    return if vrp_id.blank?

    "http://krai.ploughmanagro.com/VRP_ID:#{vrp_id}"
  end

  def vrp_sidebar_sections
    [
      {
        title: "Training",
        icon: "▥",
        links: [
          ["Training Form", :module, "training-form"],
          ["Training List", :module, "training-form-list"]
        ]
      },
      {
        title: "VRP Targets",
        icon: "▨",
        links: [
          ["VRP Targets", :route, :target_mappings_path]
        ]
      }
    ]
  end

  def current_stakeholder
    matching_stakeholder_record("stakeholder-master") || active_stakeholder_records("stakeholder-master").first
  end

  def current_stakeholder_profile
    matching_stakeholder_record("stakeholder-profile") || active_stakeholder_records("stakeholder-profile").first
  end

  def app_display_name
    current_stakeholder&.data&.[]("stakeholder_name_in_english").presence ||
      current_stakeholder&.data&.[]("stakeholder_name").presence ||
      ENV.fetch("APP_NAME", "VRP")
  end

  def app_logo_path
    matching_stakeholder_record("stakeholder-master")&.data&.[]("logo_upload").presence ||
      matching_stakeholder_record("stakeholder-profile")&.data&.[]("logo_upload").presence ||
      current_stakeholder&.data&.[]("logo_upload").presence ||
      current_stakeholder_profile&.data&.[]("logo_upload").presence ||
      "/icon.svg"
  end

  def active_stakeholder_records(module_slug)
    return [] unless defined?(ModuleRecord) && ModuleRecord.table_exists?

    ModuleRecord
      .where(module_slug: module_slug)
      .order(updated_at: :desc)
      .select { |record| record.data["status"].blank? || record.data["status"] == "Active" }
  end

  def matching_stakeholder_record(module_slug)
    names = current_user_stakeholder_names
    return if names.blank?

    active_stakeholder_records(module_slug).detect do |record|
      names.any? { |stakeholder_name| stakeholder_record_matches?(record, stakeholder_name) }
    end
  end

  def current_user_stakeholder_names
    names = [current_app_user&.dig("stakeholder")]
    username = current_app_user&.dig("username").to_s

    if defined?(User) && User.table_exists?
      user = User.find_by(user_name: username) || User.find_by(id: current_app_user&.dig("id"))
      names << user&.stakeholder
    end

    if defined?(ModuleRecord) && ModuleRecord.table_exists? && username.present?
      legacy_user = ModuleRecord
        .where(module_slug: "new-user")
        .order(updated_at: :desc)
        .detect { |record| record.data["user_name"].to_s == username }
      names << legacy_user&.data&.[]("stakeholder")
    end

    names.compact_blank.map { |name| name.to_s.strip }.uniq
  end

  def stakeholder_record_matches?(record, stakeholder_name)
    normalized_stakeholder = normalize_stakeholder_name(stakeholder_name)
    return false if normalized_stakeholder.blank?

    values = [
      record.data["stakeholder_name_in_english"],
      record.data["stakeholder_name_in_hindi"],
      record.data["stakeholder_name"],
      record.data["profile_name"]
    ]

    values.compact.any? do |value|
      normalized_value = normalize_stakeholder_name(value)
      normalized_value == normalized_stakeholder ||
        normalized_value.split.include?(normalized_stakeholder) ||
        normalized_stakeholder.split.include?(normalized_value)
    end
  end

  def normalize_stakeholder_name(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
  end
end
