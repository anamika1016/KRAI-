require "test_helper"

# A Jeevika Jankar must stay visible to the person who registered it and to the
# cluster coordinator it is mapped to. These are two independent reasons to see
# a JJ, and holding one must never hide the other.
class VrpRegisteredAndClusterVisibilityTest < ActiveSupport::TestCase
  setup do
    @registrar = User.create!(first_name: "Raghuvir", last_name: "Prajapat", user_name: "raghuvir_p",
      email: "raghuvir@example.test", mobile_no: "9876500301", password: "secret",
      user_type: "user", status: "Active")
    @coordinator = User.create!(first_name: "Rathva", last_name: "Dharmendra Sinh", user_name: "rathva_d",
      email: "rathva@example.test", mobile_no: "9876500302", password: "secret",
      user_type: "user", status: "Active")

    # Registered by Raghuvir, mapped to Rathva's cluster.
    @registered_jj = build_vrp("Registered JJ", "registered-jj@example.test")
    @registered_jj.created_by_id = @registrar.id
    @registered_jj.created_by_type = "User"
    @registered_jj.cluster_incharge = "Rathva Dharmendra Sinh"
    @registered_jj.save!(validate: false)

    # Mapped to Raghuvir's own cluster, registered by somebody else.
    @cluster_jj = build_vrp("Cluster JJ", "cluster-jj@example.test")
    @cluster_jj.created_by_id = @coordinator.id
    @cluster_jj.created_by_type = "User"
    @cluster_jj.cluster_incharge = "Raghuvir Prajapat"
    @cluster_jj.save!(validate: false)
  end

  test "a registrar who is also a cluster coordinator keeps seeing the JJs they registered" do
    names = visible_names_for(@registrar)

    assert_includes names, "Cluster JJ", "cluster-mapped JJ should be visible"
    assert_includes names, "Registered JJ", "JJ they registered must not disappear"
  end

  test "a cluster coordinator sees the JJs mapped to them" do
    assert_includes visible_names_for(@coordinator), "Registered JJ"
  end

  test "the dashboard shows a cluster coordinator both their cluster and their registrations" do
    names = dashboard_names_for(@registrar, role: "Cluster Incharge")

    assert_includes names, "Cluster JJ", "cluster-mapped JJ should reach the dashboard"
    assert_includes names, "Registered JJ", "JJ they registered must reach the dashboard too"
  end

  test "an unrelated user sees neither" do
    stranger = User.create!(first_name: "Un", last_name: "Related", user_name: "unrelated_u",
      email: "unrelated@example.test", mobile_no: "9876500303", password: "secret",
      user_type: "user", status: "Active")

    assert_empty visible_names_for(stranger)
  end

  private

  def build_vrp(name, email)
    Vrp.new(name: name, father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: "9876543#{rand(100..999)}", email: email, fcoc: "Sausar",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
  end

  def app_user_payload(user, role: nil)
    {
      "id" => user.id, "username" => user.user_name, "user_name" => user.user_name,
      "name" => user.full_name, "email" => user.email,
      "user_type" => "user", "record_type" => "User", "role" => role
    }.compact
  end

  def visible_names_for(user)
    controller = VrpsController.new
    controller.params = ActionController::Parameters.new
    payload = app_user_payload(user)
    controller.define_singleton_method(:current_app_user) { payload }
    controller.send(:visible_vrps).map(&:name)
  end

  def dashboard_names_for(user, role: nil)
    controller = ModulesController.new
    controller.params = ActionController::Parameters.new
    payload = app_user_payload(user, role: role)
    controller.define_singleton_method(:current_app_user) { payload }
    controller.send(:dashboard_vrps).map(&:name)
  end
end
