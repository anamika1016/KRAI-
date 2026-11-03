require "test_helper"

# Deactivating a Jeevika Jankar stops them logging in and takes their name out
# of the pickers, but must not hide work already recorded against them.
class InactiveJjVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(user_name: "inactive_jj_admin", password: "secret", first_name: "Inactive",
      last_name: "Admin", user_type: "admin", status: "Active",
      email: "inactive-jj@example.test", mobile_no: "9876500821")

    @active = jj("Active JJ", "active_jj_login", is_active: true)
    @retired = jj("Retired JJ", "retired_jj_login", is_active: false)

    # A bill raised while they were still active.
    @bill = ModuleRecord.create!(module_slug: "jeevika-jankar-bill-process", data: {
      "select_vrp" => @retired.id.to_s, "jeevika_jankar_name" => "Retired JJ",
      "bill_month" => "June", "status" => "Final Approved", "grand_total" => "5000"
    })
  end

  test "an inactive Jeevika Jankar cannot log in" do
    post login_path, params: { login: "retired_jj_login", password: "secret" }
    assert_redirected_to login_path
    follow_redirect!
    assert_match(/invalid username or password/i, response.body)
  end

  test "an active Jeevika Jankar can still log in" do
    post login_path, params: { login: "active_jj_login", password: "secret" }
    assert_redirected_to dashboard_path, "an active JJ must still get in"
  end

  test "the Bill Process picker leaves the inactive one out" do
    sign_in_admin
    get module_path("jeevika-jankar-bill-process")
    assert_response :success

    options = Nokogiri::HTML(response.body).css("select[data-jeevika-vrp-select] option").map { |o| o.text.strip }
    refute_includes options, "Retired JJ"
  end

  test "the Target Mapping picker leaves the inactive one out" do
    sign_in_admin
    get target_mappings_path
    assert_response :success
    refute_includes response.body, "Retired JJ"
  end

  test "the dashboard Jeevika Jankar filter leaves the inactive one out" do
    sign_in_admin
    get "/dashboard"
    assert_response :success

    options = Nokogiri::HTML(response.body).css("select option").map { |o| o.text.strip }
    refute_includes options, "Retired JJ"
  end

  # "Kahin bhi nahi dikhega" -- every form that picks a Jeevika Jankar.
  {
    "Training Form" => "training-form",
    "Other Target" => "other-target",
    "Jeevika Jankar Transfer" => "jeevika-jankar-transfer"
  }.each do |label, slug|
    test "the #{label} picker leaves the inactive one out" do
      sign_in_admin
      get module_path(slug)
      next unless response.successful?

      options = Nokogiri::HTML(response.body).css("select option").map { |o| o.text.strip }
      refute_includes options, "Retired JJ", "#{label} still offers a deactivated JJ"
    end
  end

  # The point of deactivating is to stop new work, not to erase old work.
  test "a bill raised before deactivation is still listed" do
    sign_in_admin
    get module_path("jeevika-jankar-bill-list")
    assert_response :success
    assert_includes response.body, "Retired JJ"
  end

  test "activating them again puts the name back in the picker" do
    @retired.update!(is_active: true)
    sign_in_admin

    get module_path("jeevika-jankar-bill-process")
    assert_response :success
    options = Nokogiri::HTML(response.body).css("select[data-jeevika-vrp-select] option").map { |o| o.text.strip }
    assert_includes options, "Retired JJ"
  end

  private

  def sign_in_admin
    post login_path, params: { login: @admin.user_name, password: "secret" }
  end

  def jj(name, login, is_active:)
    Vrp.create!(name: name, father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "12345678#{rand(1000..9999)}", account_no: "1234567890", bank_name: "Bank",
      branch: "Branch", ifsc_code: "TEST0123456", address: "Address",
      mobile_no: "98765#{rand(10000..99999)}", email: "#{login}@example.com",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0, vrp_type_ids: [1],
      gram_panchayat_ids: [1], village_ids: [1], user_name: login, password: "secret",
      fcoc: "FCO-C Sausar", status: 55, is_active: is_active,
      agreement_accepted_at: Time.current)
  end
end
