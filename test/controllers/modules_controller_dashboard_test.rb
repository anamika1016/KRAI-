require "test_helper"

class ModulesControllerDashboardTest < ActiveSupport::TestCase
  Target = Struct.new(
    :id,
    :vrp_id, :fco_name, :fco_id, :ics_name, :ics_id, :village_name,
    :village_id, :month_name, :completion_date, :opg_training_target,
    :week_wise_opg_target, :input_demo_inm_target, :input_demo_pm_target,
    :ffs_target, :afl_ids, :main_activity_name, :activity_name,
    keyword_init: true
  )

  test "target record count combines activity rows belonging to one assignment" do
    assignment = {
      vrp_id: 7,
      fco_name: "Sausar",
      ics_name: "ICS 1",
      village_name: "Village 1",
      month_name: "August",
      completion_date: Date.new(2026, 8, 31),
      afl_ids: %w[11 12]
    }
    targets = [
      Target.new(**assignment, main_activity_name: "Training", activity_name: "Activity A"),
      Target.new(**assignment, main_activity_name: "Training", activity_name: "Activity B"),
      Target.new(**assignment.merge(month_name: "September"), main_activity_name: "Training", activity_name: "Activity A")
    ]

    assert_equal 2, ModulesController.new.send(:dashboard_target_record_count, targets)
  end

  test "target record count includes all assignments dynamically" do
    targets = 101.times.map do |index|
      Target.new(
        vrp_id: index + 1,
        fco_name: "Sausar",
        ics_name: "ICS 1",
        village_name: "Village #{index + 1}",
        month_name: "August",
        completion_date: Date.new(2026, 8, 31),
        afl_ids: [index + 1]
      )
    end

    assert_equal 101, ModulesController.new.send(:dashboard_target_record_count, targets)
  end

  test "training activity matcher handles numbered and combined saved labels" do
    controller = ModulesController.new

    assert controller.send(
      :dashboard_training_activity_text_matches?,
      "1. Village level farmers groups",
      "Village level farmers groups"
    )
    assert controller.send(
      :dashboard_training_activity_text_matches?,
      "1. Village level farmers groups, 2. Organic Nutrient Management (Module-4)",
      "Village level farmers groups"
    )
    assert controller.send(
      :dashboard_training_activity_text_matches?,
      "Organic Nutrient Management",
      "5. Organic Nutrient Management (Module-4)"
    )
  end

  test "jeevika bill item totals use billable target base dynamically" do
    totals = ModulesController.new.send(:jeevika_jankar_bill_item_totals, [
      {
        "main_activity_type" => "Training",
        "target_quantity" => "209",
        "assigned_count" => "208",
        "achievement_count" => "208"
      },
      {
        "main_activity_type" => "Other",
        "target_quantity" => "12",
        "assigned_count" => "0",
        "achievement_count" => "15"
      }
    ])

    assert_equal 220, totals[:target]
    assert_equal 220, totals[:achievement]
  end

  test "training form mapping id can complete another row in the same assignment" do
    controller = ModulesController.new
    assignment = {
      vrp_id: 7,
      fco_name: "Sausar",
      ics_name: "ICS 1",
      village_name: "Village 1",
      month_name: "August",
      completion_date: Date.new(2026, 8, 31),
      afl_ids: %w[11 12],
      opg_training_target: 0,
      week_wise_opg_target: 0,
      input_demo_inm_target: 0,
      input_demo_pm_target: 0,
      ffs_target: 0
    }
    saved_mapping = Target.new(**assignment, id: 101, main_activity_name: "Farmers WhatsApp Groups", activity_name: "Village level farmers groups")
    dashboard_target = Target.new(**assignment, id: 102, main_activity_name: "Farmers WhatsApp Groups", activity_name: "Organic Nutrient Management")
    record = Struct.new(:data).new("target_mapping_id" => saved_mapping.id.to_s)
    controller.define_singleton_method(:training_target_mapping_for_dashboard) { |_mapping_id| saved_mapping }

    assert controller.send(:training_record_target_assignment_matches?, record, dashboard_target)
  end

  test "training form optional people and external input fields are not required" do
    controller = ModulesController.new
    data = {
      "month" => "August",
      "ics_block" => "ICS 1",
      "gram_name" => "Village 1",
      "fco_name" => "FCO",
      "trainer_name" => "Trainer",
      "trainer_contact" => "9876543210",
      "training_date" => "2026-08-31",
      "training_location" => "Village 1",
      "main_activity" => "Farmers WhatsApp Groups",
      "sub_activity" => "Village level farmers groups",
      "training_method" => "General Training/Meeting",
      "training_description" => "Completed",
      "male_count" => "1",
      "female_count" => "1",
      "farmer_count" => "2",
      "total_farmer_count" => "2",
      "selected_farmer_ids" => %w[11 12],
      "next_farmer_training_date" => "2026-09-07",
      "training_register_upload" => "register.pdf",
      "training_photo_upload_with_geo_tag" => "photo.jpg"
    }

    messages = controller.send(:training_form_error_messages, data)

    refute messages.any? { |message| message.include?("Cluster Coordinator Name") }
    refute messages.any? { |message| message.include?("Agronomist Name") }
    refute messages.any? { |message| message.include?("PAPL Staff Name") }
    refute messages.any? { |message| message.include?("External Input") }
  end

  test "cluster visible vrps only includes explicitly mapped cluster incharge vrps" do
    mapped_vrp = create_vrp(
      name: "Mapped Cluster JJ",
      user_name: "mapped_cluster_jj",
      mobile_no: "9876500001",
      email: "mapped-cluster-jj@example.com",
      aadhar_no: "123456780001",
      cluster_incharge: "Ashvin Durve"
    )
    hierarchy_only_vrp = create_vrp(
      name: "Hierarchy Only JJ",
      user_name: "hierarchy_only_jj",
      mobile_no: "9876500002",
      email: "hierarchy-only-jj@example.com",
      aadhar_no: "123456780002",
      cluster_incharge: "Other Cluster"
    )

    controller = ModulesController.new
    controller.define_singleton_method(:model_ready?) { |model_name| model_name.to_s == "Vrp" }
    controller.define_singleton_method(:current_cluster_incharge_labels) { ["Ashvin Durve"] }
    controller.define_singleton_method(:cluster_label_matches?) { |expected, actual| expected.to_s == actual.to_s }
    controller.define_singleton_method(:dashboard_hierarchy_vrps) { [hierarchy_only_vrp] }

    assert_equal [mapped_vrp.id], controller.send(:module_cluster_visible_vrp_ids)
  end

  private

  def create_vrp(attributes = {})
    defaults = {
      name: "Dashboard VRP",
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
      email: "vrp#{SecureRandom.hex(4)}@example.com",
      experience_in_years: 1,
      office_detail_id: 0,
      to_office_detail_id: 0,
      vrp_type_ids: [1],
      gram_panchayat_ids: [1],
      village_ids: [1],
      is_active: true,
      is_deleted: false
    }

    Vrp.create!(defaults.merge(attributes))
  end
end
