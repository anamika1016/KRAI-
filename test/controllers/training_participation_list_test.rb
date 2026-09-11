require "test_helper"
require "ostruct"

class TrainingParticipationListTest < ActiveSupport::TestCase
  test "all four lists enrich matching farmers without changing counts or status" do
    controller = ModulesController.new
    controller.request = ActionDispatch::TestRequest.create
    %w[unique red yellow green].each do |status|
      rows = [
        { farmer_id: "11", cluster_incharge: "-", attendance_count: 2, status: status },
        { farmer_id: "12", cluster_incharge: "-", attendance_count: 0, status: status }
      ]
      target = OpenStruct.new(afl_ids: %w[11 12], vrp: OpenStruct.new(cluster_incharge: "Mapped CC"))
      record = ModuleRecord.new(module_slug: "training-form", data: {
        "selected_farmer_ids" => ["11"], "cluster_coordinator" => "Training CC",
        "training_register_upload" => ["/uploads/register.pdf"],
        "training_photo_upload_with_geo_tag" => ["/uploads/photo.jpg", "/uploads/photo.jpg"]
      })
      controller.send(:enrich_training_participation_list_rows!, rows, [record], [target])
      assert_equal "Mapped CC, Training CC", rows.first[:cluster_incharge]
      assert_equal "Mapped CC", rows.last[:cluster_incharge]
      assert_equal ["http://test.host/uploads/register.pdf"], rows.first[:training_register_urls]
      assert_equal ["http://test.host/uploads/photo.jpg"], rows.first[:training_photo_urls]
      assert_empty Array(rows.last[:training_photo_urls])
      assert_equal [2, 0], rows.map { |row| row[:attendance_count] }
      assert_equal [status, status], rows.map { |row| row[:status] }
    end
  end

  test "explicit training JJ supplies CC with one batched lookup" do
    vrp = Vrp.new(cluster_incharge: "Assigned CC", name: "List JJ", email: "list-jj@example.test",
      aadhar_no: "123456789012", account_no: "1234", address: "Test", branch: "Test",
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      experience_in_years: 1, father_husband_name: "Test", gender: :male,
      ifsc_code: "SBIN0001234", mobile_no: "9876543210", office_detail_id: 1, to_office_detail_id: 1)
    vrp.save!(validate: false)
    c = ModulesController.new
    c.request = ActionDispatch::TestRequest.create
    rows = [{ farmer_id: "11" }, { farmer_id: "12" }]
    records = rows.map { |row| ModuleRecord.new(id: row[:farmer_id].to_i, data: { "selected_farmer_ids" => [row[:farmer_id]], "vrp_id" => vrp.id.to_s }) }
    c.send(:enrich_training_participation_list_rows!, rows, records, [])
    assert_equal ["Assigned CC", "Assigned CC"], rows.map { |row| row[:cluster_incharge] }
  end

  test "search matches enriched CC and fields beyond the first page" do
    c = ModulesController.new
    c.instance_variable_set(:@training_participation_search, "coordinator twenty one")
    rows = 21.times.map { |index| { farmer_name: "Farmer #{index}", cluster_incharge: index == 20 ? "Coordinator Twenty One" : "Other CC" } }
    matches = rows.select { |row| c.send(:training_participation_search_match?, row.values) }
    assert_equal [rows.last], matches
  end

  test "upload links show accessible eye icon and missing uploads remain explicit" do
    html = ModulesController.render(partial: "modules/training_participation_uploads", locals: { urls: ["https://example.test/register.pdf"], label: "training register" })
    fragment = Nokogiri::HTML.fragment(html)
    assert_equal "https://example.test/register.pdf", fragment.at_css("a")[:href]
    assert_equal "View training register 1", fragment.at_css("a")["aria-label"]
    assert fragment.at_css("a svg")
    missing = ModulesController.render(partial: "modules/training_participation_uploads", locals: { urls: [], label: "training photo" })
    assert_includes missing, "Not uploaded"
  end
end

class TrainingParticipationListPageTest < ActionDispatch::IntegrationTest
  test "all four pages render search and upload columns and preserve filters" do
    user = User.create!(first_name: "List", last_name: "Admin", user_name: "participation_admin",
      email: "participation-admin@example.test", mobile_no: "9876500011", password: "secret",
      user_type: "admin", status: "Active")
    post login_path, params: { login: user.user_name, password: "secret" }
    %w[unique red yellow green].each do |status|
      get farmer_training_participation_path, params: { status: status, training_month: "August", training_fcoc: "1004", search: "missing-farmer-name" }
      assert_response :success
      assert_select 'form[method="get"] input[name="search"][value="missing-farmer-name"]'
      assert_select 'input[name="training_month"][value="August"]'
      assert_select "th", text: "ClusterCoordinator"
      assert_select "th", text: "Training Register Upload"
      assert_select "th", text: "Training Photo Upload with Geo Tag"
      assert_select 'a[href*="search=missing-farmer-name"][href*="xlsx"]'
    end
  end
end
