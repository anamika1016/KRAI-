require "test_helper"

class RequestLookupPerformanceTest < ActiveSupport::TestCase
  test "mobile agreement batch retains individual labels and missing village fallbacks" do
    villages = 3.times.map { |i| ModuleRecord.create!(module_slug: "village-master", data: { "village_name" => "Village #{i}" }) }
    ids = villages.map(&:id) + ["0#{villages.first.id}", "missing-village", nil]
    vrps = ids.map { |id| Vrp.new(village_ids: [id].compact) }
    original = Api::V1::VrpAgreementsController.new
    expected = vrps.map { |vrp| original.send(:agreement_village_name, vrp) }
    controller = Api::V1::VrpAgreementsController.new
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      payload = args.last
      queries << payload[:sql] if payload[:name] != "SCHEMA" && payload[:sql].include?('FROM "module_records"')
    end
    controller.send(:preload_agreement_villages, vrps)
    assert_equal expected, vrps.map { |vrp| controller.send(:agreement_village_name, vrp) }
    assert_equal 1, queries.size
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "agreement village label keeps source precedence and skips unused fallbacks" do
    controller = VrpAgreementsController.new
    calls = []
    sources = %i[module_records target_mapping vrp_ics_mapping afl]
    values = [ nil, " ", "Village", "Other village" ]
    sources.zip(values).each do |source, value|
      controller.define_singleton_method("agreement_village_name_from_#{source}") do |_id|
        calls << source
        value
      end
    end
    3.times { assert_equal "Village", controller.send(:agreement_village_label, "42") }
    assert_equal sources.first(3), calls
  end

  test "mobile agreement rows reuse village lookups across farmers without changing blank fallback" do
    record = ModuleRecord.create!(module_slug: "village-master", data: { "village_name" => "Same village" })
    controller = Api::V1::VrpAgreementsController.new
    vrps = 4.times.map { Vrp.new(village_ids: [ record.id ]) }
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      payload = args.last
      queries << payload[:sql] if payload[:name] != "SCHEMA" && payload[:sql].include?('FROM "module_records"')
    end
    assert_equal [ "Same village" ] * 4, vrps.map { |vrp| controller.send(:agreement_village_name, vrp) }
    assert_equal 1, queries.size
    assert_equal "-", controller.send(:agreement_village_name, Vrp.new)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "registration creator lookup caches missing IDs while retaining per-JJ legacy matching" do
    controller = Api::V1::JeevikaJankarsController.new
    user = User.create!(user_name: "lookup-#{SecureRandom.hex(4)}", first_name: "Creator", password: "secret", user_type: "admin", status: "Active")
    vrps = 4.times.map { |index| Vrp.new(id: 900000 + index, created_by_id: user.id) }
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      payload = args.last
      queries << payload[:sql] if payload[:name] != "SCHEMA" && payload[:sql].match?(/FROM "(?:users|module_records)"/)
    end
    assert_equal [ user.id ] * 4, vrps.map { |vrp| controller.send(:registered_by_user, vrp)&.id }
    assert_equal 2, queries.size, "One user and one optional legacy lookup per distinct creator"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
