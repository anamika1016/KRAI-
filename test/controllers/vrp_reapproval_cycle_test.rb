require "test_helper"

class VrpReapprovalCycleTest < ActiveSupport::TestCase
  test "resubmission reopens previously approved and rejected steps in web and API" do
    [VrpsController.new, Api::V1::JeevikaJankarsController.new].each do |controller|
      history = [
        history_record("Sent for Approval"),
        history_record("Approved"),
        history_record("Rejected"),
        history_record("Sent for Approval")
      ]
      controller.define_singleton_method(:approval_history_for) { |_vrp| history }
      vrp = Vrp.new(status: 25)

      assert controller.send(:approval_sent?, vrp)
      assert_not controller.send(:approval_rejected?, vrp)
      assert_empty controller.send(:approved_approval_sequences, vrp)
      assert_equal 4, controller.send(:approval_history_for, vrp).size

      history << history_record("Rejected")
      assert controller.send(:approval_rejected?, vrp)
    end
  end

  test "web edit restarts rejected registration but preserves final approval" do
    [99, 55].each do |status|
      vrp = Vrp.new(name: "Before edit", status: status, aadhar_no: "123456789012",
        account_no: "1234567890", address: "Address", branch: "Branch", date_of_birth: Date.new(1990, 1, 1),
        date_of_joining: Date.current, email: "cycle#{status}@example.test", experience_in_years: 1,
        father_husband_name: "Father", gender: :male, ifsc_code: "TEST0123456", mobile_no: "9876543210",
        office_detail_id: 0, to_office_detail_id: 0)
      vrp.save!(validate: false)
      if status == 99
        ModuleRecord.create!(module_slug: "vrp-approval-history", data: {
          "vrp_id" => vrp.id, "action" => "Rejected", "approval_level" => "First Approval",
          "remarks" => "Please correct the village"
        })
      end
      vrp.define_singleton_method(:update) do |attributes|
        assign_attributes(attributes)
        save!(validate: false)
      end
      controller = VrpsController.new
      controller.instance_variable_set(:@vrp, vrp)
      controller.define_singleton_method(:vrp_password_confirmed?) { |_| true }
      controller.define_singleton_method(:vrp_update_params) { { name: "After edit" } }
      controller.define_singleton_method(:approval_steps_for) { |_| [] }
      controller.define_singleton_method(:current_app_user) { nil }
      controller.define_singleton_method(:redirect_to) { |*| }
      controller.define_singleton_method(:vrps_path) { "/vrps" }
      controller.update

      assert_equal "After edit", vrp.reload.name
      assert_equal(status == 99 ? 25 : 55, vrp.status)
      assert_equal(status == 99, controller.send(:approval_sent?, vrp))
      assert_not controller.send(:approval_rejected?, vrp)
      if status == 99
        assert_equal "Please correct the village", controller.send(:approval_history_for, vrp).first.data["remarks"]
      end
    end
  end

  test "edit retains location IDs omitted when equal labels were deduplicated" do
    saved = ModuleRecord.create!(module_slug: "village-master", data: {
      "gram_panchayat_name" => "Saved Panchayat", "village_name" => "Saved Village"
    })
    vrp = Vrp.new(gram_panchayat_ids: [saved.id.to_s], village_ids: [saved.id.to_s])
    controller = VrpsController.new
    controller.instance_variable_set(:@vrp, vrp)
    controller.instance_variable_set(:@gram_panchayat_options, [["Saved Panchayat", "other-id"]])
    controller.instance_variable_set(:@village_options, [])
    controller.send(:keep_saved_location_options!)

    assert_includes controller.instance_variable_get(:@gram_panchayat_options), ["Saved Panchayat", saved.id.to_s]
    assert_includes controller.instance_variable_get(:@village_options), ["Saved Village", saved.id.to_s]
  end

  private

  def history_record(action)
    ModuleRecord.new(data: { "action" => action, "approval_level" => "First Approval", "remarks" => "Correction needed" })
  end
end
