# Read-only admin controller + ERB profile (no authentication/network/browser timing).
# PROFILE_SLUG=training-form PROFILE_PARAMS='{}' bin/rails runner script/profile_module_page.rb
# PROFILE_ACTION=dashboard or farmer_training_participation selects a report.
require "digest"
action = ENV.fetch("PROFILE_ACTION", "show")
raise "Unsupported action" unless %w[show dashboard farmer_training_participation].include?(action)
controller = ModulesController.new
controller.set_request!(ActionDispatch::TestRequest.create)
controller.set_response!(ActionDispatch::TestResponse.new)
controller.params = ActionController::Parameters.new(JSON.parse(ENV.fetch("PROFILE_PARAMS", "{}")).merge(
  "slug" => ENV.fetch("PROFILE_SLUG", "training-form"), "controller" => "modules", "action" => action
))
controller.define_singleton_method(:current_app_user) do
  { "user_type" => "admin", "role" => "Admin", "record_type" => "User", "id" => "page-profile", "username" => "page-profile" }
end
queries = []
subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  next if event.payload[:name] == "SCHEMA"
  normalized = event.payload[:sql].to_s.gsub(/'(?:[^']|'')*'/, "?").gsub(/\b\d+\b/, "?").squish
  queries << { ms: event.duration, fingerprint: Digest::SHA256.hexdigest(normalized)[0, 16] }
end
clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
begin
  ActiveRecord::Base.transaction do
    ActiveRecord::Base.connection.execute("SET TRANSACTION READ ONLY")
    started = clock.call
    controller.public_send(action)
    loaded = clock.call
    html = controller.render_to_string(template: "modules/#{action}", layout: false)
    finished = clock.call
    puts JSON.pretty_generate(action: action, slug: controller.params[:slug], controller_ms: ((loaded - started) * 1000).round(2),
      render_ms: ((finished - loaded) * 1000).round(2), html_bytes: html.bytesize,
      query_count: queries.size, sql_ms: queries.sum { |q| q[:ms] }.round(2),
      repeated_queries: queries.group_by { |q| q[:fingerprint] }.map { |key, rows| { fingerprint: key, count: rows.size, ms: rows.sum { |q| q[:ms] }.round(2) } }.sort_by { |q| -q[:ms] }.first(10))
    raise ActiveRecord::Rollback
  end
ensure
  ActiveSupport::Notifications.unsubscribe(subscriber)
end
