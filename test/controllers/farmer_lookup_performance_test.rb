require "test_helper"

class FarmerLookupPerformanceTest < ActiveSupport::TestCase
  test "farmer availability preserves order and mixed ID handling" do
    controller = Api::V1::FarmerTrainingsController.new
    first = { id: 1, name: "First" }
    second = { id: "2", name: "Second" }
    third = { id: 3, name: "Third" }
    mappings = [
      { farmers: [first, second], completed_farmer_ids: [1, "1"] },
      { farmers: [{ id: "1", name: "Duplicate" }, third], completed_farmer_ids: ["3"] }
    ]
    assert_equal [[first, second, third], [second], %w[1 3]],
      controller.send(:farmer_lists_for, mappings)
  end

  test "single VRP lookup keeps visibility and avoids loading the population" do
    records = 3.times.map do |index|
      record = Vrp.new(name: "Lookup #{index}", aadhar_no: "123456789012", account_no: "1234",
        address: "Test", branch: "Test", date_of_birth: Date.new(1990, 1, 1),
        date_of_joining: Date.current, email: "lookup-#{index}@example.test",
        experience_in_years: 1, father_husband_name: "Test", gender: :male,
        ifsc_code: "SBIN0001234", mobile_no: "9876543210", office_detail_id: 1, to_office_detail_id: 1)
      record.save!(validate: false)
      record
    end
    scope = Vrp.where(id: records.first(2).map(&:id))
    controller = VrpsController.new
    controller.define_singleton_method(:visible_vrps) { scope }
    instantiated = 0
    subscriber = ActiveSupport::Notifications.subscribe("instantiation.active_record") do |*args|
      payload = args.last
      instantiated += payload[:record_count] if payload[:class_name] == "Vrp"
    end
    assert_equal records.first, controller.send(:find_visible_vrp, records.first.id.to_s)
    assert_nil controller.send(:find_visible_vrp, records.last.id.to_s)
    assert_equal 1, instantiated
    assert_not scope.loaded?
    controller.define_singleton_method(:visible_vrps) { records.first(2) }
    assert_equal records.first, controller.send(:find_visible_vrp, records.first.id.to_s)
    assert_nil controller.send(:find_visible_vrp, records.last.id.to_s)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
