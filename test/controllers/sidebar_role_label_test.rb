require "test_helper"

# The sidebar footer names the signed-in person's role, not their account type.
class SidebarRoleLabelTest < ActionDispatch::IntegrationTest
  test "a user with a role shows the role under their name" do
    sign_in_as(role: "Cluster Incharge", stakeholder_role: "Cluster Coordinator")

    get "/dashboard"
    assert_response :success
    assert_select ".side-user small", text: "Cluster Incharge"
    assert_select ".side-user small", text: "User", count: 0
  end

  test "a blank role falls back to the next spelling before the account type" do
    sign_in_as(role: nil, stakeholder_role: "Agronomist")

    get "/dashboard"
    assert_response :success
    assert_select ".side-user small", text: "Agronomist"
  end

  test "generic User role is skipped when an actual designation exists" do
    sign_in_as(role: "User", stakeholder_role: "Cluster Coordinator")

    get "/dashboard"
    assert_response :success
    assert_select ".side-user small", text: "Cluster Coordinator"
    assert_select ".side-user small", text: "User", count: 0
  end

  test "an account with no role at all keeps showing its account type" do
    sign_in_as(role: nil, stakeholder_role: nil, user_type: "Admin")

    get "/dashboard"
    assert_response :success
    assert_select ".side-user small", text: "Admin"
  end

  test "a regular account without a role never shows generic User" do
    sign_in_as(role: nil, stakeholder_role: nil)

    get "/dashboard"
    assert_response :success
    assert_select ".side-user small", text: "Role not assigned"
    assert_select ".side-user small", text: "User", count: 0
  end

  private

  def sign_in_as(role:, stakeholder_role: nil, user_type: "User")
    user = User.create!(first_name: "Raghuvir", last_name: "Prajapat",
      user_name: "sidebar_role_#{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(4)}@example.test",
      mobile_no: "9876500#{rand(100..999)}", password: "secret", user_type: user_type,
      role: role, stakeholder_role: stakeholder_role, status: "Active")
    post login_path, params: { login: user.user_name, password: "secret" }
  end
end
