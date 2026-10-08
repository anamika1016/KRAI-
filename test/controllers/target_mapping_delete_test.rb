require "test_helper"

class TargetMappingDeleteTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(first_name: "Mapping", last_name: "Admin", user_name: "mapping_delete_admin",
      email: "mapping-delete@example.test", mobile_no: "9876500511", password: "secret",
      user_type: "admin", status: "Active")
    post login_path, params: { login: user.user_name, password: "secret" }
    @vrp = Vrp.new(name: "Delete Mapping JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: "9876543210", email: "mapping-delete-jj@example.test",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    @vrp.save!(validate: false)
  end

  test "one delete removes all activities in the displayed group and preserves other groups" do
    targets = %w[Soil Water Seed].map { |activity| mapping(activity: activity, group: "delete-group") }
    other = mapping(activity: "Soil", group: "other-group")

    get target_mappings_path
    assert_response :success
    assert_select "form[action=?][data-turbo-confirm]", target_mapping_path(targets.last)

    assert_difference "TargetMapping.count", -3 do
      delete target_mapping_path(targets.first)
    end
    assert_response :see_other
    assert_redirected_to target_mappings_path
    assert TargetMapping.exists?(other.id)
    targets.each { |target| refute TargetMapping.exists?(target.id) }
  end

  test "one delete removes legacy duplicate mappings grouped into the same row" do
    first = mapping(activity: "Soil")
    mapping(activity: "Soil")
    other = mapping(activity: "Water")

    assert_difference "TargetMapping.count", -2 do
      delete target_mapping_path(first)
    end
    assert_response :see_other
    assert TargetMapping.exists?(other.id)
  end

  test "single mapping delete preserves unrelated activities" do
    target = mapping(activity: "Soil")
    other = mapping(activity: "Water")

    assert_difference "TargetMapping.count", -1 do
      delete target_mapping_path(target)
    end
    assert_response :see_other
    assert TargetMapping.exists?(other.id)
  end

  private

  def mapping(activity:, group: nil)
    TargetMapping.create!(vrp: @vrp, fco_id: "FCO-1", ics_id: "ICS-1", village_id: "Village-1",
      month_name: "October", main_activity_name: "Farmers' Training", activity_name: activity,
      target_quantity: 8, mapping_group_key: group)
  end
end
