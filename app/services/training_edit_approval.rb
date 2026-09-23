require "base64"

# Revisions remain separate from live training data until the responsible Agronomist approves.
class TrainingEditApproval
  SLUG = "training-form-edit-request".freeze
  IMAGE_KEYS = %w[training_register_upload training_photo_upload_with_geo_tag].freeze
  class InvalidTransition < StandardError; end

  def self.identity(actor)
    "#{actor['record_type'].presence || 'User'}:#{actor['id']}"
  end

  def self.username(value)
    value.to_s.sub(/\s*\([^)]*\)\s*\z/, "").gsub(/\s+/, " ").strip.downcase
  end

  # An approver may be stored by login, display name, or mobile; treat them all as the
  # same person so the current approver is recognised regardless of which form was saved.
  def self.actor_usernames(actor)
    [actor["username"], actor["user_name"], actor["name"], actor["mobile_no"]]
      .compact_blank.map { |value| username(value) }.uniq
  end

  def self.automatic_routing(data, actor)
    office = TrainingStaffScope.office_for(data, actor)
    candidates = TrainingStaffScope.staff(office, :agronomist)
      .reject { |candidate| candidate["user_name"].blank? || identity(candidate) == identity(actor) }
      .uniq { |candidate| username(candidate["user_name"]) }
    return {} unless candidates.one?

    approver = candidates.first
    { "approvers" => [TrainingStaffScope.name(approver)],
      "approver_identities" => [identity(approver)], "approval_office" => office, "approval_role" => "agronomist" }
  end

  def self.assign_automatic_approver!(revision)
    return revision unless revision.data["status"] == "Pending" && revision.data["approval_role"] != "agronomist"

    revision.with_lock do
      data = revision.data.deep_dup
      routing = automatic_routing(data["before"] || {}, data["requester"] || {})
      routing = { "approvers" => [], "approver_identities" => [], "approval_role" => nil } if routing.empty?
      revision.update!(data: data.merge(routing).merge("step" => 0))
    end
    revision.reload
  end

  def self.submit!(record:, proposed:, actor:)
    record.with_lock do
      pending = ModuleRecord.where(module_slug: SLUG).where("data::jsonb ->> 'record_id' = ? AND data::jsonb ->> 'status' = 'Pending'", record.id.to_s).first
      if pending && pending.data["requester_identity"] != identity(actor)
        raise InvalidTransition, "Another user's edit is pending approval for this training form."
      end
      routing = automatic_routing(record.data, actor)
      raise InvalidTransition, "A single active Agronomist account must be assigned to this training's FCO office before submitting the edit." if routing.empty?
      IMAGE_KEYS.each { |key| proposed[key] = (Array(record.data[key]) + Array(proposed[key])).compact_blank.uniq }
      # Preserve creator/ownership fields; CC edits cannot reassign records.
      record.data.each { |key, value| proposed[key] = value if key.start_with?("created_by") || %w[vrp_id select_vrp jeevika_jankar_id].include?(key) }
      if pending
        pending.with_lock do
          raise InvalidTransition, "This request was already decided. Reload the training form before editing." unless pending.data["status"] == "Pending"
          raise InvalidTransition, "The original record changed. Reload before submitting." unless comparable_data(pending.data["before"]) == comparable_data(record.data)
          previous = pending.data.deep_dup
          history = Array(previous["history"]) + [{ "action" => "resubmitted", "actor" => identity(actor), "at" => Time.current.iso8601 }]
          pending.update!(data: previous.merge(routing).merge(
            "proposed" => proposed, "step" => 0, "history" => history,
            "evidence" => (Array(previous["evidence"]) + evidence(record.data, proposed)).uniq
          ))
        end
        return pending
      end
      ModuleRecord.create!(module_slug: SLUG, data: {
        "record_id" => record.id, "before" => record.data.deep_dup, "proposed" => proposed,
        "requester" => actor.slice("id", "record_type", "username", "user_name", "name", "stakeholder", *TrainingStaffScope::OFFICE_KEYS),
        "requester_identity" => identity(actor), "status" => "Pending", "step" => 0,
        "history" => [], "evidence" => evidence(record.data, proposed)
      }.merge(routing))
    end
  end

  def self.edit_data(record, actor)
    return record.data unless record.module_slug == "training-form"

    revision = ModuleRecord.where(module_slug: SLUG)
      .where("data::jsonb ->> 'record_id' = ? AND data::jsonb ->> 'status' = 'Pending'", record.id.to_s).first
    return record.data unless revision && revision.data["requester_identity"] == identity(actor)

    revision.data["proposed"].deep_dup
  end

  def self.evidence(*snapshots)
    snapshots.flat_map { |data| IMAGE_KEYS.flat_map { |key| Array(data[key]) } }.compact_blank.uniq.filter_map do |url|
      next unless url.is_a?(String) && url.start_with?("/uploads/module_records/")
      path = Rails.root.join("public", url.delete_prefix("/"))
      root = Rails.root.join("public/uploads/module_records")
      next unless root.directory? && path.file? && path.realpath.to_s.start_with?("#{root.realpath}/")
      { "url" => url, "filename" => path.basename.to_s, "base64" => Base64.strict_encode64(path.binread) }
    end
  end

  def self.pending_for(actor)
    return [] if actor.blank?

    ModuleRecord.where(module_slug: SLUG).where("data::jsonb ->> 'status' = 'Pending'").order(id: :desc).select do |revision|
      assign_automatic_approver!(revision)
      visible?(revision, actor)
    end
  end

  def self.visible?(revision, actor)
    return true if actor["user_type"].to_s.casecmp("admin").zero? || revision.data["requester_identity"] == identity(actor)

    if revision.data["approver_identities"].present?
      return Array(revision.data["approver_identities"]).include?(identity(actor))
    end
    aliases = actor_usernames(actor)
    Array(revision.data["approvers"]).any? { |label| aliases.include?(username(label)) }
  end

  def self.can_decide?(revision, actor)
    return false unless revision.data["status"] == "Pending" && Array(revision.data["approvers"]).any?
    return true if actor["user_type"].to_s.casecmp("admin").zero?

    if revision.data["approver_identities"].present?
      return revision.data["approver_identities"][revision.data["step"].to_i] == identity(actor)
    end
    approver = revision.data["approvers"][revision.data["step"].to_i]
    actor_usernames(actor).include?(username(approver))
  end

  # The "before" snapshot and the live record store the same values in different
  # shapes: blank as nil or "", a single upload as "path" or ["path"], and keys
  # that only appear once a newer form version saves them. Comparing raw hashes
  # therefore rejects approvals where nothing actually changed, so compare a
  # normalised view instead. Real content edits still differ and are still caught.
  def self.comparable_data(data)
    Hash(data).each_with_object({}) do |(key, value), memo|
      normalized = comparable_value(value)
      memo[key] = normalized unless normalized.nil?
    end
  end

  def self.comparable_value(value)
    case value
    when String
      value.strip.presence
    when Array
      cleaned = value.filter_map { |item| comparable_value(item) }
      # A single upload is stored as "path" in one snapshot and ["path"] in the
      # other, so collapse one-element arrays to make those two forms equal.
      cleaned.size == 1 ? cleaned.first : cleaned.presence
    when Hash
      comparable_data(value).presence
    else
      value
    end
  end

  def self.status_label(revision)
    status = revision.data["status"].to_s
    return "Approved" if status == "Approved"
    return "Rejected" if status == "Rejected"

    approver = Array(revision.data["approvers"])[revision.data["step"].to_i]
    approver.present? ? "Pending at #{approver}" : "Pending - Agronomist assignment unavailable"
  end

  def self.decide!(revision:, actor:, decision:, remarks:)
    assign_automatic_approver!(revision)
    raise InvalidTransition, "Invalid decision." unless %w[approve reject route].include?(decision)
    revision.with_lock do
      data = revision.data.deep_dup
      if decision == "route"
        raise InvalidTransition, "Only admin can route an unassigned pending request." unless actor["user_type"].to_s.casecmp("admin").zero? && data["status"] == "Pending" && Array(data["approvers"]).empty?
        routing = automatic_routing(data["before"] || {}, data["requester"] || {})
        raise InvalidTransition, "Assign a single active Agronomist account to the training's FCO office first." if routing.empty?
        data.merge!(routing)
      else
        raise InvalidTransition, "This request is not awaiting your approval." unless can_decide?(revision, actor)
        raise InvalidTransition, "Remarks are required." if remarks.blank?
        if decision == "reject"
          data["status"] = "Rejected"
        else
          data["step"] = data["step"].to_i + 1
          if data["step"] >= data["approvers"].size
            record = ModuleRecord.find(data["record_id"])
            record.with_lock do
              raise InvalidTransition, "The original record changed. Reject this request and submit a fresh edit." unless record.module_slug == "training-form" && comparable_data(record.data) == comparable_data(data["before"])
              record.update!(data: data["proposed"])
            end
            data["status"] = "Approved"
          end
        end
      end
      data["history"] << { "action" => decision, "actor" => identity(actor), "remarks" => remarks, "at" => Time.current.iso8601 }
      revision.update!(data: data)
    end
  end
end
