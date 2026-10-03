require "test_helper"

# The FCO list used to be hardcoded as 1004/1006/1095 in a dozen places, so an
# FCO added in Office Setup never appeared on the dashboard. It now comes from
# the farmer master, under whatever name AFL stores.
class FcoDirectoryTest < ActiveSupport::TestCase
  setup { FcoDirectory.reset_cache! }
  teardown { FcoDirectory.reset_cache! }

  test "raw AFL-only offices do not create extra dashboard cards" do
    farmer("1004", "Sausar")
    farmer("1006", "Turekela")
    farmer("1095", "Pavijetpur")
    farmer("1200", "Direct to HO")

    assert_equal %w[1004 1006 1095].sort, FcoDirectory.ids.sort
    refute_includes FcoDirectory.names, "Direct to HO"
  end

  test "the name is whatever AFL stores for that id" do
    farmer("1095", "Pavijetpur Renamed")

    assert_equal ["Pavijetpur Renamed"], FcoDirectory.names
  end

  test "filter values cover the id, the bare name and the FCO-C spelling" do
    farmer("1200", "Direct to HO")
    ModuleRecord.create!(module_slug: "office-category-add", data: {
      "parent_category" => "FCO-C", "office_name" => "FCO-C Direct to HO", "status" => "Active"
    })
    FcoDirectory.reset_cache!

    assert_equal ["1200", "Direct to HO", "FCO-C Direct to HO"], FcoDirectory.filter_values
  end

  # Cards are labelled "<name> Male", so a stored prefix would read
  # "FCO-C Sausar Male" on the web while the mobile API read "Sausar Male".
  test "the FCO-C prefix AFL sometimes stores is dropped from the name" do
    farmer("1004", "FCO-C Sausar")
    farmer("1095", "FCO-Pavijetpur")

    assert_equal %w[Pavijetpur Sausar], FcoDirectory.names.sort
    assert_includes FcoDirectory.filter_values, "FCO-C Sausar", "the stored spelling still has to match"
  end

  test "blank and duplicate FCO ids are ignored" do
    farmer("1004", "Sausar")
    farmer("1004", "Sausar")
    Afl.create!(farmer_name: "No FCO", tracenet_no: "no-fco", fco_id: "", fco: "")

    assert_equal ["1004"], FcoDirectory.ids
  end

  # Target rows from an unconfigured operational office must not add cards.
  test "an FCO known only to a target mapping does not appear" do
    farmer("1004", "Sausar")
    vrp = create_vrp(fcoc: "FCO-C Direct to HO")
    TargetMapping.create!(vrp: vrp, fco_id: "1200", fco_name: "FCO-C Direct to HO",
      ics_id: "HO", ics_name: "HO", village_id: "v1", village_name: "Village", month_name: "August",
      main_activity_name: "Other", activity_name: "Soil Sample", target_quantity: 1)
    FcoDirectory.reset_cache!

    refute_includes FcoDirectory.ids, "1200"
    refute_includes FcoDirectory.names, "Direct to HO"
  end

  # Imported AFL rows carry the string "NULL", and some target rows put the name
  # in the id column -- both produced junk boxes on the dashboard.
  test "junk ids and name-as-id duplicates are dropped" do
    farmer("1004", "Sausar")
    Afl.create!(farmer_name: "Junk", tracenet_no: "junk-1", fco_id: "NULL", fco: "NULL")
    vrp = create_vrp
    TargetMapping.create!(vrp: vrp, fco_id: "Sausar", fco_name: "Sausar", ics_id: "i", ics_name: "I",
      village_id: "v", village_name: "V", month_name: "August", main_activity_name: "Other",
      activity_name: "Soil Sample", target_quantity: 1)
    FcoDirectory.reset_cache!

    assert_equal ["1004"], FcoDirectory.ids, "the numeric office code wins"
    assert_equal ["Sausar"], FcoDirectory.names
  end

  # An FCO-C added in Office Setup has no farmers of its own; it reports through
  # the sub office it is mapped to.
  test "an Office Setup FCO-C resolves to the sub office it reports through" do
    farmer("1095", "Pavijetpur")
    ModuleRecord.create!(module_slug: "office-mapping-add", data: {
      "parent_category" => "FCO-C", "office_name" => "Direct to HO",
      "sub_office_name" => "TO-Pavijetpur", "status" => "Active"
    })
    FcoDirectory.reset_cache!

    assert_equal "Pavijetpur", FcoDirectory.canonical_name("Direct to HO")
    assert_nil FcoDirectory.canonical_name("Pavijetpur"), "a real FCO keeps its own path"
    assert_nil FcoDirectory.canonical_name("1095")
  end

  test "mapped sub-office values retain the actual FCO dashboard label" do
    farmer("1095", "Pavijetpur")
    ModuleRecord.create!(module_slug: "office-mapping-add", data: {
      "parent_category" => "FCO-C", "office_name" => "Direct to HO",
      "sub_office_name" => "TO-Pavijetpur", "status" => "Active"
    })
    FcoDirectory.reset_cache!

    assert_equal "Pavijetpur", FcoDirectory.display_name_for("1095")
    assert_equal "Pavijetpur", FcoDirectory.display_name_for("Pavijetpur")
    assert_includes FcoDirectory.aliases_for("Direct to HO"), "1095"
  end

  test "historic Direct-to-HO spelling resolves from the correctly spelled filter" do
    farmer("1095", "Pavijetpur")
    ModuleRecord.create!(module_slug: "office-mapping-add", data: {
      "parent_category" => "FCO-C", "office_name" => "direact to ho",
      "sub_office_name" => "TO-Pavijetpur", "status" => "Active"
    })
    FcoDirectory.reset_cache!

    assert_equal "Pavijetpur", FcoDirectory.names.first
    assert_includes FcoDirectory.aliases_for("Direct to HO"), "1095"
    assert_equal "Pavijetpur", FcoDirectory.display_name_for("Pavijetpur")
  end

  test "an office mapped to something that is not an FCO is left alone" do
    farmer("1095", "Pavijetpur")
    ModuleRecord.create!(module_slug: "office-mapping-add", data: {
      "parent_category" => "FCO-C", "office_name" => "Direct to HO",
      "sub_office_name" => "TO-Nowhere", "status" => "Active"
    })
    FcoDirectory.reset_cache!

    assert_nil FcoDirectory.canonical_name("Direct to HO")
  end

  test "falls back to the original three when AFL has nothing" do
    assert_equal %w[1004 1006 1095], FcoDirectory.ids
    assert_equal %w[Sausar Turekela Pavijetpur], FcoDirectory.names
  end

  test "the dashboard default FCO scope excludes an unconfigured AFL office" do
    farmer("1200", "Direct to HO")

    controller = ModulesController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new
    controller.define_singleton_method(:current_app_user) { { "user_type" => "admin" } }

    values = controller.send(:dashboard_summary_fco_filter_values)
    refute_includes values, "1200"
    refute_includes values, "direct to ho"
  end

  private

  def create_vrp(attributes = {})
    Vrp.create!({
      name: "Directory JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current, aadhar_no: "123456789012",
      account_no: "1234567890", bank_name: "Bank", branch: "Branch", ifsc_code: "TEST0123456",
      address: "Address", mobile_no: "9876543210", email: "jj_#{SecureRandom.hex(4)}@example.com",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0, vrp_type_ids: [1],
      gram_panchayat_ids: [1], village_ids: [1],
      user_name: "jj_#{SecureRandom.hex(4)}", password: "secret"
    }.merge(attributes))
  end

  def farmer(fco_id, fco)
    Afl.create!(farmer_name: "Farmer #{SecureRandom.hex(3)}", tracenet_no: SecureRandom.hex(6),
      fco_id: fco_id, fco: fco, ics_id: "ics-#{fco_id}", ics_name: "ICS #{fco_id}",
      village_id: "v-#{fco_id}", village_name: "Village #{fco_id}")
    FcoDirectory.reset_cache!
  end
end
