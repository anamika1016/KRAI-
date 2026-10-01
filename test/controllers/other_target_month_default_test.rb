require "test_helper"

# A new Other Target is entered for the month in progress, so the form opens on
# the current month instead of making the user pick it every time.
class OtherTargetMonthDefaultTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(first_name: "Other", last_name: "Target", user_name: "other_target_admin",
      email: "other-target@example.test", mobile_no: "9876500501", password: "secret",
      user_type: "admin", status: "Active")
    post login_path, params: { login: user.user_name, password: "secret" }
  end

  test "a new Other Target form pre-selects the current month" do
    travel_to(Time.zone.local(2026, 9, 30, 10)) do
      get "/modules/other-target"
      assert_response :success
      assert_select "select[data-seed-target-month] option[selected][value=?]", "September"
    end
  end

  test "the pre-selected month follows the calendar" do
    travel_to(Time.zone.local(2026, 11, 3, 10)) do
      get "/modules/other-target"
      assert_response :success
      assert_select "select[data-seed-target-month] option[selected][value=?]", "November"
    end
  end

  test "editing a saved Other Target keeps its own month" do
    record = ModuleRecord.create!(module_slug: "other-target", data: {
      "month" => "July", "jeevika_jankar_name" => "Saved JJ"
    })

    travel_to(Time.zone.local(2026, 9, 30, 10)) do
      get "/modules/other-target/records/#{record.id}/edit"
      assert_response :success
      assert_select "select[data-seed-target-month] option[selected][value=?]", "July"
      assert_select "select[data-seed-target-month] option[selected][value=?]", "September", count: 0
    end
  end
end
