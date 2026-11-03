require "test_helper"

class Api::V1::VrpAgreementsControllerTest < ActionDispatch::IntegrationTest
  SIGNATURE = "data:image/png;base64,aGVsbG8=".freeze

  test "JJ can load and accept the first-login agreement then use returned token" do
    vrp = create_vrp(user_name: "agreement_api_jj", password: "secret")

    get "/api/v1/jeevika-jankar-agreement", params: { username: vrp.user_name, password: "secret" }, as: :json
    assert_response :success
    agreement = response.parsed_body.fetch("agreement")
    assert_equal true, agreement["required"]
    assert_equal 7, agreement.fetch("terms").size

    post "/api/v1/jeevika-jankar-agreement",
      params: { username: vrp.user_name, password: "secret", decision: "agree", signature_data: SIGNATURE }, as: :json
    assert_response :success
    body = response.parsed_body
    assert body["token"].present?
    assert_equal true, body.dig("agreement", "accepted")
    assert_equal SIGNATURE, vrp.reload.agreement_signature_data

    get api_v1_me_path, headers: { "Authorization" => "Bearer #{body.fetch("token")}" }, as: :json
    assert_response :success
  end

  test "agreement API rejects missing signature and bad credentials" do
    vrp = create_vrp(user_name: "agreement_api_no_signature", password: "secret")
    post "/api/v1/jeevika-jankar-agreement", params: { username: vrp.user_name, password: "secret" }, as: :json
    assert_response :unprocessable_entity
    assert_nil vrp.reload.agreement_accepted_at

    get "/api/v1/jeevika-jankar-agreement", params: { username: vrp.user_name, password: "wrong" }, as: :json
    assert_response :unauthorized
  end

  test "accepted-agreements list returns signed rows to admin and rejects JJ tokens" do
    signed = create_vrp(user_name: "agreement_api_signed", password: "secret",
      agreement_accepted_at: Time.current, agreement_signature_data: SIGNATURE)
    create_vrp(user_name: "agreement_api_unsigned", password: "secret", agreement_accepted_at: Time.current)
    admin = build_admin_user
    admin.save!(validate: false)

    get "/api/v1/vrp-agreements", headers: { "Authorization" => "Bearer #{ApiAuthToken.encode(admin)}" }, as: :json
    assert_response :success
    assert_equal [signed.id], response.parsed_body.fetch("agreements").map { |row| row.fetch("id") }

    get "/api/v1/vrp-agreements/#{signed.id}", headers: { "Authorization" => "Bearer #{ApiAuthToken.encode(admin)}" }, as: :json
    assert_response :success
    assert_equal SIGNATURE, response.parsed_body.dig("agreement", "signature_data")

    get "/api/v1/vrp-agreements", headers: { "Authorization" => "Bearer #{ApiAuthToken.encode(signed)}" }, as: :json
    assert_response :forbidden
  end

  test "admin can load a selected JJ identity for the agreement form" do
    vrp = create_vrp(user_name: "agreement_selected_jj", password: "secret")
    admin = User.new(first_name: "Agreement", last_name: "Admin", user_name: "agreement_selected_admin",
      email: "agreement-selected-admin@example.test", mobile_no: "9876500912",
      password: "secret", user_type: "admin", status: "Active")
    admin.save!(validate: false)

    get "/api/v1/jeevika-jankar-agreement",
      params: { username: admin.user_name, password: "secret", vrp_id: vrp.id }, as: :json

    assert_response :success
    agreement = response.parsed_body.fetch("agreement")
    assert_equal vrp.name, agreement.fetch("name")
    assert_equal vrp.mobile_no, agreement.fetch("mobile_no")
    assert_equal true, agreement.fetch("required")
  end

  private

  def create_vrp(attributes = {})
    defaults = {
      name: "Agreement API JJ", father_husband_name: "Test Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234567890", bank_name: "Test Bank",
      branch: "Test Branch", ifsc_code: "TEST0123456", address: "Test Address",
      mobile_no: "9876543210", email: "agreement-#{SecureRandom.hex(4)}@example.test",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0,
      vrp_type_ids: [1], gram_panchayat_ids: [1], village_ids: [1], is_active: true, is_deleted: false
    }
    Vrp.create!(defaults.merge(attributes))
  end

  def build_admin_user
    User.new(first_name: "Agreement", last_name: "Admin", user_name: "agreement_admin_#{SecureRandom.hex(3)}",
      email: "agreement-admin-#{SecureRandom.hex(3)}@example.test", mobile_no: "9876500911",
      password: "secret", user_type: "admin", status: "Active", role: "Manager ics")
  end
end
