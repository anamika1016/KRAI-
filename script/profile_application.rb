# Read-only profiling of application GET endpoints (controller + render).
# Run: bin/rails runner script/profile_application.rb > tmp/application-profile.json
# PROFILE_ONLY='api/v1/jeevika_jankar_masters|vrp_agreements' narrows the scan.
# PROFILE_USER_ID selects an existing office account; default is an admin.
# No payload, SQL values, credentials, external messages, or writes are emitted.
require "digest"
require "uri"

excluded_controllers = %w[sessions api/v1/sessions api/v1/otp_logins api/v1/password_resets jj_exam uploads rails/health active_storage/blobs/redirect active_storage/disk]
excluded_actions = /export|download|template|destroy|create|update|logout|import|accept|take|submit/
selector = Regexp.new(ENV["PROFILE_ONLY"]) if ENV["PROFILE_ONLY"].present?
profile_user = if ENV["PROFILE_USER_ID"].present?
  User.find_by(id: ENV["PROFILE_USER_ID"])
else
  User.where("LOWER(user_type) = ?", "admin").first
end
raise "An existing user account is needed for profiling" unless profile_user
payload = ApplicationController.new.send(:app_user_session_payload, profile_user)
clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }

routes = Rails.application.routes.routes.filter_map do |route|
  next unless route.verb.include?("GET")
  controller = route.defaults[:controller]
  action = route.defaults[:action]
  next if controller.blank? || action.blank? || excluded_controllers.include?(controller)
  next if controller.start_with?("active_storage/", "rails/") || action.match?(excluded_actions)
  next if selector && !controller.match?(selector)
  next unless (route.required_keys.map(&:to_s) - %w[format controller action]).empty?

  [ controller, action, route.defaults.except(:controller, :action).stringify_keys ]
end.uniq
ModulesController::MODULES.each_key do |slug|
  routes << [ "modules", "show", { "slug" => slug } ] if !selector || "modules".match?(selector)
end
# Profile every advertised dashboard widget and drill-down, too.
{
  "api/v1/jeevika_jankar_dashboard" => { "widget" => :admin_dashboard_widget_catalog, "list" => :admin_dashboard_list_catalog },
  "api/v1/user_dashboard" => { "widget" => :user_dashboard_widget_catalog, "list" => :user_dashboard_list_catalog }
}.each do |path, actions|
  next if selector && !path.match?(selector)
  catalog_controller = "#{path.camelize}Controller".constantize.new
  catalog_controller.set_request!(ActionDispatch::TestRequest.create)
  catalog_controller.set_response!(ActionDispatch::TestResponse.new)
  catalog_controller.define_singleton_method(:current_api_user) { profile_user }
  catalog_controller.define_singleton_method(:current_api_user_payload) { payload }
  actions.each do |action, catalog|
    key = action == "widget" ? "widget" : "list_type"
    catalog_controller.send(catalog).each_key { |value| routes << [ path, action, { key => value } ] }
  end
end

# Record-specific pages are sampled with an existing record, without mutation.
Rails.application.routes.routes.each do |route|
  next unless route.verb.include?("GET")
  path, action = route.defaults.values_at(:controller, :action)
  next if path.blank? || action.blank? || excluded_controllers.include?(path)
  next if selector && !path.match?(selector)
  next unless %w[show edit results bill invoice photos show_record].include?(action)
  next unless (route.required_keys.map(&:to_s) - %w[format controller action]) == [ "id" ]
  model = if path == "api/v1/jeevika_jankar_payments"
    ModuleRecord.where(module_slug: "jeevika-jankar-bill-process")
  elsif path == "api/v1/vrp_agreements" || path == "api/v1/jeevika_jankars" || path == "vrp_agreements"
    Vrp
  elsif path.start_with?("api/")
    slug = { "farmer_trainings" => "training-form", "other_targets" => "other-target", "seed_distribution_targets" => "seed-distribution-target", "papl360_targets" => "papl360-target", "add_farmer_forms" => "add-farmer-form", "access_controls" => "access-control" }[path.split("/").last]
    ModuleRecord.where(module_slug: slug) if slug
  else
    path.classify.safe_constantize
  end
  next unless model.respond_to?(:pick)
  id = model.pick(:id)
  routes << [ path, action, { "id" => id } ] if id
end
routes.uniq!
routes.select! { |_path, action, _defaults| action == ENV["PROFILE_ACTION"] } if ENV["PROFILE_ACTION"].present?

canonical_json = lambda do |value|
  case value
  when Hash
    value.except("generated_at", "server_processing_ms", "cache_hit").sort.to_h.transform_values { |entry| canonical_json.call(entry) }
  when Array then value.map { |entry| canonical_json.call(entry) }
  else value
  end
