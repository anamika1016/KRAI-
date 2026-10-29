require "test_helper"

# The TO filter sits beside FCO: it lists the sub offices that exist under the
# FCO in view, defaults to all of them, and narrows the ICS list to that TO.
class DashboardToFilterTest < ActionDispatch::IntegrationTest
  setup do
    User.create!(user_name: "to_filter_admin", password: "secret", first_name: "TO",
      last_name: "Filter", user_type: "admin", status: "Active",
      email: "to-filter@example.test", mobile_no: "9876500971")
    post login_path, params: { login: "to_filter_admin", password: "secret" }

    @hinganghat = jj("Hinganghat JJ", "FCO-C Sausar", "TO-Hinganghat")
    @sausar     = jj("Sausar JJ", "FCO-C Sausar", "TO-Sausar")
    @turekela   = jj("Turekela JJ", "FCO-C Turekela", "TO-Turekela")

    target(@hinganghat, "ics-sawli", "Sawli Wagh FPC", "1004", "Sausar")
    target(@sausar, "ics-allipur", "Allipur Agro FPC", "1004", "Sausar")
    target(@turekela, "ics-bastrani", "Bastrani Women FPC", "1006", "Turekela")
  end

  test "the TO dropdown sits beside FCO and defaults to All TO" do
    get "/dashboard", params: { month: month }
    assert_response :success

    assert_select "select#dash_to option[value='']", text: "All TO"
    assert_select "select#dash_to option[selected]", count: 0, message: "nothing pre-selected"
  end

  test "it lists only the TOs under the FCO in view" do
    get "/dashboard", params: { month: month, fcoc: "FCO-C Sausar" }
    assert_response :success

    assert_select "select#dash_to option", text: "TO-Hinganghat"
    assert_select "select#dash_to option", text: "TO-Sausar"
    assert_select "select#dash_to option", text: "TO-Turekela", count: 0,
      message: "Turekela's sub office belongs to another FCO"
  end

  test "picking a TO leaves only that TO's ICS to choose from" do
    get "/dashboard", params: { month: month, fcoc: "FCO-C Sausar", to_name: "TO-Hinganghat" }
    assert_response :success

    assert_select "select#dash_ics option", text: "Sawli Wagh FPC"
    assert_select "select#dash_ics option", text: "Allipur Agro FPC", count: 0,
      message: "that ICS belongs to TO-Sausar"
  end

  test "All TO leaves every ICS of the FCO in place" do
    get "/dashboard", params: { month: month, fcoc: "FCO-C Sausar" }
    assert_response :success

    assert_select "select#dash_ics option", text: "Sawli Wagh FPC"
    assert_select "select#dash_ics option", text: "Allipur Agro FPC"
  end

  # "TO-Turekela" and "TO- Turekela" are the same office saved two ways.
  test "one office saved with different spellings is listed once" do
    jj("Spacey JJ", "FCO-C Sausar", "TO- Hinganghat").tap do |vrp|
      target(vrp, "ics-sawli-2", "Sawli Wagh FPC Two", "1004", "Sausar")
    end

    get "/dashboard", params: { month: month, fcoc: "FCO-C Sausar" }
    assert_response :success

    labels = Nokogiri::HTML(response.body).css("select#dash_to option").map { |o| o.text.strip }
    hinganghat = labels.select { |l| l.downcase.delete(" ").include?("hinganghat") }
    assert_equal 1, hinganghat.size, "listed once, not twice: #{labels.inspect}"
  end

  # A TO is created on Sub Office Add long before anyone is posted to it, and
  # that is exactly when it has to be selectable.
  test "a TO added in Office Setup appears before any Jeevika Jankar has it" do
    get "/dashboard", params: { month: month, fcoc: "FCO-C Sausar" }
    assert_response :success
    assert_select "select#dash_to option", text: "TO-higarghat", count: 0

    sub_office("FCO-C Sausar", "TO-higarghat")

    get "/dashboard", params: { month: month, fcoc: "FCO-C Sausar" }
    assert_response :success
    assert_select "select#dash_to option", text: "TO-higarghat"
  end

  test "an Office Setup TO stays with its own FCO" do
    sub_office("FCO-C Sausar", "TO-higarghat")

    get "/dashboard", params: { month: month, fcoc: "FCO-C Turekela" }
    assert_response :success
    assert_select "select#dash_to option", text: "TO-higarghat", count: 0
  end

  test "a deactivated sub office drops out of the list" do
    sub_office("FCO-C Sausar", "TO-Closed", status: "Inactive")

    get "/dashboard", params: { month: month, fcoc: "FCO-C Sausar" }
    assert_response :success
    assert_select "select#dash_to option", text: "TO-Closed", count: 0
  end

  test "an Office Setup TO and the same TO on a JJ are one option" do
    sub_office("FCO-C Sausar", "TO -Sausar")

    get "/dashboard", params: { month: month, fcoc: "FCO-C Sausar" }
    assert_response :success

    labels = Nokogiri::HTML(response.body).css("select#dash_to option").map { |o| o.text.strip }
    assert_equal 1, labels.count { |l| l.downcase.delete(" -").include?("sausar") }, labels.inspect
  end

  test "a TO added later needs no code change to appear" do
    get "/dashboard", params: { month: month, fcoc: "FCO-C Sausar" }
    assert_response :success
    assert_select "select#dash_to option", text: "TO-Brand-New", count: 0

    fresh = jj("Brand New JJ", "FCO-C Sausar", "TO-Brand-New")
    target(fresh, "ics-fresh", "Fresh ICS", "1004", "Sausar")

    get "/dashboard", params: { month: month, fcoc: "FCO-C Sausar" }
    assert_response :success
    assert_select "select#dash_to option", text: "TO-Brand-New"
  end

  test "the chip shows which TO is applied" do
    get "/dashboard", params: { month: month, fcoc: "FCO-C Sausar", to_name: "TO-Hinganghat" }
    assert_response :success
    assert_select ".filter-chip", text: "TO: TO-Hinganghat"
  end

  private

  def sub_office(office_name, sub_office_name, status: "Active")
    ModuleRecord.create!(module_slug: "office-mapping-add", data: {
      "stakeholder_category" => "PAPL", "parent_category" => "FCO-C",
      "office_name" => office_name, "sub_office_name" => sub_office_name,
      "office_level" => "Block", "status" => status
    })
  end

  def jj(name, fcoc, to_name)
    Vrp.create!(name: name, father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "12345678#{rand(1000..9999)}", account_no: "1234567890", bank_name: "Bank",
      branch: "Branch", ifsc_code: "TEST0123456", address: "Address",
      mobile_no: "98765#{rand(10000..99999)}", email: "jj_#{SecureRandom.hex(4)}@example.com",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0, vrp_type_ids: [1],
      gram_panchayat_ids: [1], village_ids: [1], user_name: "jj_#{SecureRandom.hex(4)}",
      password: "secret", fcoc: fcoc, to_name: to_name)
  end

  def target(vrp, ics_id, ics_name, fco_id, fco_name)
    farmer = Afl.create!(farmer_name: "Farmer #{SecureRandom.hex(3)}", tracenet_no: SecureRandom.hex(6),
      fco_id: fco_id, fco: fco_name, ics_id: ics_id, ics_name: ics_name,
      village_id: "v-#{ics_id}", village_name: "Village #{ics_id}")
    TargetMapping.create!(vrp: vrp, fco_id: fco_id, fco_name: fco_name, ics_id: ics_id,
      ics_name: ics_name, village_id: "v-#{ics_id}", village_name: "Village #{ics_id}",
      month_name: month, main_activity_name: "Farmers' Training", activity_name: "Soil",
      target_quantity: 1, afl_ids: [farmer.id])
  end

  def month
    @month ||= Date.current.strftime("%B")
  end
end
