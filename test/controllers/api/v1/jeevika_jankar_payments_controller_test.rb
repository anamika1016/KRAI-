require "test_helper"

# Production crashed both mobile Bill and Payment lists with a 500:
# NoMethodError (undefined method 'filtered_parameters' for nil) in
# ModulesController#current_slug. The #calculator helper built a fresh
# ModulesController but never set its request, so anything downstream that
# reads the URL (current_slug, current_sidebar_menu_title) found params nil.
class Api::V1::JeevikaJankarPaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(first_name: "Admin", last_name: "User", user_name: "admin_#{SecureRandom.hex(4)}",
      email: "admin-#{SecureRandom.hex(4)}@example.test", mobile_no: "9876500#{rand(100..999)}",
      password: "secret", user_type: "admin", status: "Active")

    @vrp = Vrp.create!(name: "Bill JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current, aadhar_no: "123456789012",
      account_no: "1234567890", bank_name: "Bank", branch: "Branch", ifsc_code: "TEST0123456",
      address: "Address", mobile_no: "9876500800", email: "bill-jj-#{SecureRandom.hex(4)}@example.test",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0, vrp_type_ids: [1],
      gram_panchayat_ids: [1], village_ids: [1], user_name: "bill_jj_#{SecureRandom.hex(4)}", password: "secret")

    ModuleRecord.create!(module_slug: "jeevika-jankar-bill-process", data: {
      "select_vrp" => @vrp.id.to_s, "bill_month" => "September", "bill_status" => "pending", "record_state" => "Active"
    })
  end

  test "the mobile bill list does not 500" do
    get "/api/v1/jeevika-jankar-bills", headers: headers(@admin)

    assert_response :success
    assert response.parsed_body["success"]
    assert_operator response.parsed_body.fetch("bills").size, :>=, 1
  end

  test "the mobile payment list does not 500" do
    get "/api/v1/jeevika-jankar-payments", params: { month: "September" }, headers: headers(@admin)

    assert_response :success
    assert response.parsed_body["success"]
  end

  private

  def headers(user)
    { "Authorization" => "Bearer #{ApiAuthToken.encode(user)}" }
  end
end
