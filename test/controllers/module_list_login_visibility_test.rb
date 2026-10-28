require "test_helper"

# Training Form List / Other Target List / Bill List must only show what the
# signed-in login owns: an Agronomist sees the Jeevika Jankars they registered,
# a Cluster Incharge the ones mapped under them, an FCO-C everything filed under
# that FCO-C.
class ModuleListLoginVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @sausar_user = User.create!(first_name: "Gaurav", last_name: "Makar",
      user_name: "agro_sausar", email: "agro-sausar@example.test", mobile_no: "9876500701",
      password: "secret", user_type: "User", status: "Active",
      role: "agricultural specialist", stakeholder_role: "Agronomist",
      office_category: "FCO-C Sausar", office_name: "FCO-C Sausar", sub_office_name: "TO-Hinganghat")

    @other_user = User.create!(first_name: "Other", last_name: "Agro",
      user_name: "agro_turekela", email: "agro-turekela@example.test", mobile_no: "9876500702",
      password: "secret", user_type: "User", status: "Active",
      role: "agricultural specialist", stakeholder_role: "Agronomist",
      office_category: "FCO-C Turekela", office_name: "FCO-C Turekela", sub_office_name: "TO-Turekela")

    # Access Control is what opens the screen for a non-admin role.
    ModuleRecord.create!(module_slug: "access-control", data: {
      "stakeholder_role" => "Agronomist", "role" => "agricultural specialist",
      "sub_module_names" => ["Training Form List"], "can_view" => "Yes"
    })

    @mine = create_jj("Sausar JJ", "FCO-C Sausar", "TO-Hinganghat", @sausar_user)
    @theirs = create_jj("Turekela JJ", "FCO-C Turekela", "TO-Turekela", @other_user)

    training_record(@mine, "Sausar Village", "FCO-C Sausar")
    training_record(@theirs, "Turekela Village", "FCO-C Turekela")
  end

  test "an Agronomist does not see another FCO-C's training records" do
    post login_path, params: { login: @sausar_user.user_name, password: "secret" }

    get module_path("training-form-list")
    assert_response :success

    assert_includes response.body, "Sausar Village", "own record has to stay visible"
    refute_includes response.body, "Turekela Village",
      "a Sausar Agronomist must not see a Turekela training record"
  end

  # created_by_id is just a number: User 7 and Jeevika Jankar 7 are different
  # people. Matching on the number alone handed every record a Jeevika Jankar
  # saved to whichever user happens to share that id -- in another FCO-C.
  test "a record created by a Jeevika Jankar with the same id stays hidden" do
    ModuleRecord.create!(module_slug: "training-form", data: {
      "vrp_id" => @theirs.id.to_s, "village" => "Collision Village",
      "fco_name" => "FCO-C Turekela", "month" => "October",
      "main_activity" => "Farmers' Training", "sub_activity" => "Soil",
      "created_by_id" => @sausar_user.id.to_s, "created_by_record_type" => "Vrp"
    })

    post login_path, params: { login: @sausar_user.user_name, password: "secret" }
    get module_path("training-form-list")
    assert_response :success

    refute_includes response.body, "Collision Village",
      "a Jeevika Jankar's record must not surface just because the ids collide"
  end

  test "the signed-in user still sees what they created themselves" do
    ModuleRecord.create!(module_slug: "training-form", data: {
      "vrp_id" => @mine.id.to_s, "village" => "My Own Village",
      "fco_name" => "FCO-C Sausar", "month" => "October",
      "main_activity" => "Farmers' Training", "sub_activity" => "Soil",
      "created_by_id" => @sausar_user.id.to_s, "created_by_record_type" => "User"
    })

    post login_path, params: { login: @sausar_user.user_name, password: "secret" }
    get module_path("training-form-list")
    assert_response :success
    assert_includes response.body, "My Own Village"
  end

  test "an admin still sees every training record" do
    admin = User.create!(first_name: "Visibility", last_name: "Admin", user_name: "visibility_admin",
      email: "visibility-admin@example.test", mobile_no: "9876500703", password: "secret",
      user_type: "admin", status: "Active")
    post login_path, params: { login: admin.user_name, password: "secret" }

    get module_path("training-form-list")
    assert_response :success
    assert_includes response.body, "Sausar Village"
    assert_includes response.body, "Turekela Village"
  end

  private

  def create_jj(name, fcoc, to_name, creator)
    Vrp.create!(name: name, father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "1234567890#{rand(10..99)}", account_no: "1234567890", bank_name: "Bank",
      branch: "Branch", ifsc_code: "TEST0123456", address: "Address", mobile_no: "98765432#{rand(10..99)}",
      email: "jj_#{SecureRandom.hex(4)}@example.com", experience_in_years: 1,
      office_detail_id: 0, to_office_detail_id: 0, vrp_type_ids: [1], gram_panchayat_ids: [1],
      village_ids: [1], user_name: "jj_#{SecureRandom.hex(4)}", password: "secret",
      fcoc: fcoc, to_name: to_name, created_by_id: creator.id, created_by_type: "User")
  end

  def training_record(vrp, village, fcoc)
    ModuleRecord.create!(module_slug: "training-form", data: {
      "vrp_id" => vrp.id.to_s, "village" => village, "village_name" => village,
      "fco_name" => fcoc, "month" => "October", "main_activity" => "Farmers' Training",
      "sub_activity" => "Soil", "training_date" => "2026-10-15",
      "created_by_id" => vrp.created_by_id.to_s, "created_by_record_type" => "User"
    })
  end
end
