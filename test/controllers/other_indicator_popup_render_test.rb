require "test_helper"

# The per-FCO breakdown behind the "Main Major Work Indicator - Other" box is a
# hover popup. The dashboard renders one of two Other panels depending on the
# Main Activity filter, so the popup has to reach the page in both.
class OtherIndicatorPopupRenderTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(first_name: "Popup", last_name: "Admin", user_name: "popup_admin",
      email: "popup-admin@example.test", mobile_no: "9876500801", password: "secret",
      user_type: "admin", status: "Active")
    post login_path, params: { login: user.user_name, password: "secret" }

    ModuleRecord.create!(module_slug: "other-target", data: {
      "fcoc_name" => "Sausar", "month" => "September", "main_activity" => "Internal Inspection",
      "sub_activity" => "Documentation", "target" => "36", "achievement" => "30"
    })
    ModuleRecord.create!(module_slug: "other-target", data: {
      "fcoc_name" => "Turekela", "month" => "September", "main_activity" => "Seed Packet Distribution",
      "sub_activity" => "Non GMO Seed", "target" => "100", "achievement" => "40"
    })
  end

  test "the popup renders when no Farmers' Training data exists" do
    get "/dashboard", params: { month: "September" }
    assert_response :success

    assert_popup
  end

  test "the popup renders on the Farmers' Training view too" do
    vrp = Vrp.new(name: "Popup JJ", father_husband_name: "Father", gender: :female,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: "9876500802", email: "popup-jj@example.test", fcoc: "Sausar",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    vrp.save!(validate: false)
    target = TargetMapping.new(vrp: vrp, fco_id: "1004", fco_name: "Sausar", ics_id: "p-ics",
      ics_name: "P ICS", village_id: "p-village", village_name: "P Village", month_name: "September",
      main_activity_name: "Farmers' Training", activity_name: "Module-4", target_quantity: 10)
    target.save!(validate: false)

    get "/dashboard", params: { month: "September", main_activity: "Farmers' Training" }
    assert_response :success

    assert_select "#other_major_work_indicator_boxes", minimum: 1
    assert_popup
  end

  private

  def assert_popup
    assert_select ".dashboard-card-hover-popup span", text: "Sausar = 30/36"
    assert_select ".dashboard-card-hover-popup span", text: "Turekela = 40/100"
  end
end
