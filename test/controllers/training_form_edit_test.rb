require "test_helper"

class TrainingFormEditTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(first_name: "Training", last_name: "Admin", user_name: "training_edit_admin",
      email: "training-edit-admin@example.test", mobile_no: "9876500022", password: "secret",
      user_type: "admin", status: "Active")
    post login_path, params: { login: user.user_name, password: "secret" }
    @record = ModuleRecord.create!(module_slug: "training-form", data: {
      "month" => "September", "ics" => "Saved ICS", "village" => "Saved Village",
      "main_activities" => ["Saved Activity"], "sub_activities" => ["Saved Topic"],
      "selected_farmer_ids" => ["999999999"], "selected_farmer_names" => ["Saved Farmer"],
      "male_count" => "3", "female_count" => "4", "farmer_count" => "1",
      "photo_close-up_view" => ["https://example.test/photo.jpg"],
      "training_register_upload" => ["https://example.test/document.pdf"]
    })
  end

  test "edit renders saved selections and evidence without current mappings" do
    get edit_module_record_path("training-form", @record)
    assert_response :success
    assert_select '[data-training-target-ics][data-selected-value="Saved ICS"]'
    assert_select '[data-training-target-village][data-selected-value="Saved Village"]'
    assert_select '[data-training-farmer-panel]' do |panels|
      assert_equal "Saved Farmer", JSON.parse(panels.first['data-saved-farmers']).first['farmer_name']
    end
    assert_select 'img[src="https://example.test/photo.jpg"]'
    assert_select 'a[href="https://example.test/document.pdf"]'
    assert_select 'input[name="module_record[total_farmer_count]"][value="7"]'
  end

  test "grouped training row exposes every record for admin deletion" do
    duplicate = ModuleRecord.create!(module_slug: @record.module_slug, data: @record.data)
    get module_path("training-form-list")
    assert_response :success
    assert_select '[data-module-row-paths]' do |rows|
      paths = rows.flat_map { |row| JSON.parse(row['data-module-row-paths']) }
      [@record, duplicate].each do |record|
        assert_includes paths, edit_module_record_path("training-form", record)
        assert_difference('ModuleRecord.count', -1) do
          delete module_record_path("training-form", record)
        end
        assert_response :see_other
      end
    end
  end

  test "admin JSON deletion succeeds without redirect" do
    assert_difference('ModuleRecord.count', -1) do
      delete module_record_path("training-form", @record), headers: { "Accept" => "application/json" }
    end
    assert_response :no_content
  end

  test "selected farmer view has no edit action" do
    get selected_farmers_module_record_path("training-form-list", @record)
    assert_response :success
    assert_select 'a', text: "Edit Record", count: 0
  end
end
