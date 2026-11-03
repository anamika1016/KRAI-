require "test_helper"

# Target Mapping Master gets a TO between FCO and ICS. ICS TO MAPPING records
# which ICS belongs to which TO, and that master alone decides what the ICS
# dropdown offers: one ICS mapped, one ICS offered; none mapped, none offered.
class TargetMappingToFilterTest < ActionDispatch::IntegrationTest
  setup do
    User.create!(user_name: "tm_to_admin", password: "secret", first_name: "TM",
      last_name: "Admin", user_type: "admin", status: "Active",
      email: "tm-to@example.test", mobile_no: "9876500831")
    post login_path, params: { login: "tm_to_admin", password: "secret" }

    @vrp = Vrp.create!(name: "TO Filter JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current, aadhar_no: "123456780011",
      account_no: "1234567890", bank_name: "Bank", branch: "Branch", ifsc_code: "TEST0123456",
      address: "Address", mobile_no: "9876540011", email: "to_filter_jj@example.com",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0, vrp_type_ids: [1],
      gram_panchayat_ids: [1], village_ids: [1], user_name: "to_filter_jj", password: "secret",
      fcoc: "FCO-C Sausar", to_name: "TO-Hinganghat", status: 55, is_active: true)

    @alpha = afl("ICS Alpha", "ics-alpha", "Village A", "v-a")
    @beta  = afl("ICS Beta", "ics-beta", "Village B", "v-b")

    sub_office("FCO-C Sausar", "TO-Hinganghat")
    sub_office("FCO-C Sausar", "TO -Sausar")
    sub_office("FCO-C Turekela", "TO- Turekela")
  end

  test "the form has a TO select between FCO and ICS" do
    get target_mappings_path
    assert_response :success

    doc = Nokogiri::HTML(response.body)
    names = doc.css("select").map { |s| s["name"] }.compact
    assert_includes names, "target_mapping[to_name]"
    assert_operator names.index("target_mapping[to_name]"), :>, names.index("target_mapping[fco_id]")
    assert_operator names.index("target_mapping[to_name]"), :<, names.index("target_mapping[ics_id]")
  end

  test "TO options are the sub offices of the chosen FCO only" do
    get vrp_mappings_target_mappings_path, params: { fco_id: "1004||Sausar" }, as: :json
    assert_response :success

    labels = response.parsed_body.fetch("to_options").map { |o| o["label"] }
    assert_includes labels, "TO-Hinganghat"
    assert_includes labels, "TO -Sausar"
    refute_includes labels, "TO- Turekela", "that one belongs to another FCO"
  end

  test "a TO with nothing mapped to it offers no ICS" do
    assert_empty ics_labels(to_name: "TO-Hinganghat")
    assert has_ics?(ics_labels(to_name: nil), "ICS Alpha"), "All TO is unaffected"
  end

  # Exactly what the master says -- one row mapped, one ICS offered.
  test "one mapped ICS means one ICS in the list" do
    ics_to_mapping("ICS Alpha", "Sausar", "TO -Sausar")

    assert_equal 1, ics_labels(to_name: "TO -Sausar").size
    assert has_ics?(ics_labels(to_name: "TO -Sausar"), "ICS Alpha")
    assert_empty ics_labels(to_name: "TO-Hinganghat"), "nothing mapped to this TO"
  end

  test "adding a second mapping grows the list straight away" do
    ics_to_mapping("ICS Alpha", "Sausar", "TO -Sausar")
    assert_equal 1, ics_labels(to_name: "TO -Sausar").size

    ics_to_mapping("ICS Beta", "Sausar", "TO -Sausar")
    assert_equal 2, ics_labels(to_name: "TO -Sausar").size
  end

  test "a mapped TO narrows the ICS list to its own ICS" do
    ics_to_mapping("ICS Alpha", "FCO-C Sausar", "TO-Hinganghat")

    labels = ics_labels(to_name: "TO-Hinganghat")
    assert has_ics?(labels, "ICS Alpha")
    refute has_ics?(labels, "ICS Beta"), "Beta is not filed under this TO"
  end

  test "All TO still shows every ICS of the FCO" do
    ics_to_mapping("ICS Alpha", "FCO-C Sausar", "TO-Hinganghat")

    labels = ics_labels(to_name: "")
    assert has_ics?(labels, "ICS Alpha")
    assert has_ics?(labels, "ICS Beta")
  end

  test "TO spelling variants match the same office" do
    ics_to_mapping("ICS Alpha", "FCO-C Sausar", "TO-Hinganghat")

    assert has_ics?(ics_labels(to_name: "TO- Hinganghat"), "ICS Alpha")
    assert has_ics?(ics_labels(to_name: "TO -Hinganghat"), "ICS Alpha")
    refute has_ics?(ics_labels(to_name: "TO -Hinganghat"), "ICS Beta")
  end

  # Only ICS TO MAPPING decides; a JJ's own ICS mapping does not leak in.
  test "ICS TO MAPPING alone drives the list" do
    VrpIcsMapping.create!(vrp: @vrp, fco_id: "1004", fco_name: "Sausar",
      ics_id: "ics-alpha", ics_name: "ICS Alpha", village_id: "v-a",
      village_name: "Village A", afl_ids: [@alpha.id].to_json)
    ics_to_mapping("ICS Beta", "FCO-C Sausar", "TO-Hinganghat")

    labels = ics_labels(to_name: "TO-Hinganghat")
    assert has_ics?(labels, "ICS Beta")
    refute has_ics?(labels, "ICS Alpha"), "only what ICS TO MAPPING lists"
  end

  test "two ICS mapped to the TO both show" do
    ics_to_mapping("ICS Alpha", "FCO-C Sausar", "TO-Hinganghat")
    ics_to_mapping("ICS Beta", "FCO-C Sausar", "TO-Hinganghat")

    labels = ics_labels(to_name: "TO-Hinganghat")
    assert has_ics?(labels, "ICS Alpha")
    assert has_ics?(labels, "ICS Beta")
  end

  test "an ICS mapped to another TO stays out of that TO's list" do
    ics_to_mapping("ICS Alpha", "FCO-C Sausar", "TO -Sausar")
    ics_to_mapping("ICS Beta", "FCO-C Sausar", "TO-Hinganghat")

    assert_equal ["ICS Alpha"], ics_labels(to_name: "TO -Sausar").map { |l| l.split(" - ").first }
    assert_equal ["ICS Beta"], ics_labels(to_name: "TO-Hinganghat").map { |l| l.split(" - ").first }
  end

  test "the Recent Target Mappings list shows a TO column" do
    TargetMapping.create!(vrp: @vrp, fco_id: "1004", fco_name: "Sausar", ics_id: "ics-alpha",
      ics_name: "ICS Alpha", village_id: "v-a", village_name: "Village A", month_name: "June",
      main_activity_name: "Farmers' Training", activity_name: "Soil", target_quantity: 1,
      afl_ids: [@alpha.id])

    get target_mappings_path
    assert_response :success

    headers = Nokogiri::HTML(response.body).css("table thead th").map { |th| th.text.strip }
    assert_includes headers, "TO"
    assert_includes response.body, "TO-Hinganghat"
  end

  # The whole point of the safety work: saving must still go through.
  test "saving a target mapping still works with the TO field posted" do
    assert_difference("TargetMapping.count", 1) do
      post target_mappings_path, params: { target_mapping: {
        vrp_id: @vrp.id, fco_id: "1004||Sausar", to_name: "TO-Hinganghat",
        ics_id: "ics-alpha||ICS Alpha", village_id: "v-a||Village A",
        month_name: "June", main_activity_name: "Seed Packet Distribution 2026-27",
        activity_name: "Non GMO Seed", target_quantity: 1, afl_ids: [@alpha.id.to_s]
      } }
    end
    refute_nil TargetMapping.last.ics_name
  end

  private

  def has_ics?(labels, name)
    labels.any? { |label| label.start_with?(name) }
  end

  def ics_labels(to_name:)
    params = { fco_id: "1004||Sausar" }
    params[:to_name] = to_name if to_name
    get vrp_mappings_target_mappings_path, params: params, as: :json
    assert_response :success
    response.parsed_body.fetch("ics_options").map { |o| o["label"].to_s }
  end

  def afl(ics_name, ics_id, village_name, village_id)
    Afl.create!(farmer_name: "Farmer #{SecureRandom.hex(3)}", tracenet_no: SecureRandom.hex(6),
      fco_id: "1004", fco: "Sausar", ics_id: ics_id, ics_name: ics_name,
      village_id: village_id, village_name: village_name)
  end

  def sub_office(office_name, sub_office_name)
    ModuleRecord.create!(module_slug: "office-mapping-add", data: {
      "stakeholder_category" => "PAPL", "parent_category" => "FCO-C",
      "office_name" => office_name, "sub_office_name" => sub_office_name, "status" => "Active" })
  end

  def ics_to_mapping(ics_name, fco_name, to_name)
    ModuleRecord.create!(module_slug: "ics-to-mapping", data: {
      "ics_name" => ics_name, "fco_name" => fco_name, "to_name" => to_name, "status" => "Active" })
  end
end
