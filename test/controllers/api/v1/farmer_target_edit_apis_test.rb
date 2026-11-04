require "test_helper"

# Edit APIs for the two app screens:
#   PATCH /api/v1/farmer-trainings/:id   (Training Form List)
#   PATCH /api/v1/other-targets/:id      (Other Target List)
#
# Both routes were already declared but neither controller had an #update, so
# a PATCH raised instead of saving. The web edit screens are untouched.
#
# The important rule these cover: the web does NOT let a Cluster Incharge write
# a training form straight back -- the change becomes a TrainingEditApproval
# revision an Agronomist approves. Saving directly from the API would be a way
# around that approval, so the API has to behave the same way.
class Api::V1::FarmerTargetEditApisTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_user(user_type: "admin", role: "Admin", user_name: "edit_api_admin")
    @token = login_token("edit_api_admin")
    @vrp = create_vrp
    ModuleRecord.create!(module_slug: "add-activity-group",
      data: { main_activity_name: "Training", main_activity_type: "Training" })
    ModuleRecord.create!(module_slug: "add-activity-group",
      data: { main_activity_name: "Seed", main_activity_type: "Other" })
    @farmer = Afl.create!(farmer_name: "Mapped farmer")
    TargetMapping.create!(vrp: @vrp, fco_id: "demo", ics_id: "1", village_id: "1",
      village_name: "Village", ics_name: "ICS", month_name: "September",
      main_activity_name: "Training", activity_name: "Demo", target_quantity: 1,
      afl_ids: [@farmer.id.to_s])
    TargetMapping.create!(vrp: @vrp, fco_id: "demo", ics_id: "1", village_id: "1",
      village_name: "Village", ics_name: "ICS", month_name: "September",
      main_activity_name: "Seed", activity_name: "Distribution", target_quantity: 5)
  end

  # ---------------- Other Target List ----------------

  test "other target edit requires auth" do
    patch "/api/v1/other-targets/#{create_other_target['id']}",
      params: { other_target: { village: "Changed" } }, as: :json
    assert_response :unauthorized
  end

  test "other target edit saves the changed field and keeps the rest" do
    record = create_other_target

    patch "/api/v1/other-targets/#{record['id']}",
      params: { other_target: { achievement: 4 } }, headers: auth, as: :json
    assert_response :success

    body = response.parsed_body
    assert body["success"]
    refute body["pending_approval"], "an Other Target edit is saved straight away"

    data = ModuleRecord.find(record["id"]).data
    assert_equal "4", data["achievement"].to_s, "the edited field is saved"
    assert_equal "Village", data["village"], "a field that was not sent keeps its saved value"
    assert_equal "September", data["month"]
  end

  test "other target edit rejects an achievement above the target" do
    record = create_other_target

    patch "/api/v1/other-targets/#{record['id']}",
      params: { other_target: { achievement: 99 } }, headers: auth, as: :json
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"].join(" "), "Achievement"

    assert_equal "3", ModuleRecord.find(record["id"]).data["achievement"].to_s,
      "a rejected edit must not change the saved record"
  end

  test "other target edit returns 404 for an unknown id" do
    patch "/api/v1/other-targets/999999999",
      params: { other_target: { village: "Changed" } }, headers: auth, as: :json
    assert_response :not_found
    refute response.parsed_body["success"]
  end

  test "other target edit cannot touch a record the login may not see" do
    other_vrp = create_vrp(name: "Someone Else", aadhar_no: "123456780099",
      mobile_no: "9876540099", email: "other-edit@example.test", user_name: "other_edit_jj")
    hidden = ModuleRecord.create!(module_slug: "other-target",
      data: { "jeevika_jankar_id" => other_vrp.id.to_s, "village" => "Hidden" })
    jj_token = jj_login_token(other_vrp)

    second = create_vrp(name: "Second JJ", aadhar_no: "123456780098",
      mobile_no: "9876540098", email: "second-edit@example.test", user_name: "second_edit_jj")
    mine = ModuleRecord.create!(module_slug: "other-target",
      data: { "jeevika_jankar_id" => second.id.to_s, "village" => "Mine" })

    patch "/api/v1/other-targets/#{mine.id}",
      params: { other_target: { village: "Hacked" } },
      headers: { "Authorization" => "Bearer #{jj_token}" }, as: :json
    assert_response :not_found
    assert_equal "Mine", mine.reload.data["village"]
    assert_equal "Hidden", hidden.reload.data["village"]
  end

  # ---------------- Training Form List ----------------

  test "training form edit requires auth" do
    patch "/api/v1/farmer-trainings/#{create_training['id']}",
      params: { farmer_training: { training_location: "Changed" } }, as: :json
    assert_response :unauthorized
  end

  test "admin training form edit saves straight away and keeps unsent fields" do
    record = create_training

    patch "/api/v1/farmer-trainings/#{record['id']}",
      params: { farmer_training: { training_location: "New Hall", male_count: 7 } },
      headers: auth, as: :json
    assert_response :success

    body = response.parsed_body
    assert body["success"]
    refute body["pending_approval"], "an admin writes the training form directly"

    data = ModuleRecord.find(record["id"]).data
    assert_equal "New Hall", data["training_location"]
    assert_equal 7, data["male_count"]
    assert_equal "September", data["month"], "unsent fields keep their saved value"
    assert_equal "Demo", data["sub_activity"]
  end

  test "a Cluster Incharge training edit is queued for approval, not written" do
    record = create_training
    cc = create_user(user_type: "User", role: "Cluster Incharge", user_name: "edit_api_cc")
    @vrp.update_column(:cluster_incharge, cc.full_name)
    agronomist_for_training_routing

    before = ModuleRecord.find(record["id"]).data["training_location"]

    patch "/api/v1/farmer-trainings/#{record['id']}",
      params: { farmer_training: { training_location: "CC Edited Hall" } },
      headers: { "Authorization" => "Bearer #{login_token('edit_api_cc')}" }, as: :json
    assert_response :success

    body = response.parsed_body
    assert body["success"]
    assert body["pending_approval"],
      "a Cluster Incharge edit must be reported as pending approval, not as saved"
    assert_includes body["message"], "approval"

    assert_equal before, ModuleRecord.find(record["id"]).data["training_location"],
      "the training form itself must not change until the edit is approved"
    assert ModuleRecord.where(module_slug: TrainingEditApproval::SLUG).exists?,
      "a revision is recorded for the approver"
  end

  test "a training edit adds evidence instead of replacing what is saved" do
    record = create_training

    patch "/api/v1/farmer-trainings/#{record['id']}",
      params: { farmer_training: { photo_front_view: "/uploads/module_records/second.jpg" } },
      headers: auth, as: :json
    assert_response :success

    photos = Array(ModuleRecord.find(record["id"]).data["photo_front_view"])
    assert_includes photos, "/uploads/module_records/front.jpg", "the original photo is kept"
    assert_includes photos, "/uploads/module_records/second.jpg", "the new photo is added"
  end

  test "training form edit rejects a change that breaks validation" do
    record = create_training

    patch "/api/v1/farmer-trainings/#{record['id']}",
      params: { farmer_training: { training_location: "" } }, headers: auth, as: :json
    assert_response :unprocessable_entity

    assert_equal "Village", ModuleRecord.find(record["id"]).data["training_location"],
      "a rejected edit must not change the saved record"
  end

  test "training form edit returns 404 for an unknown id" do
    patch "/api/v1/farmer-trainings/999999999",
      params: { farmer_training: { training_location: "Changed" } }, headers: auth, as: :json
    assert_response :not_found
  end

  private

  def auth = { "Authorization" => "Bearer #{@token}" }

  def create_training
    attrs = { month: "September", ics_block: "ICS", gram_name: "Village", fco_name: "Demo",
      training_date: "2026-09-16", training_location: "Village", main_activity: "Training",
      sub_activity: "Demo", training_method: "General Training/Meeting",
      training_description: "Meeting", male_count: 2, female_count: 3,
      selected_farmer_ids: [@farmer.id.to_s], next_farmer_training_date: "2026-09-20",
      training_register_upload: "/uploads/module_records/register.jpg",
      photo_front_view: "/uploads/module_records/front.jpg" }
    post "/api/v1/farmer-trainings", params: { farmer_training: attrs }, headers: auth, as: :json
    assert_response :created
    response.parsed_body.fetch("farmer_training")
  end

  def create_other_target
    attrs = { jeevika_jankar_id: @vrp.id, month: "September", ics: "ICS", village: "Village",
      main_activity: "Seed", sub_activity: "Distribution", target: 5, achievement: 3 }
    post "/api/v1/other-targets", params: { other_target: attrs }, headers: auth, as: :json
    assert_response :created
    response.parsed_body.fetch("other_target")
  end

  # TrainingEditApproval refuses to queue a revision unless the training's FCO
  # office has exactly one active Agronomist to route it to.
  def agronomist_for_training_routing
    create_user(user_type: "User", role: "Agronomist", user_name: "edit_api_agro",
      office_name: "Demo")
  end

  def create_user(attributes = {})
    suffix = SecureRandom.hex(3)
    defaults = {
      first_name: "Edit", last_name: "Api",
      email: "edit-api-#{suffix}@example.test",
      mobile_no: "9#{SecureRandom.random_number(10**9).to_s.rjust(9, '0')}",
      password: "secret", status: "Active", stakeholder: "PAPL"
    }
    User.create!(defaults.merge(attributes.reverse_merge(user_name: "edit_api_#{suffix}")))
  end

  def create_vrp(attributes = {})
    defaults = {
      name: "Edit Api JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456780097", account_no: "1234", bank_name: "Bank", branch: "Branch",
      ifsc_code: "TEST0123456", address: "Address", mobile_no: "9876540097",
      email: "edit-api-jj@example.test", experience_in_years: 1,
      office_detail_id: 0, to_office_detail_id: 0, user_name: "edit_api_jj",
      password: "secret", fcoc: "Demo", status: 55, is_active: true,
      agreement_accepted_at: Time.current
    }
    vrp = Vrp.new(defaults.merge(attributes))
    vrp.save!(validate: false)
    vrp
  end

  def login_token(user_name)
    post api_v1_login_path, params: { login: user_name, password: "secret" }, as: :json
    assert_response :success
    response.parsed_body.fetch("token")
  end

  def jj_login_token(vrp)
    post api_v1_login_path, params: { login: vrp.user_name, password: "secret" }, as: :json
    assert_response :success
    response.parsed_body.fetch("token")
  end
end
