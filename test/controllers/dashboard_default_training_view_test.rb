require "test_helper"

# The dashboard opens on the training view for every login. Other indicators
# are something the user picks from the filter, never a default they land on
# just because they have no training targets yet.
class DashboardDefaultTrainingViewTest < ActionDispatch::IntegrationTest
  setup do
    User.create!(user_name: "default_view_admin", password: "secret", first_name: "Default",
      last_name: "View", user_type: "admin", status: "Active",
      email: "default-view@example.test", mobile_no: "9876500941")
    post login_path, params: { login: "default_view_admin", password: "secret" }

    @vrp = Vrp.create!(name: "Default View JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current, aadhar_no: "123456789066",
      account_no: "1234567890", bank_name: "Bank", branch: "Branch", ifsc_code: "TEST0123456",
      address: "Address", mobile_no: "9876543266", email: "default_view_jj@example.com",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0, vrp_type_ids: [1],
      gram_panchayat_ids: [1], village_ids: [1], user_name: "default_view_jj", password: "secret",
      fcoc: "FCO-C Sausar", to_name: "TO-Hinganghat")

    @farmer = Afl.create!(farmer_name: "Default Farmer", tracenet_no: "default-1", fco_id: "1004",
      fco: "Sausar", ics_id: "ics-1", ics_name: "ICS One", village_id: "v1", village_name: "Village One")
  end

  test "a login with only Other targets still opens on the training dashboard" do
    target("Soil Sampling", "Soil Sample Collection")

    get "/dashboard", params: { month: month }
    assert_response :success
    assert_select "#dashboard_summary_boxes", 1, "Dashboard Summary belongs to the training view"
  end

  test "a login with no targets at all still opens on the training dashboard" do
    get "/dashboard", params: { month: month }
    assert_response :success
    assert_select "#dashboard_summary_boxes", 1
  end

  test "a login with training targets is unchanged" do
    target("Farmers' Training", "Soil")

    get "/dashboard", params: { month: month }
    assert_response :success
    assert_select "#dashboard_summary_boxes", 1
  end

  # Picking an Other indicator by hand still has to work -- the default is the
  # only thing that changed.
  test "choosing an Other indicator still leaves the training view" do
    target("Soil Sampling", "Soil Sample Collection")

    get "/dashboard", params: { month: month, main_activity: "Soil Sampling" }
    assert_response :success
    assert_select "#dashboard_summary_boxes", 0, "Dashboard Summary is training-only"
  end

  private

  def target(main_activity, sub_activity)
    TargetMapping.create!(vrp: @vrp, fco_id: "1004", fco_name: "Sausar", ics_id: "ics-1",
      ics_name: "ICS One", village_id: "v1", village_name: "Village One", month_name: month,
      main_activity_name: main_activity, activity_name: sub_activity,
      target_quantity: 3, afl_ids: [@farmer.id])
  end

  def month
    @month ||= Date.current.strftime("%B")
  end
end
