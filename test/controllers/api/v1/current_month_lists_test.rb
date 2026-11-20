require "test_helper"

class Api::V1::CurrentMonthListsTest < ActiveSupport::TestCase
  setup do
    @controller = Api::V1::BaseController.new
    @controller.instance_variable_set(:@current_api_user_payload, { "record_type" => "Vrp" })
  end

  test "month rolls over and excludes old and future activity rows" do
    rows = %w[October November December].map do |month|
      { data: { "month" => month }, created_at: Time.zone.local(2026, 11, 10) }
    end
    travel_to Time.zone.local(2026, 11, 19) do
      assert_equal [rows[1]], @controller.send(:current_month_module_rows, rows)
    end
    travel_to Time.zone.local(2026, 12, 1) do
      assert_equal [rows[2]], @controller.send(:current_month_module_rows, rows)
    end
  end

  test "undated module rows use creation month including year" do
    travel_to Time.zone.local(2026, 11, 19) do
      current = { data: {}, created_at: Time.zone.local(2026, 11, 1) }
      old = { data: {}, created_at: Time.zone.local(2025, 11, 1) }
      assert_equal [current], @controller.send(:current_month_module_rows, [old, current])
    end
  end

  test "CC roles are restricted and admin lists retain history" do
    %w[CC].concat(["Cluster Incharge", "Cluster Coordinator"]).each do |role|
      @controller.instance_variable_set(:@current_api_user_payload, { "role" => role })
      assert @controller.send(:current_month_lists?), role
    end
    @controller.instance_variable_set(:@current_api_user_payload, { "role" => "Admin" })
    rows = [{ data: { "month" => "October" } }]
    assert_equal rows, @controller.send(:current_month_module_rows, rows)
  end

  test "all farmer work lists enforce current month for JJ and CC even with old month params" do
    controllers = [Api::V1::FarmerTrainingsController, Api::V1::OtherTargetsController,
      Api::V1::SeedDistributionTargetsController, Api::V1::Papl360TargetsController,
      Api::V1::AddFarmerFormsController]
    travel_to Time.zone.local(2026, 11, 20) do
      [{ "record_type" => "Vrp" }, { "role" => "Cluster Incharge" }].each do |payload|
        controllers.each do |klass|
          controller = klass.new
          controller.instance_variable_set(:@current_api_user_payload, payload)
          controller.params = ActionController::Parameters.new(month: "October", all: "1")
          rows = %w[October November December].map { |month| { data: { "month" => month } } }
          service = Object.new
          service.define_singleton_method(:list) { |month:| rows }
          service.define_singleton_method(:training_list) { |**options| rows }
          controller.define_singleton_method(:farmer_target_api) { service }
          controller.define_singleton_method(:render) { |json:, **options| @rendered = json }
          controller.index
          result = controller.instance_variable_get(:@rendered)
          assert_equal 1, result[:count], klass.name
          assert_equal "November", result[klass::RESOURCE_KEY].first[:data]["month"], klass.name
        end
      end
    end
  end

  test "bill list month cannot be overridden by an old month or All" do
    controller = Api::V1::JeevikaJankarPaymentsController.new
    travel_to Time.zone.local(2026, 12, 1) do
      [{ "record_type" => "Vrp" }, { "role" => "CC" }].each do |payload|
        controller.instance_variable_set(:@current_api_user_payload, payload)
        %w[November All].each do |month|
          controller.params = ActionController::Parameters.new(month: month)
          rows = [{ bill_month: "November" }, { bill_month: "December" }]
          assert_equal [rows.last], controller.send(:filter_month, rows)
        end
      end
    end
  end

end
