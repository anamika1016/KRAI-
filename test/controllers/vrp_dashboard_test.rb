require "test_helper"

class VrpDashboardTest < ActionDispatch::IntegrationTest
  test "vrp sees own dashboard data and read only targets" do
    vrp = create_vrp(
      user_name: "dashboard_vrp",
      password: "secret",
      agreement_accepted_at: Time.current
    )
    repeat_previous = create_afl(
      farmer_name: "Repeat Farmer",
      father_name: "Repeat Father",
      mobile_no: "9000000001",
      tracenet_no: "TR_REPEAT",
      purchase_date: Date.new(2026, 5, 12)
    )
    repeat_current = create_afl(
      farmer_name: "Repeat Farmer",
      father_name: "Repeat Father",
      mobile_no: "9000000001",
      tracenet_no: "TR_REPEAT",
      purchase_date: Date.new(2026, 6, 11)
    )
    new_current = create_afl(
      farmer_name: "New Farmer",
      father_name: "New Father",
      mobile_no: "9000000002",
      tracenet_no: "TR_NEW",
      purchase_date: Date.new(2026, 6, 15)
    )
    pending_farmer = create_afl(
      farmer_name: "Pending Farmer",
      father_name: "Pending Father",
      mobile_no: "9000000003",
      tracenet_no: "TR_PENDING",
      purchase_date: Date.new(2026, 5, 9)
    )
    mapping = VrpIcsMapping.create!(
      vrp: vrp,
      fco_id: "FCO1",
      fco_name: "FCO One",
      ics_id: "ICS1",
      ics_name: "ICS One",
      village_id: "V1",
      village_name: "Village One",
      afl_ids: [repeat_previous.id, repeat_current.id, new_current.id, pending_farmer.id],
      created_by_type: "User",
      created_by_id: 1
    )
    TargetMapping.create!(
      vrp: vrp,
      vrp_ics_mapping: mapping,
      fco_id: mapping.fco_id,
      fco_name: mapping.fco_name,
      ics_id: mapping.ics_id,
      ics_name: mapping.ics_name,
      village_id: mapping.village_id,
      village_name: mapping.village_name,
      farmer_count: 4,
      month_name: "June",
      completion_date: Date.new(2026, 6, 30),
      main_activity_name: "Farmer Visit",
      activity_name: "Farm Visit",
      target_quantity: 10,
      created_by_type: "User",
      created_by_id: 1
    )
    ModuleRecord.create!(
      module_slug: "vrp-bill-add",
      data: {
        "select_vrp" => "#{vrp.name} - #{vrp.mobile_no}",
        "select_bill_month" => "June",
        "select_activity_group" => ["Farmer Visit"],
        "bill_items" => [
          {
            "activity" => "Farm Visit",
            "no_of_unit" => "4",
            "rate" => "0",
            "total_amount" => "0"
          }
        ],
        "grand_units" => "4"
      }
    )
    ModuleRecord.create!(
      module_slug: "training-form",
      data: {
        "month" => "June",
        "training_date" => "2026-06-05",
        "main_activity" => "Farmer Visit",
        "sub_activity" => "Farm Visit",
        "training_topic" => "Farmer Visit",
        "training_subject" => "Farm Visit",
        "selected_farmer_ids" => [repeat_previous.id.to_s, repeat_current.id.to_s]
      }
    )
    ModuleRecord.create!(
      module_slug: "training-form",
      data: {
        "month" => "June",
        "training_date" => "2026-06-12",
        "main_activity" => "Farmer Visit",
        "sub_activity" => "Farm Visit",
        "training_topic" => "Farmer Visit",
        "training_subject" => "Farm Visit",
        "selected_farmer_ids" => [repeat_previous.id.to_s, new_current.id.to_s]
      }
    )
    ModuleRecord.create!(
      module_slug: "training-form",
      data: {
        "month" => "June",
        "training_date" => "2026-06-20",
        "main_activity" => "Farmer Visit",
        "sub_activity" => "Farm Visit",
        "training_topic" => "Farmer Visit",
        "training_subject" => "Farm Visit",
        "selected_farmer_ids" => [repeat_previous.id.to_s, repeat_current.id.to_s]
      }
    )
    ModuleRecord.create!(
      module_slug: "training-form",
      data: {
        "month" => "June",
        "training_date" => "2026-06-22",
        "main_activity" => "Other Activity",
        "sub_activity" => "Other Sub Activity",
        "training_topic" => "Other Activity",
        "training_subject" => "Other Sub Activity",
        "selected_farmer_ids" => [pending_farmer.id.to_s]
      }
    )

    post login_path, params: { login: "dashboard_vrp", password: "secret" }
    follow_redirect!

    assert_response :success
    assert_includes response.body, "Mapped Farmers"
    assert_includes response.body, "Mapped Villages"
    assert_includes response.body, "Main Activities"
    assert_includes response.body, "Sub Activities"
    assert_includes response.body, "Assigned Target"
    assert_includes response.body, "Completed"
    assert_includes response.body, "Farmer Month Follow-up"
    assert_includes response.body, "Farmer Training Dashboard"
    assert_includes response.body, "Select Month"
    assert_includes response.body, "Select Sub Activity"
    assert_includes response.body, "Select Month and Sub Activity to load training data."
    refute_includes response.body, "Farmer Training Participation Status"
    refute_includes response.body, "Sessions"
    refute_includes response.body, "Photos"
    refute_includes response.body, "Registers"
    refute_includes response.body, "Male"
    refute_includes response.body, "Female"
    refute_includes response.body, "Dates"
    refute_includes response.body, "Cumulative"
    assert_includes response.body, "Repeat Farmers"
    assert_includes response.body, "New Farmers"
    assert_includes response.body, "Pending Target Farmers"
    assert_includes response.body, "Repeat Farmer"
    assert_includes response.body, "New Farmer"
    assert_includes response.body, "Pending Farmer"
    assert_includes response.body, "Farmer Visit"
    assert_includes response.body, "40%"
    assert_equal 1, response.body.scan("VRP Dashboard").size
    assert_includes response.body, "VRP Targets"

    get dashboard_path, params: { training_month: "June", training_sub_activity: "Farm Visit" }

    assert_response :success
    assert_includes response.body, "June"
    assert_includes response.body, "Farm Visit"
    assert_match(/<span class="training-status-pill green">1<\/span>/, response.body)
    assert_match(/<span class="training-status-pill yellow">2<\/span>/, response.body)
    assert_match(/<span class="training-status-pill red">1<\/span>/, response.body)
    assert_includes response.body, "Completed Farmers"
    assert_includes response.body, "Pending Farmers"
    refute_includes response.body, "Select Month and Sub Activity to load training data."

    get target_mappings_path

    assert_response :success
    assert_includes response.body, "VRP Targets"
    assert_includes response.body, "Village One"
    assert_includes response.body, "Completion Date"
    assert_includes response.body, "30-06-2026"
    assert_includes response.body, "Farm Visit"
    refute_includes response.body, "Save Target"
    refute_includes response.body, "Delete this target mapping?"
  end

  test "admin sees vrp menu and can select it in access control" do
    accepted_vrp = create_vrp(
      name: "Accepted VRP",
      user_name: "accepted_for_admin",
      mobile_no: "9876543211",
      email: "accepted@example.com",
      aadhar_no: "123456789013",
      agreement_accepted_at: Time.current
    )
    mapping = VrpIcsMapping.create!(
      vrp: accepted_vrp,
      fco_id: "FCO2",
      fco_name: "FCO Two",
      ics_id: "ICS2",
      ics_name: "ICS Two",
      village_id: "V2",
      village_name: "Admin Village",
      afl_ids: ["1"],
      created_by_type: "User",
      created_by_id: 1
    )
    TargetMapping.create!(
      vrp: accepted_vrp,
      vrp_ics_mapping: mapping,
      fco_id: mapping.fco_id,
      fco_name: mapping.fco_name,
      ics_id: mapping.ics_id,
      ics_name: mapping.ics_name,
      village_id: mapping.village_id,
      village_name: mapping.village_name,
      farmer_count: 1,
      month_name: "July",
      completion_date: Date.new(2026, 7, 31),
      main_activity_name: "Admin Activity",
      activity_name: "Admin Sub Activity",
      target_quantity: 7,
      created_by_type: "User",
      created_by_id: 1
    )
    User.create!(
      user_name: "admin",
      password: "secret",
      first_name: "Admin",
      user_type: "admin",
      status: "Active"
    )
    ModuleRecord.create!(
      module_slug: "approval-master",
      data: {
        "module_name" => "Jeevika Jankar Registration",
        "stakeholder_name" => "PAPL",
        "approval_level" => "Approval 1",
        "approver_approved_by" => "Anamika Vishwakarma (Aggronomist)",
        "status" => "Active",
        "user_name" => "Anamika Vishwakarma"
      }
    )
    ModuleRecord.create!(
      module_slug: "approval-master",
      data: {
        "module_name" => "Jeevika Jankar Registration",
        "stakeholder_name" => "PAPL",
        "approval_level" => "Approval 2",
        "approver_approved_by" => "rohit sharma sharma (IT Excicutive)",
        "status" => "Active",
        "user_name" => "rohit sharma sharma"
      }
    )
    ModuleRecord.create!(
      module_slug: "approval-master",
      data: {
        "module_name" => "Jeevika Jankar Registration",
        "stakeholder_name" => "PAPL",
        "approval_level" => "Approval 3",
        "approver_approved_by" => "third approver",
        "status" => "Active",
        "user_name" => "Anamika Vishwakarma"
      }
    )
    ModuleRecord.create!(
      module_slug: "approval-master",
      data: {
        "module_name" => "Jeevika Jankar Registration",
        "stakeholder_name" => "PAPL",
        "approval_level" => "Approval 4",
        "approver_approved_by" => "fourth approver",
        "status" => "Active",
        "user_name" => "Anamika Vishwakarma"
      }
    )

    post login_path, params: { login: "admin", password: "secret" }
    follow_redirect!

    assert_response :success
    assert_includes response.body, "VRP Targets"
    assert_includes response.body, "Accepted VRP"
    assert_includes response.body, "Admin Village"
    assert_includes response.body, "Admin Sub Activity"
    assert_includes response.body, "VRP Declaration Accepted"
    assert_includes response.body, "VRP Target Assigned"

    get module_path("approval-list")

    assert_response :success
    assert_includes response.body, "Stakeholder Category"
    assert_includes response.body, "Approval Levels"
    assert_includes response.body, "First Approval"
    assert_includes response.body, "Second Approval"
    assert_includes response.body, "Third Approval"
    assert_includes response.body, "Fourth Approval"
    refute_includes response.body, "Approval 1"

    approval_record = ModuleRecord.where(module_slug: "approval-master").first
    get edit_module_record_path("approval-master", approval_record)

    assert_response :success
    assert_includes response.body, "First Approval"
    assert_includes response.body, "Second Approval"
    assert_includes response.body, "Third Approval"
    assert_includes response.body, "Fourth Approval"
    refute_includes response.body, "Approval step 0"

    get module_path("access-control")

    assert_response :success
    assert_includes response.body, "VRP Targets"
    refute_includes response.body, "VRP Dashboard"
  end

  test "vrp training form shows only target assigned farmers" do
    vrp = create_vrp(
      name: "Training VRP",
      user_name: "training_vrp",
      mobile_no: "9876543888",
      email: "training-vrp@example.com",
      aadhar_no: "123456789088",
      agreement_accepted_at: Time.current
    )
    farmers = 3.times.map do |index|
      create_afl(
        farmer_name: "Training Farmer #{index + 1}",
        tracenet_no: "TR_TRAINING_#{index + 1}",
        mobile_no: "900000020#{index}"
      )
    end
    mapping = VrpIcsMapping.create!(
      vrp: vrp,
      fco_id: "FCO1",
      fco_name: "FCO One",
      ics_id: "ICS1",
      ics_name: "ICS One",
      village_id: "V1",
      village_name: "Village One",
      afl_ids: farmers.map(&:id),
      created_by_type: "User",
      created_by_id: 1
    )
    TargetMapping.create!(
      vrp: vrp,
      vrp_ics_mapping: mapping,
      fco_id: mapping.fco_id,
      fco_name: mapping.fco_name,
      ics_id: mapping.ics_id,
      ics_name: mapping.ics_name,
      village_id: mapping.village_id,
      village_name: mapping.village_name,
      farmer_count: 2,
      month_name: "July",
      completion_date: Date.new(2026, 7, 31),
      main_activity_name: "Farmer Visit",
      activity_name: "Farm Visit",
      target_quantity: 2,
      afl_ids: farmers.first(2).map(&:id),
      created_by_type: "User",
      created_by_id: 1
    )

    post login_path, params: { login: "training_vrp", password: "secret" }
    follow_redirect!
    get module_path("training-form")

    assert_response :success
    assert_includes response.body, "Farmer Training Form"
    assert_includes response.body, "Target Farmers"
    assert_includes response.body, "Training Farmer 1"
    assert_includes response.body, "Training Farmer 2"
    refute_includes response.body, "Training Farmer 3"
  end

  test "partial target requires selected farmers and blocks same month reassignment" do
    vrp = create_vrp(
      name: "Target VRP",
      user_name: "target_vrp",
      mobile_no: "9876543999",
      email: "target-vrp@example.com",
      aadhar_no: "123456789099"
    )
    farmers = 3.times.map do |index|
      create_afl(
        farmer_name: "Target Farmer #{index + 1}",
        tracenet_no: "TR_TARGET_#{index + 1}",
        mobile_no: "900000010#{index}"
      )
    end
    mapping = VrpIcsMapping.create!(
      vrp: vrp,
      fco_id: "FCO1",
      fco_name: "FCO One",
      ics_id: "ICS1",
      ics_name: "ICS One",
      village_id: "V1",
      village_name: "Village One",
      afl_ids: farmers.map(&:id),
      created_by_type: "User",
      created_by_id: 1
    )
    User.create!(
      user_name: "target_admin",
      password: "secret",
      first_name: "Target Admin",
      user_type: "admin",
      status: "Active"
    )

    post login_path, params: { login: "target_admin", password: "secret" }
    follow_redirect!

    assert_difference("TargetMapping.count", 1) do
      post target_mappings_path, params: {
        target_mapping: target_params(vrp, mapping, "July", 2, farmers.first(2).map(&:id))
      }
    end

    target = TargetMapping.order(:id).last
    assert_equal 2, target.farmer_count
    assert_equal farmers.first(2).map { |farmer| farmer.id.to_s }, target.afl_ids

    get vrp_mappings_target_mappings_path, params: {
      vrp_id: vrp.id,
      fco_id: mapping.fco_id,
      ics_id: mapping.ics_id,
      village_id: mapping.village_id,
      month_name: "July",
      main_activity_name: "Farmer Visit",
      activity_name: "Farm Visit"
    }

    farmer_rows = JSON.parse(response.body).fetch("farmers")
    assigned_rows = farmer_rows.select { |farmer| farmer["assigned_to_other"] }
    available_rows = farmer_rows.reject { |farmer| farmer["assigned_to_other"] }
    assert_equal farmers.first(2).map { |farmer| farmer.id.to_s }.sort, assigned_rows.map { |farmer| farmer["id"] }.sort
    assert_equal [farmers.last.id.to_s], available_rows.map { |farmer| farmer["id"] }

    get vrp_mappings_target_mappings_path, params: {
      vrp_id: vrp.id,
      fco_id: mapping.fco_id,
      ics_id: mapping.ics_id,
      village_id: mapping.village_id,
      month_name: "August",
      main_activity_name: "Farmer Visit",
      activity_name: "Farm Visit"
    }
    august_rows = JSON.parse(response.body).fetch("farmers")
    assert_equal farmers.first(2).map { |farmer| farmer.id.to_s }.sort,
      august_rows.select { |farmer| farmer["assigned_to_other"] }.map { |farmer| farmer["id"] }.sort

    other_vrp = create_vrp(
      user_name: "second_target_vrp",
      password: "secret",
      agreement_accepted_at: Time.current
    )
    other_mapping = VrpIcsMapping.create!(
      vrp: other_vrp,
      fco_id: mapping.fco_id,
      fco_name: mapping.fco_name,
      ics_id: mapping.ics_id,
      ics_name: mapping.ics_name,
      village_id: mapping.village_id,
      village_name: mapping.village_name,
      afl_ids: farmers.map(&:id),
      created_by_type: "User",
      created_by_id: 1
    )

    assert_no_difference("TargetMapping.count") do
      post target_mappings_path, params: {
        target_mapping: target_params(other_vrp, other_mapping, "July", 2, farmers.first(2).map(&:id))
      }
    end

    get vrp_mappings_target_mappings_path, params: {
      vrp_id: other_vrp.id,
      fco_id: other_mapping.fco_id,
      ics_id: other_mapping.ics_id,
      village_id: other_mapping.village_id,
      month_name: "July",
      main_activity_name: "Farmer Visit",
      activity_name: "Farm Visit"
    }

    cross_vrp_rows = JSON.parse(response.body).fetch("farmers")
    assert_equal farmers.first(2).map { |farmer| farmer.id.to_s }.sort,
      cross_vrp_rows.select { |farmer| farmer["assigned_to_other"] }.map { |farmer| farmer["id"] }.sort

    assert_no_difference("TargetMapping.count") do
      post target_mappings_path, params: {
        target_mapping: target_params(vrp, mapping, "August", 1, [farmers.first.id])
      }
    end

    assert_difference("TargetMapping.count", 1) do
      post target_mappings_path, params: {
        target_mapping: target_params(vrp, mapping, "July", 1, [farmers.last.id])
      }
    end
  end

  private

  def target_params(vrp, mapping, month, target_quantity, farmer_ids)
    {
      vrp_id: vrp.id,
      fco_id: mapping.fco_id,
      ics_id: mapping.ics_id,
      village_id: mapping.village_id,
      month_name: month,
      completion_date: Date.new(2026, 7, 31),
      main_activity_name: "Farmer Visit",
      activity_name: "Farm Visit",
      target_quantity: target_quantity,
      afl_ids: farmer_ids
    }
  end

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

  def create_afl(attributes = {})
    defaults = {
      fco_id: "FCO1",
      fco: "FCO One",
      ics_id: "ICS1",
      ics_name: "ICS One",
      village_id: "V1",
      village_name: "Village One",
      farmer_name: "Test Farmer"
    }

    Afl.create!(defaults.merge(attributes))
  end
end
