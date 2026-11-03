require "test_helper"

# The type master still spells a Jeevika Jankar's type "VRP". The login
# response is user-facing, so it says Jeevika Jankar -- without disturbing the
# stored spelling that Access Control matches a JJ login on.
class Api::V1::LoginRoleLabelTest < ActionDispatch::IntegrationTest
  setup do
    @type = VrpType.find_or_create_by!(type_name: "VRP")
    @vrp = Vrp.create!(name: "Role Label JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current, aadhar_no: "123456770011",
      account_no: "1234567890", bank_name: "Bank", branch: "Branch", ifsc_code: "TEST0123456",
      address: "Address", mobile_no: "9876570011", email: "role_label_jj@example.com",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0,
      vrp_type_ids: [@type.id], gram_panchayat_ids: [1], village_ids: [1],
      user_name: "role_label_jj", password: "secret", fcoc: "FCO-C Sausar",
      status: 55, is_active: true, agreement_accepted_at: Time.current)
  end

  test "the session payload calls the role Jeevika Jankar, not VRP" do
    payload = build_payload
    assert_equal "Jeevika Jankar", payload["role"]
    refute_equal "VRP", payload["role"]
  end

  # Access Control matches a JJ login on vrp_types alone, so that list has to
  # keep the spelling the master actually stores.
  test "vrp_types keeps the stored spelling" do
    assert_includes build_payload["vrp_types"], "VRP"
  end

  test "another type name is left exactly as the master spells it" do
    crp = VrpType.find_or_create_by!(type_name: "CRP")
    @vrp.update!(vrp_type_ids: [crp.id])

    assert_equal "CRP", build_payload["role"]
  end

  test "the web sidebar shows the renamed role too" do
    post login_path, params: { login: "role_label_jj", password: "secret" }
    follow_redirect!
    assert_response :success
    assert_select ".side-user small", text: "Jeevika Jankar"
  end

  # The real endpoint, not just the payload builder.
  test "POST /api/v1/login returns Jeevika Jankar as the role" do
    post "/api/v1/login", params: { login: "role_label_jj", password: "secret" }, as: :json
    assert_response :success

    user = response.parsed_body.fetch("user")
    assert_equal "Jeevika Jankar", user["role"]
    assert_includes Array(user["vrp_types"]), "VRP", "the stored spelling still travels"
  end

  private

  def build_payload
    controller = ApplicationController.new
    controller.send(:app_user_session_payload, @vrp.reload)
  end
end
