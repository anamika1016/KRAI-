require "test_helper"

# The sidebar must show exactly what Access Control granted for the role --
# no more.
class AccessControlSidebarTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(first_name: "Access", last_name: "Agronomist",
      user_name: "acl_agronomist", email: "acl-agro@example.test", mobile_no: "9876500811",
      password: "secret", user_type: "User", status: "Active",
      stakeholder: "PAPL", stakeholder_role: "Agronomist", role: "agricultural specialist")

    ModuleRecord.create!(module_slug: "access-control", data: {
      "stakeholder" => "PAPL", "stakeholder_role" => "Agronomist",
      "role" => "agricultural specialist", "can_view" => "Yes",
      "sub_module_names" => ["Training Form List", "Other Target List"]
    })

    post login_path, params: { login: @user.user_name, password: "secret" }
  end

  test "only the two granted lists appear under Farmer Target" do
    get "/dashboard"
    assert_response :success

    assert_includes sidebar_links, "Training Form List"
    assert_includes sidebar_links, "Other Target List"
  end

  # This one is granted to nobody here, but an Agronomist/Cluster role used to
  # get it regardless of Access Control.
  test "Training Form Edit Approval List needs its own access" do
    get "/dashboard"
    assert_response :success

    refute_includes sidebar_links, "Training Form Edit Approval List"
  end

  test "an un-granted sibling list stays hidden" do
    get "/dashboard"
    assert_response :success

    refute_includes sidebar_links, "Other Target"
    refute_includes sidebar_links, "Training Form"
    refute_includes sidebar_links, "Farmer Participation Report"
  end

  # Editing the access record has to take effect on the next page load. The
  # allowed-keys cache is keyed on the records' own fingerprint, so no manual
  # cache clearing here on purpose -- that is what is being checked.
  test "editing the access record updates the sidebar straight away" do
    get "/dashboard"
    assert_response :success
    refute_includes sidebar_links, "Training Form Edit Approval List"

    record = ModuleRecord.where(module_slug: "access-control").first
    record.update!(data: record.data.merge(
      "sub_module_names" => ["Training Form List", "Other Target List", "Training Form Edit Approval List"]))

    get "/dashboard"
    assert_response :success
    assert_includes sidebar_links, "Training Form Edit Approval List"
  end

  test "removing a list takes it away again" do
    record = ModuleRecord.where(module_slug: "access-control").first
    record.update!(data: record.data.merge("sub_module_names" => ["Training Form List"]))

    get "/dashboard"
    assert_response :success
    assert_includes sidebar_links, "Training Form List"
    refute_includes sidebar_links, "Other Target List"
  end

  private

  def sidebar_links
    Nokogiri::HTML(response.body).css(".side-subnav a, .side-nav a").map { |a| a.text.strip }
  end
end
