require "test_helper"
require "ostruct"

class ModulesControllerDashboardTest < ActiveSupport::TestCase
  remove_const(:Target) if defined?(Target)
  Target = Struct.new(
    :id,
    :vrp_id, :fco_name, :fco_id, :ics_name, :ics_id, :village_name,
    :village_id, :month_name, :completion_date, :opg_training_target,
    :week_wise_opg_target, :input_demo_inm_target, :input_demo_pm_target,
    :ffs_target, :afl_ids, :main_activity_name, :activity_name,
    :mapping_group_key, :target_mapping_id,
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
      afl_ids: %w[11 12],
      mapping_group_key: "group_1"
    }
    targets = [
      Target.new(**assignment, main_activity_name: "Training", activity_name: "Activity A"),
      Target.new(**assignment, main_activity_name: "Training", activity_name: "Activity B"),
      Target.new(**assignment.merge(month_name: "September", mapping_group_key: "group_2"), main_activity_name: "Training", activity_name: "Activity A")
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
    record = OpenStruct.new(data: { "target_mapping_id" => saved_mapping.id.to_s })
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

  test "CC dashboard counts and lists only registration mapped JJ farmers" do
    own = create_vrp(user_name: "scope_own", cluster_incharge: "Mapped CC")
    other = create_vrp(user_name: "scope_other", cluster_incharge: "Other CC", mobile_no: "9876500999", aadhar_no: "123456780999")
    farmer = Afl.create!(farmer_name: "Own Farmer", fco_id: "1004")
    hidden = Afl.create!(farmer_name: "Other Farmer", fco_id: "1004")
    [[own, farmer], [other, hidden]].each do |vrp, afl|
      target = TargetMapping.new(vrp_id: vrp.id, fco_id: "1004", ics_id: "test-ics", village_id: "test-village", target_quantity: 1, month_name: "August", main_activity_name: "Farmers' Training", activity_name: "Training", afl_ids: [afl.id.to_s])
      target.save!(validate: false)
    end
    controller = ModulesController.new
    controller.define_singleton_method(:current_app_user) { { "id" => "500", "name" => "Mapped CC", "role" => "Cluster Coordinator" } }
    controller.define_singleton_method(:admin_dashboard_user?) { false }
    controller.define_singleton_method(:current_cluster_incharge_labels) { ["Mapped CC"] }
    assert_equal [own.id], controller.send(:dashboard_vrps).map(&:id)
    assert_equal [own.id], controller.send(:dashboard_target_mappings).map(&:vrp_id).uniq
    assert_equal 1, controller.send(:farmer_training_mapped_farmer_count_and_popups, month_name: "August", fcoc_name: "1004").first
    rows = controller.send(:farmer_training_participation_rows_from_sql, "red", month_name: "August", fcoc_name: "1004")
    assert_equal [farmer.id.to_s], rows.map { |row| row[:farmer_id] }
  end

  test "unmapped CC sees zero counts and query results are reused within request" do
    controller = ModulesController.new
    controller.define_singleton_method(:current_app_user) { { "id" => "501", "name" => "Unmapped CC", "role" => "Cluster Coordinator" } }
    controller.define_singleton_method(:admin_dashboard_user?) { false }
    controller.define_singleton_method(:current_cluster_incharge_labels) { ["Unmapped CC"] }
    calls = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*args| calls << args.last[:sql] }
    first = controller.send(:farmer_training_mapped_farmer_count_and_popups, month_name: "August", fcoc_name: "1004")
    count = calls.size
    second = controller.send(:farmer_training_mapped_farmer_count_and_popups, month_name: "August", fcoc_name: "1004")
    assert_equal 0, first.first
    assert_equal first, second
    assert_equal count, calls.size
    assert_empty controller.send(:dashboard_visible_farmer_scope).to_a
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "participation report processes attachments once per training entry" do
    first = Afl.create!(farmer_name: "First")
    second = Afl.create!(farmer_name: "Second")
    record = ModuleRecord.create!(module_slug: "training-form", data: {
      "selected_farmer_ids" => [first.id.to_s, second.id.to_s], "month" => "August",
      "training_date" => "2026-08-10", "training_method" => "FFS",
      "training_register_upload" => "register.pdf", "training_photo_upload_with_geo_tag" => "photo.jpg"
    })
    controller = ModulesController.new
    controller.define_singleton_method(:admin_dashboard_user?) { true }
    controller.define_singleton_method(:vrp_login_user?) { false }
    controller.define_singleton_method(:farmer_participation_visible_vrps) { [] }
    controller.define_singleton_method(:active_module_records_scope) { |_| ModuleRecord.where(id: record.id) }
    calls = []
    controller.define_singleton_method(:module_upload_public_urls) { |value| calls << value; [value] }
    rows = controller.send(:farmer_participation_entries)
    assert_equal [first.id.to_s, second.id.to_s], rows.map { |row| row[:farmer_id] }
    assert_equal ["register.pdf", "photo.jpg"], calls
    assert rows.all? { |row| row[:training_method] == "FFS" && row[:month] == "August" }
  end

  test "bill summary is reused within request and refreshed when bill data changes" do
    controller = ModulesController.new
    calls = 0
    controller.define_singleton_method(:compute_jeevika_bill_summary) { |record| calls += 1; { amount: record.data["grand_total"] } }
    record = ModuleRecord.new(data: { "grand_total" => "5000" })
    assert_equal controller.send(:jeevika_bill_summary, record), controller.send(:jeevika_bill_summary, record)
    assert_equal 1, calls
    record.data["grand_total"] = "4000"
    assert_equal "4000", controller.send(:jeevika_bill_summary, record)[:amount]
    assert_equal 2, calls
  end

  test "CC designation is recognized even when session role is User" do
    controller = ModulesController.new
    controller.define_singleton_method(:current_app_user) { { "role" => "User", "stakeholder_role" => "CC" } }
    assert controller.send(:module_cluster_incharge_login?)
  end

  test "agronomist dashboard excludes JJ registered by others" do
    own = create_vrp(user_name: "agro_own", created_by_id: 801)
    create_vrp(user_name: "agro_other", created_by_id: 802, mobile_no: "9876500999", aadhar_no: "123456780999")
    controller = ModulesController.new
    controller.define_singleton_method(:current_app_user) { { "id" => "801", "role" => "Agronomist", "record_type" => "User" } }
    controller.define_singleton_method(:dashboard_current_app_user_ids) { [801] }
    assert_equal [own.id], controller.send(:dashboard_visible_vrp_ids)
  end

  test "FCOC dashboard includes every JJ of its FCO regardless of CC" do
    own = create_vrp(user_name: "fco_own", fcoc: "FCO-C Sausar", cluster_incharge: "Another CC")
    create_vrp(user_name: "fco_other", fcoc: "FCO-C Turekela", mobile_no: "9876500999", aadhar_no: "123456780999")
    controller = ModulesController.new
    controller.define_singleton_method(:current_app_user) { { "id" => "803", "role" => "FCOC", "fcoc" => "FCO-C Sausar" } }
    assert_equal [own.id], controller.send(:dashboard_visible_vrp_ids)
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
