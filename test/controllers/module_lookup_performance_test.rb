require "test_helper"

class ModuleLookupPerformanceTest < ActiveSupport::TestCase
  test "lightweight location rows preserve flags order and JSON value types" do
    records = [
      { "state" => "S", "district" => "D", "block_name" => "First", "status" => " Active " },
      { "block_name" => "Inactive", "status" => "Inactive" },
      { "block_name" => "Deleted", "deleted" => " YES " },
      { "block_name" => "Last", "block_code" => 123, "aliases" => ["a", "b"] }
    ].each_with_index.map do |data, index|
      ModuleRecord.create!(module_slug: "block-master", data: data, created_at: index.minutes.ago)
    end
    controller = ModulesController.new
    expected = ModuleRecord.where(module_slug: "block-master").order(created_at: :desc)
      .select { |record| controller.send(:active_module_record?, record) }
      .map { |record| [record.id, record.data] }

    queries = capture_queries("module_records") do
      2.times do
        actual = controller.send(:active_records_for_location, "block-master")
        assert_equal expected, actual.map { |record| [record.id, record.data] }
      end
    end
    assert_equal 1, queries.size
    assert_equal records.first.id, expected.first.first
  end

  test "location index preserves first matching candidate aliases and ignores numeric names" do
    controller = ModulesController.new
    candidates = [
      { "state_name" => " S ", "district_name" => "D", "cd_block_name" => "B", "gp_code" => "12", "gram_name" => "First" },
      { "state" => "S", "district" => "D", "block" => "B", "gram_code" => "12", "gram_name" => "Second" },
      { "state" => "S", "district" => "D", "block" => "Other", "gp_code" => "12", "gram_name" => "Other" },
      { "state" => "S", "district" => "D", "block" => "B", "gp_code" => "13" }
    ].map { |data| ModuleRecord.new(data: data) }
    controller.define_singleton_method(:gram_panchayat_location_records) { candidates }
    village = ModuleRecord.new(data: { "state" => "S", "district" => "D", "block" => "B" })
    assert_equal "First", controller.send(:gram_panchayat_name_by_location, village, "12")
    assert_nil controller.send(:gram_panchayat_name_by_location, village, "13")
    assert_nil controller.send(:gram_panchayat_name_by_location, village, "missing")
  end

  test "VRP label index preserves ID priority and first match across competing labels" do
    controller = ModulesController.new
    first = Vrp.new(id: 901, name: "Alias", user_name: "first", mobile_no: "9876500001")
    second = Vrp.new(id: 902, name: "Second", user_name: "Alias", mobile_no: "9876500002")
    third = Vrp.new(id: 903, name: "alias", user_name: "third")
    vrps = [first, second, third]
    controller.define_singleton_method(:cached_vrps_by_id) { vrps.index_by { |vrp| vrp.id.to_s } }
    ["Alias", " ALIAS ", "first", "9876500002", "902", "missing"].each do |label|
      expected = vrps.find { |vrp| vrp.id.to_s == label } || vrps.find do |vrp|
        vrp.name.to_s == label || vrp.user_name.to_s == label || vrp.mobile_no.to_s == label ||
          vrp.name.to_s.downcase == controller.send(:normalize_dashboard_text, label).downcase
      end
      actual = controller.send(:cached_vrp_lookup, label)
      expected ? assert_equal(expected.id, actual&.id) : assert_nil(actual)
    end
  end

  test "approval channel lookup queries once for multiple rows and retains inactive steps" do
    data = { "module_name" => "VRP Bill", "stakeholder_name" => "Staff", "user_name" => "Person" }
    first = ModuleRecord.create!(module_slug: "approval-master", data: data.merge("status" => "Inactive"), created_at: 2.minutes.ago)
    second = ModuleRecord.create!(module_slug: "approval-master", data: data.merge("approval_level" => "Second Approval"))
    controller = ModulesController.new
    queries = capture_queries("module_records") do
      [first, second].each do |record|
        assert_equal [first.id, second.id], controller.send(:approval_channel_records_for, record).map(&:id)
      end
    end
    assert_equal 1, queries.size
  end

  test "approver dropdown reuses users across approval form rows" do
    User.create!(first_name: "Lookup", last_name: "Approver", user_name: "lookup_approver",
      email: "lookup-approver@example.test", mobile_no: "9876500098", password: "secret",
      role: "Manager", status: "Active")
    controller = ModulesController.new
    expected = User.order(created_at: :desc).filter_map do |user|
      name = user.full_name.presence || user.user_name.presence
      next if name.blank?

      user.role.present? ? "#{name} (#{user.role})" : name
    end.uniq
    queries = capture_queries("users") do
      3.times { assert_equal expected, controller.send(:approver_options) }
    end
    assert_equal 1, queries.size
  end

  private

  def capture_queries(table)
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      payload = args.last
      queries << payload[:sql] if payload[:name] != "SCHEMA" && payload[:sql].include?(%Q{"#{table}"})
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
