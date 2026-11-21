require "test_helper"

class MasterListInitialRenderTest < ActionDispatch::IntegrationTest
  test "large master pages retain every row and action while showing the existing first page immediately" do
    admin = User.create!(user_name: "master-render-#{SecureRandom.hex(4)}", first_name: "Admin",
      password: "secret", user_type: "admin", status: "Active")
    251.times do |index|
      ModuleRecord.create!(module_slug: "state-master", data: {
        "state_name" => "Performance state #{index.to_s.rjust(3, '0')}", "state_code" => index.to_s, "status" => "Active"
      })
    end
    post login_path, params: { login: admin.user_name, password: "secret" }
    get module_path("state-master")
    assert_response :success
    assert_select 'meta[name="turbo-cache-control"]', count: 0
    assert_select 'meta[name="turbo-visit-control"][content="reload"]', count: 0
    rows = css_select("#module_saved_records tbody tr")
    assert_operator rows.size, :>=, 251
    assert_equal 15, rows.count { |row| !row.key?("hidden") }
    assert_equal rows.size - 15, rows.count { |row| row.key?("data-initial-page-hidden") }
    assert rows.last.css("a, form").any?, "Later-page rows must retain their edit/status/delete actions"
    assert_includes response.body, "Performance state 250"
    assert_includes response.body, "#module_saved_records tr[data-initial-page-hidden] { display: table-row !important; }"
  end
end
