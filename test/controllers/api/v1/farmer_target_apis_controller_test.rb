require "test_helper"

class Api::V1::FarmerTargetApisControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_admin_user(user_name: "api_farmer_admin", password: "secret")
    @token = api_login_token(login: "api_farmer_admin", password: "secret")
  end

  test "farmer training list requires auth" do
    get "/api/v1/farmer-trainings", as: :json
    assert_response :unauthorized
  end

  test "farmer training form data requires auth" do
    get "/api/v1/farmer-trainings/form-data", as: :json

    assert_response :unauthorized
  end

  test "farmer training farmer list requires auth" do
    get "/api/v1/farmer-trainings/farmers", as: :json

    assert_response :unauthorized
  end

  test "farmer training months require auth" do
    get "/api/v1/farmer-trainings/months", as: :json

    assert_response :unauthorized
  end

  test "mapped farmer list requires auth" do
    get "/api/v1/farmer-trainings/mapped-farmers", as: :json

    assert_response :unauthorized
  end

  test "farmer training list and form options work" do
    ModuleRecord.create!(
      module_slug: "training-form",
      data: {
        "month" => "July",
        "ics_block" => "ICS-1",
        "gram_name" => "Village 1",
        "trainer_name" => "Trainer",
        "created_by_id" => @user.id.to_s
      }
    )

    get "/api/v1/farmer-trainings", headers: auth_headers, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal true, body["success"]
    assert body["farmer_trainings"].is_a?(Array)
    assert body["count"] >= 1

    get "/api/v1/farmer-trainings/form-options", headers: auth_headers, as: :json
    assert_response :success
    assert_equal true, response.parsed_body["success"]
    assert response.parsed_body["options"].key?("target_mappings")
    assert response.parsed_body["options"].key?("autofill")
  end

  test "training and other target form options include FCO CC and agronomist names" do
    cc = User.create!(first_name: "Sausar", last_name: "CC", user_name: "sausar_cc",
      email: "sausar-cc@example.test", mobile_no: "9876500111", password: "secret",
      stakeholder_role: "Cluster Coordinator", office_name: "FCO-C Sausar", status: "Active")
    agronomist = User.create!(first_name: "Sausar", last_name: "Agronomist", user_name: "sausar_agronomist",
      email: "sausar-agronomist@example.test", mobile_no: "9876500112", password: "secret",
      stakeholder_role: "Agronomist", office_name: "FCO-C Sausar", status: "Active")
    vrp = create_vrp(fcoc: "FCO-C Sausar")
    ModuleRecord.create!(module_slug: "add-activity-group", data: { main_activity_name: "Training", main_activity_type: "Training" })
    ModuleRecord.create!(module_slug: "add-activity-group", data: { main_activity_name: "Seed", main_activity_type: "Other" })
    TargetMapping.create!(vrp: vrp, fco_id: "1004", fco_name: "FCO-C Sausar", ics_id: "ICS-1", ics_name: "ICS One",
      village_id: "V-1", village_name: "Village One", month_name: "October", main_activity_name: "Training", activity_name: "Meeting")
    TargetMapping.create!(vrp: vrp, fco_id: "1004", fco_name: "FCO-C Sausar", ics_id: "ICS-1", ics_name: "ICS One",
      village_id: "V-1", village_name: "Village One", month_name: "October", main_activity_name: "Seed", activity_name: "Distribution")

    ["farmer-trainings", "other-targets"].each do |path|
      get "/api/v1/#{path}/form-options", headers: auth_headers
      assert_response :success
      options = response.parsed_body.fetch("options")
      assert_includes options.fetch("cc_names"), cc.full_name
      assert_includes options.fetch("agronomist_names"), agronomist.full_name
      fco_staff = options.fetch("staff_by_fco").find { |row| row["fco_name"] == "FCO-C Sausar" }
      assert_includes fco_staff.fetch("cc_names"), cc.full_name
      assert_includes fco_staff.fetch("agronomist_names"), agronomist.full_name
    end

    get "/api/v1/farmer-trainings/form-data", headers: auth_headers
    assert_response :success
    assert_includes response.parsed_body.dig("options", "cc_names"), cc.full_name
    assert_includes response.parsed_body.dig("options", "agronomist_names"), agronomist.full_name
  end

  test "JJ training options contain only that JJ mapped CC and agronomist" do
    agronomist = create_admin_user(first_name: "Assigned", last_name: "Agronomist", user_name: "assigned_agronomist",
      stakeholder_role: "Agronomist", office_name: "FCO-C Sausar")
    create_admin_user(first_name: "Unassigned", last_name: "Agronomist", user_name: "unassigned_agronomist",
      stakeholder_role: "Agronomist", office_name: "FCO-C Sausar")
    jj = create_vrp(name: "Scoped JJ", user_name: "scoped_jj", password: "secret", agreement_accepted_at: Time.current,
      fcoc: "FCO-C Sausar", cluster_incharge: "Assigned CC", created_by_id: agronomist.id)

    post "/api/v1/jeevika-jankar-login", params: { login: jj.user_name, password: "secret" }, as: :json
    assert_response :success
    headers = { "Authorization" => "Bearer #{response.parsed_body.fetch("token")}" }

    get "/api/v1/farmer-trainings/form-options", headers: headers, as: :json
    assert_response :success
    options = response.parsed_body.fetch("options")
    assert_equal ["N/A", "Assigned CC"], options.fetch("cc_names")
    assert_equal ["N/A", agronomist.full_name], options.fetch("agronomist_names")
    assert_equal ["FCO-C Sausar"], options.fetch("staff_by_fco").map { |row| row["fco_name"] }
  end

  test "seed distribution list and form options work" do
    ModuleRecord.create!(
      module_slug: "seed-distribution-target",
      data: {
        "month" => "July",
        "ics" => "ICS-1",
        "village" => "Village 1",
        "jeevika_jankar_name" => "JJ One",
        "created_by_id" => @user.id.to_s
      }
    )

    get "/api/v1/seed-distribution-targets", headers: auth_headers, as: :json
    assert_response :success
    assert_equal true, response.parsed_body["success"]
    assert response.parsed_body["seed_distribution_targets"].is_a?(Array)

    get "/api/v1/seed-distribution-targets/form-options", headers: auth_headers, as: :json
    assert_response :success
    assert response.parsed_body["options"].key?("target_mappings")
    assert response.parsed_body["options"].key?("autofill")
  end

  test "papl360 list and form options work" do
    ModuleRecord.create!(
      module_slug: "papl360-target",
      data: {
        "month" => "July",
        "ics" => "ICS-1",
        "village" => "Village 1",
        "jeevika_jankar_name" => "JJ One",
        "created_by_id" => @user.id.to_s
      }
    )

    get "/api/v1/papl360-targets", headers: auth_headers, as: :json
    assert_response :success
    assert_equal true, response.parsed_body["success"]
    assert response.parsed_body["papl360_targets"].is_a?(Array)

    get "/api/v1/papl360-targets/form-options", headers: auth_headers, as: :json
    assert_response :success
  end

  test "add farmer form list create and form options work" do
    vrp = create_vrp(user_name: "add_farmer_vrp", name: "Add Farmer VRP")
    mapping = TargetMapping.create!(
      vrp: vrp,
      fco_id: "FCO1",
      fco_name: "FCO One",
      ics_id: "ICS1",
      ics_name: "ICS One",
      village_id: "V1",
      village_name: "Village One",
      month_name: "July",
      main_activity_name: "New Farmer",
      activity_name: "Enrollment",
      target_quantity: 5,
      afl_ids: []
    )

    get "/api/v1/add-farmer-forms/form-options", headers: auth_headers, as: :json
    assert_response :success
    options = response.parsed_body["options"]
    assert options["mappings"].any? { |row| row["id"] == mapping.id.to_s }

    post "/api/v1/add-farmer-forms",
      params: {
        target_mapping_id: mapping.id.to_s,
        no_farmer: 3
      },
      headers: auth_headers,
      as: :json

    assert_response :created
    body = response.parsed_body
    assert_equal true, body["success"]
    assert_equal "3", body.dig("add_farmer_form", "data", "no_farmer")
    assert_equal mapping.id.to_s, body.dig("add_farmer_form", "data", "target_mapping_id")

    get "/api/v1/add-farmer-forms", headers: auth_headers, as: :json
    assert_response :success
    assert response.parsed_body["add_farmer_forms"].any?
  end

  test "web modules path still works after api addition" do
    ModuleRecord.create!(
      module_slug: "training-form",
      data: {
        "trainer_name" => "Lead Trainer",
        "internal_trainer_name_1" => "Internal Trainer One",
        "internal_trainer_name_2" => "Internal Trainer Two",
        "created_by_id" => @user.id.to_s
      }
    )

    post login_path, params: { login: "api_farmer_admin", password: "secret" }
    get "/modules/training-form-list"
    assert_response :success
    assert_includes response.body, "Cluster Coordinator Name"
    assert_includes response.body, "Agronomist Name"
    assert_includes response.body, "Internal Trainer One"
    assert_includes response.body, "Internal Trainer Two"
  end

  test "other targets authenticate, validate, create, list and show using mapped target" do
    get "/api/v1/other-targets", as: :json
    assert_response :unauthorized
    vrp = create_vrp
    ModuleRecord.create!(module_slug: "add-activity-group", data: { main_activity_name: "Seed", main_activity_type: "Other" })
    mapping = TargetMapping.create!(vrp: vrp, fco_id: "demo", ics_id: "1", village_id: "1", village_name: "Village", ics_name: "ICS",
      month_name: "September", main_activity_name: "Seed", activity_name: "Distribution", target_quantity: 5)
    get "/api/v1/other-targets/form-options", headers: auth_headers
    assert_response :success
    assert response.parsed_body.dig("options", "target_mappings").any? { |row| row["target_mapping_id"] == mapping.id.to_s }
    attrs = { jeevika_jankar_id: vrp.id, month: "September", ics: "ICS", village: "Village",
      main_activity: "Seed", sub_activity: "Distribution", achievement: "bad", target: 999, created_by_id: "forged" }
    post "/api/v1/other-targets", params: { other_target: attrs }, headers: auth_headers, as: :json
    assert_response :unprocessable_entity
    attrs[:achievement] = 6
    post "/api/v1/other-targets", params: { other_target: attrs }, headers: auth_headers, as: :json
    assert_response :unprocessable_entity
    attrs[:achievement] = 3
    post "/api/v1/other-targets", params: { other_target: attrs }, headers: auth_headers, as: :json
    assert_response :created
    record = response.parsed_body["other_target"]
    assert_equal "5", record.dig("data", "target")
    assert_equal @user.id.to_s, record.dig("data", "created_by_id")
    get "/api/v1/other-targets/#{record['id']}", headers: auth_headers
    assert_response :success
    get "/api/v1/other-targets", headers: auth_headers
    assert_response :success
    assert response.parsed_body["other_targets"].any? { |row| row["id"] == record["id"] }
  end

  test "demonstration JSON has separate numeric targets and achievements and monthly scope" do
    get "/api/v1/demonstration-methods/summary"
    assert_response :unauthorized
    vrp = create_vrp
    2.times do
      TargetMapping.create!(vrp: vrp, fco_id: "demo", fco_name: "Demo", ics_id: "1", village_id: "1",
        month_name: "September", main_activity_name: "Training", activity_name: "Demo", target_quantity: 0,
        opg_training_target: 8, week_wise_opg_target: 3, input_demo_inm_target: 2)
    end
    ModuleRecord.create!(module_slug: "training-form", data: { created_by_id: vrp.id.to_s, month: "September", training_method: "General Training/Meeting" })
    ModuleRecord.create!(module_slug: "training-form", data: { created_by_id: vrp.id.to_s, month: "August", training_method: "FFS" })
    get "/api/v1/demonstration-methods/summary", params: { month: "September", fco_id: "demo" }, headers: auth_headers
    assert_response :success
    assert_equal 8, response.parsed_body["opg_target"]
    assert_equal({ "target" => 5, "achievement" => 1 }, response.parsed_body["total"])
    get "/api/v1/demonstration-methods", params: { month: "September", vrp_id: vrp.id, per_page: 1 }, headers: auth_headers
    assert_response :success
    assert_equal 1, response.parsed_body["count"]
    assert_equal({ "target" => 3, "achievement" => 1 }, response.parsed_body.dig("records", 0, "methods", "general_training_meeting"))
    get "/api/v1/demonstration-methods", params: { month: "invalid" }, headers: auth_headers
    assert_response :unprocessable_entity
  end

  test "training API keeps manual male and female counts and sums total" do
    vrp = create_vrp
    farmer = Afl.create!(farmer_name: "Mapped farmer")
    ModuleRecord.create!(module_slug: "add-activity-group", data: { main_activity_name: "Training", main_activity_type: "Training" })
    TargetMapping.create!(vrp: vrp, fco_id: "demo", ics_id: "1", village_id: "1", village_name: "Village", ics_name: "ICS",
      month_name: "September", main_activity_name: "Training", activity_name: "Demo", target_quantity: 1, afl_ids: [farmer.id.to_s])
    attrs = { month: "September", ics_block: "ICS", gram_name: "Village", fco_name: "Demo",
      training_date: "2026-09-16", training_location: "Village", main_activity: "Training", sub_activity: "Demo",
      training_method: "General Training/Meeting", training_description: "Meeting", male_count: 2, female_count: 3,
      selected_farmer_ids: [farmer.id.to_s], next_farmer_training_date: "2026-09-20",
      training_register_upload: "/uploads/module_records/register.jpg", photo_front_view: "/uploads/module_records/front.jpg" }
    post "/api/v1/farmer-trainings", params: { farmer_training: attrs }, headers: auth_headers, as: :json
    assert_response :created
    data = response.parsed_body.dig("farmer_training", "data")
    assert_equal 2, data["male_count"]
    assert_equal 3, data["female_count"]
    assert_equal "5", data["total_farmer_count"]
    assert_equal "1", data["farmer_count"]
    get "/api/v1/farmer-trainings/form-options", headers: auth_headers
    assert_includes response.parsed_body.dig("options", "training_methods"), "General Training/Meeting"
  end

  test "JJ token cannot access other JJ target forms or demonstration rows" do
    own = create_vrp(name: "Own JJ")
    other = create_vrp(name: "Other JJ")
    ModuleRecord.create!(module_slug: "add-activity-group", data: { main_activity_name: "Seed", main_activity_type: "Other" })
    [own, other].each do |vrp|
      TargetMapping.create!(vrp: vrp, fco_id: "demo", ics_id: "1", village_id: "1", village_name: "Village", ics_name: "ICS",
        month_name: "September", main_activity_name: "Seed", activity_name: "Distribution", target_quantity: 5)
    end
    other_record = ModuleRecord.create!(module_slug: "other-target", data: { jeevika_jankar_id: other.id.to_s })
    headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(own)}" }
    get "/api/v1/other-targets/#{other_record.id}", headers: headers
    assert_response :not_found
    get "/api/v1/other-targets/form-options", headers: headers
    assert_equal [own.id.to_s], response.parsed_body.dig("options", "target_mappings").map { |row| row["vrp_id"] }.uniq
    get "/api/v1/demonstration-methods", params: { month: "September" }, headers: headers
    assert_response :success
    assert_equal [own.id], response.parsed_body["records"].map { |row| row["vrp_id"] }
    get "/api/v1/demonstration-methods/summary", params: { month: "September", vrp_id: other.id }, headers: headers
    assert_equal [], response.parsed_body["fcos"]
  end

  private

  def auth_headers
    { "Authorization" => "Bearer #{@token}" }
  end

  def api_login_token(login:, password:)
    post api_v1_login_path, params: { login: login, password: password }, as: :json
    assert_response :success
    response.parsed_body["token"]
  end

  def create_admin_user(attributes = {})
    defaults = {
      first_name: "Api",
      last_name: "Admin",
      email: "api_farmer_admin_#{SecureRandom.hex(3)}@example.com",
      mobile_no: "9#{SecureRandom.random_number(10**9).to_s.rjust(9, "0")}",
      password: "secret",
      user_type: "admin",
      status: "Active",
      stakeholder: "PAPL",
      role: "Admin"
    }
    User.create!(defaults.merge(attributes))
  end

  def create_vrp(attributes = {})
    defaults = {
      name: "Test JJ",
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
      email: "jj#{SecureRandom.hex(4)}@example.com",
      experience_in_years: 1,
      office_detail_id: 0,
      to_office_detail_id: 0,
      vrp_type_ids: [ 1 ],
      gram_panchayat_ids: [ 1 ],
      village_ids: [ 1 ],
      is_active: true,
      is_deleted: false,
      status: 55,
      password: "secret"
    }

    Vrp.create!(defaults.merge(attributes))
  end
end
