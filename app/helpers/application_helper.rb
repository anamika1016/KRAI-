module ApplicationHelper
  SIDEBAR_SECTIONS = [
    {
      title: "LG Directory",
      icon: "▦",
      links: [
        ["State Entry", :module, "state-master"],
        ["District Entry", :module, "district-master"],
        ["Block Entry", :module, "block-master"],
        ["GP Entry", :module, "gram-panchayat-master"],
        ["Village Entry", :module, "village-master"]
      ]
    },
    {
      title: "Master Setup",
      icon: "▣",
      links: [
        # ["Training Material", :module, "training-material"],
        ["Month Entry", :module, "month-master"],
        ["ICS Entry", :module, "ics-master"]
      ]
    },
    {
      title: "Stakeholder",
      icon: "▩",
      links: [
        ["Stakeholder Name", :module, "stakeholder-master"]
      ]
    },
    {
      title: "Office Management",
      icon: "▥",
      links: [
        ["Office Category Add", :module, "office-category-add"]
      ]
    },
    {
      title: "Activity Setup",
      icon: "▤",
      links: [
        ["Add VRP Type", :module, "add-vrp-type"],
        ["Add Activity Group", :module, "add-activity-group"],
        ["Activity Group List", :module, "activity-group-list"],
        ["Add Activity", :module, "add-vrp-activity"],
        ["VRP Activity List", :module, "vrp-activity-list"],
        ["Task Completion Indicator", :module, "task-completion-indicator"],
        ["TCI List", :module, "task-completion-indicator-list"]
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
      title: "Resource Person Type Management",
      icon: "▧",
      links: [
        ["Stakeholder Person Type", :module, "stakeholder-role"],
        ["Resource Person Type", :module, "role-management"],
        ["User Management Person Type", :module, "user-management-role"],
        ["Access Control", :module, "access-control"],
        ["Access Control List", :module, "access-control-list"]
      ]
    },
    {
      title: "VRP Registration",
      icon: "▥",
      links: [
        ["VRP Registration", :route, :new_vrp_path],
        ["VRP List", :route, :vrps_path],
        ["VRP Approval", :route, :approvals_vrps_path],
        ["VRP Approval Form", :module, "approval-master"],
        ["VRP Approval List", :module, "approval-list"]
      ]
    },
    {
      title: "Bill Management",
      icon: "▧",
      links: [
        ["Bill Entry", :module, "vrp-bill-add"],
        ["Bill List", :module, "vrp-bill-list"]
      ]
    },
    {
      title: "Weekly Target",
      icon: "▨",
      links: [
        ["Target Entry", :module, "weekly-target-add"],
        ["Target List", :module, "weekly-target-list"],
        ["Progress Report", :module, "weekly-progress-report"]
      ]
    }
  ].freeze

  def sidebar_sections
    allowed_keys = allowed_sidebar_keys
    return SIDEBAR_SECTIONS if allowed_keys.nil?

    SIDEBAR_SECTIONS.filter_map do |section|
      allowed_links = section[:links].select { |link| allowed_keys.include?(sidebar_access_key(link)) }
      section.merge(links: allowed_links) if allowed_links.any?
    end
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
      "Role" => "Resource Person Type",
      "Role Name" => "Resource Person Type",
      "Stakeholder Role" => "Stakeholder Person Type",
      "User Management Role" => "User Management Person Type"
    }.fetch(label.to_s, label)
  end

  def allowed_sidebar_keys
    return nil unless current_app_user.present?
    return nil if current_app_user["user_type"].to_s.casecmp("admin").zero?
    return [] unless defined?(ModuleRecord) && ModuleRecord.table_exists?

    access_records = ModuleRecord
      .where(module_slug: "access-control")
      .order(created_at: :desc)
      .select { |record| record.data["status"].blank? || record.data["status"].to_s.casecmp("Active").zero? }
      .select do |record|
        record_stakeholder = record.data["stakeholder_name"].presence || record.data["stakeholder"]
        stakeholder_match = record_stakeholder.blank? || record_stakeholder.to_s.strip.casecmp(current_app_user["stakeholder"].to_s.strip).zero?
        record_role = record.data["role_name"].presence || record.data["role"]
        role_match = record_role.blank? || record_role.to_s.strip.casecmp(current_app_user["role"].to_s.strip).zero?
        can_view = record.data["can_view"].blank? || record.data["can_view"].to_s.casecmp("Yes").zero?
        stakeholder_match && role_match && can_view
      end

    access_records.flat_map do |record|
      submodule_keys = access_values(record.data["sub_module_names"].presence || record.data["sub_module_name"])
        .filter_map { |name| name.presence&.parameterize }

      section_keys = access_values(record.data["module_names"].presence || record.data["module_name"]).flat_map do |section_name|
        section = SIDEBAR_SECTIONS.find { |sidebar_section| sidebar_section[:title].to_s.casecmp(section_name.to_s).zero? }
        section ? section[:links].map { |link| sidebar_access_key(link) } : []
      end

      submodule_keys + section_keys
    end.uniq
  end

  def access_values(value)
    Array(value)
      .flat_map { |item| item.to_s.split(",") }
      .map(&:strip)
      .reject(&:blank?)
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
