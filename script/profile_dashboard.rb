# Read-only controller profiling; run with bin/rails runner script/profile_dashboard.rb.
# Optional: DASHBOARD_FILTERS='{"month":"July","main_activity":"Farmers\u0027 Training"}'
# Uses admin visibility. Does not log farmer details or SQL literals.
require "digest"

controller = ModulesController.new
controller.set_request!(ActionDispatch::TestRequest.create)
controller.set_response!(ActionDispatch::TestResponse.new)
controller.params = ActionController::Parameters.new(JSON.parse(ENV.fetch("DASHBOARD_FILTERS", "{}")))
controller.define_singleton_method(:current_app_user) do
  { "user_type" => "admin", "role" => "Admin", "record_type" => "User", "id" => "dashboard-profile", "username" => "dashboard-profile" }
end
queries = []
subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  next if event.payload[:name] == "SCHEMA"

  normalized = event.payload[:sql].to_s.gsub(/'(?:[^']|'')*'/, "?").gsub(/\b\d+\b/, "?").squish
  queries << { ms: event.duration.round(2), cached: !!event.payload[:cached], fingerprint: Digest::SHA256.hexdigest(normalized)[0, 16] }
end
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
begin
  controller.dashboard
ensure
  ActiveSupport::Notifications.unsubscribe(subscriber)
end
puts JSON.pretty_generate(
  controller_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2),
  query_count: queries.size,
  uncached_queries: queries.count { |query| !query[:cached] },
  sql_ms: queries.sum { |query| query[:ms] }.round(2),
  slowest: queries.sort_by { |query| -query[:ms] }.first(10)
)
