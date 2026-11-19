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
end
