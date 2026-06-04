require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "vrp must accept agreement on first login" do
    vrp = create_vrp(user_name: "first_vrp", password: "secret")

    post login_path, params: { login: "first_vrp", password: "secret" }

    assert_redirected_to vrp_agreement_path
    assert_nil vrp.reload.agreement_accepted_at

    get vrp_agreement_path
    assert_response :success
    assert_includes response.body, "कृषि जानकार"

    post vrp_agreement_path, params: { decision: "agree" }

    assert_redirected_to dashboard_path
    assert vrp.reload.agreement_accepted_at.present?
  end

  test "vrp login remains blocked when agreement is declined" do
    vrp = create_vrp(user_name: "decline_vrp", password: "secret")

    post login_path, params: { login: "decline_vrp", password: "secret" }
    post vrp_agreement_path, params: { decision: "decline" }

    assert_redirected_to login_path
    assert_nil vrp.reload.agreement_accepted_at
  end

  test "vrp with accepted agreement logs in directly" do
    create_vrp(user_name: "accepted_vrp", password: "secret", agreement_accepted_at: Time.current)

    post login_path, params: { login: "accepted_vrp", password: "secret" }

    assert_redirected_to dashboard_path
  end

  private

  def create_vrp(attributes = {})
    defaults = {
      name: "Test VRP",
      father_husband_name: "Test Father",
      gender: :male,
      date_of_birth: Date.new(1990, 1, 1),
      date_of_joining: Date.current,
      aadhar_no: "123456789012",
      account_no: "1234567890",
      bank_name: "Test Bank",
      branch: "Test Branch",
      ifsc_code: "TEST0123456",
      address: "Test Address",
      mobile_no: "9876543210",
      email: "vrp#{SecureRandom.hex(4)}@example.com",
      experience_in_years: 1,
      office_detail_id: 0,
      to_office_detail_id: 0,
      vrp_type_ids: [1],
      gram_panchayat_ids: [1],
      village_ids: [1],
      is_active: true,
      is_deleted: false
    }

    Vrp.create!(defaults.merge(attributes))
  end
end
