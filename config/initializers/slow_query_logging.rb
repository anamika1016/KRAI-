# Log slow-query fingerprints without SQL literals or customer data.
require "digest"

ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, started, finished, _id, payload|
  next if payload[:cached] || payload[:name] == "SCHEMA"

  duration = (finished - started) * 1000
  next if duration < 200

  normalized_sql = payload[:sql].to_s.gsub(/'(?:[^']|'')*'/, "?").gsub(/\b\d+\b/, "?").squish
  fingerprint = Digest::SHA256.hexdigest(normalized_sql)[0, 16]
  Rails.logger.warn("[slow_sql] duration_ms=#{duration.round(1)} fingerprint=#{fingerprint} operation=#{normalized_sql.split.first}")
end