end
results = routes.map do |controller_path, action, defaults|
  queries = []
  instantiated = Hash.new(0)
  model_subscription = ActiveSupport::Notifications.subscribe("instantiation.active_record") do |*args|
    event = args.last
    instantiated[event[:class_name]] += event[:record_count]
  end
  row = { controller: controller_path, action: action, parameters: defaults.except("format") }
  subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    next if event.payload[:name] == "SCHEMA"
    sql = event.payload[:sql].to_s.gsub(/'(?:[^']|'')*'/, "?").gsub(/\b\d+\b/, "?").squish
    queries << { ms: event.duration, fingerprint: Digest::SHA256.hexdigest(sql)[0, 16] }
  end
  started = clock.call
  begin
    controller = "#{controller_path.camelize}Controller".constantize.new
    request = ActionDispatch::TestRequest.create
    url = Rails.application.routes.url_helpers.url_for(
      defaults.symbolize_keys.merge(controller: controller_path, action: action, only_path: true)
    )
    uri = URI.parse(url)
    request.set_header("PATH_INFO", uri.path)
    request.set_header("QUERY_STRING", uri.query.to_s)
    request.path_parameters = defaults.merge("controller" => controller_path, "action" => action)
    row[:path] = uri.path
    request.set_header("HTTP_HOST", "localhost")
    request.set_header("HTTP_USER_AGENT", "Mozilla/5.0 Chrome/131.0.0.0 Safari/537.36")
    request.set_header("HTTP_ACCEPT", controller_path.start_with?("api/") ? "application/json" : "text/html")
    controller.set_request!(request)
    controller.set_response!(ActionDispatch::TestResponse.new)
    controller.define_singleton_method(:current_app_user) { payload }
    if controller_path.start_with?("api/")
      controller.define_singleton_method(:current_api_user) { profile_user }
      controller.define_singleton_method(:current_api_user_payload) { payload }
    end
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SET TRANSACTION READ ONLY")
      controller.process(action)
      row[:status] = controller.response.status
      row[:bytes] = controller.response.body.bytesize
      row[:media_type] = controller.response.media_type
      body = controller.response.body
      row[:body_sha256] = Digest::SHA256.hexdigest(body)
      if controller.response.media_type == "application/json"
        row[:content_sha256] = Digest::SHA256.hexdigest(JSON.generate(canonical_json.call(JSON.parse(body))))
      elsif controller.response.media_type == XlsxExporter::MIME_TYPE
        entries = []
        Zip::File.open_buffer(body) do |zip|
          entries = zip.entries.sort_by(&:name).map do |entry|
            content = entry.get_input_stream.read
            if entry.name == "docProps/core.xml"
              document = Nokogiri::XML(content)
              document.xpath("//*[local-name()='created' or local-name()='modified']").remove
              content = document.to_xml
            end
            [ entry.name, content ]
          end
        end
        row[:workbook_entries] = entries.to_h.transform_values { |content| Digest::SHA256.hexdigest(content) }
        row[:content_sha256] = Digest::SHA256.hexdigest(JSON.generate(entries))
      else
        document = Nokogiri::HTML(body)
        document.css('meta[name="csrf-token"], meta[name="csp-nonce"], input[name="authenticity_token"]').remove
        document.css("[data-dashboard-clock-time]").each { |node| node.content = "" }
        row[:content_sha256] = Digest::SHA256.hexdigest(document.to_html)
      end
      raise ActiveRecord::Rollback
    end
  rescue => error
    row[:error] = error.class.name
    row[:source] = error.backtrace&.find { |line| line.include?("/app/") }&.sub(Rails.root.to_s + "/", "")
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
    ActiveSupport::Notifications.unsubscribe(model_subscription)
  end
  row[:instantiated_records] = instantiated
  row[:total_ms] = ((clock.call - started) * 1000).round(2)
  row[:queries] = queries.size
  row[:sql_ms] = queries.sum { |query| query[:ms] }.round(2)
  row[:repeated_queries] = queries.group_by { |query| query[:fingerprint] }.filter_map do |fingerprint, entries|
    { fingerprint: fingerprint, count: entries.size, ms: entries.sum { |query| query[:ms] }.round(2) } if entries.size > 1
  end.sort_by { |entry| -entry[:count] }.first(5)
  warn "#{controller_path}##{action} #{defaults['slug']} #{row[:total_ms]}ms #{row[:error] || row[:status]}"
  row
end
puts JSON.pretty_generate(results: results, endpoints: results.size,
  successful: results.count { |row| row[:status] == 200 }, errors: results.count { |row| row[:error] })
