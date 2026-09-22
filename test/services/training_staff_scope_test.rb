require "test_helper"

class TrainingStaffScopeTest < ActiveSupport::TestCase
  test "CC and agronomist options stay within their FCO and normalize duplicate names" do
    [
      ["cc_a", "Ashvin  Durve", "Cluster Coordinator", "FCO-C Sausar", "Active"],
      ["cc_b", "Other CC", "Cluster Coordinator", "FCO-C Turekela", "Active"],
      ["ag_a", "Local Agronomist", "Agronomist", "FCO-C Sausar", "Active"],
      ["ag_b", "Other Agronomist", "Agronomist", "FCO-C Turekela", "Active"],
      ["cc_inactive", "Inactive CC", "Cluster Coordinator", "FCO-C Sausar", "Inactive"]
    ].each do |login, name, role, office, status|
      User.create!(user_name: login, first_name: name, stakeholder_role: role,
        office_name: office, status: status, password: "secret")
    end
    ModuleRecord.create!(module_slug: "new-user", data: { "first_name" => "Ashvin Durve",
      "stakeholder_role" => "Cluster Coordinator", "office_name" => "FCO-C Sausar" })
    assert_equal ["N/A", "Ashvin Durve"], TrainingStaffScope.options("Sausar", :cluster_coordinator)
    assert_equal ["N/A", "Local Agronomist"], TrainingStaffScope.options("FCO-C Sausar", :agronomist)
    assert_equal ["N/A", "Other CC"], TrainingStaffScope.options("FCO-C Turekela", :cluster_coordinator)
  end
end
