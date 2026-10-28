require "test_helper"

# AFL Upload is paginated on the server, so the per-heading search boxes have
# to narrow the query, not just the rows that happen to be on screen.
class AflHeadingSearchTest < ActionDispatch::IntegrationTest
  setup do
    User.create!(user_name: "afl_search_admin", password: "secret", first_name: "AFL",
      last_name: "Admin", user_type: "admin", status: "Active",
      email: "afl-search@example.test", mobile_no: "9876500811")
    post login_path, params: { login: "afl_search_admin", password: "secret" }

    farmer("1004", "Sausar", "ICS Alpha", "Ramesh Kumar", "TRC-A1")
    farmer("1006", "Turekela", "ICS Beta", "Suresh Patel", "TRC-B1")
    farmer("1004", "Sausar", "ICS Beta", "Mahesh Yadav", "TRC-A2")
  end

  test "a heading box narrows the list to matching rows" do
    get afls_path, params: { col: { fco: "turekela" } }
    assert_response :success

    assert_includes response.body, "Suresh Patel"
    refute_includes response.body, "Ramesh Kumar"
    refute_includes response.body, "Mahesh Yadav"
  end

  test "two heading boxes narrow together, not either-or" do
    get afls_path, params: { col: { fco: "sausar", ics_name: "Beta" } }
    assert_response :success

    assert_includes response.body, "Mahesh Yadav"
    refute_includes response.body, "Ramesh Kumar", "Sausar but ICS Alpha"
    refute_includes response.body, "Suresh Patel", "ICS Beta but Turekela"
  end

  # The heading widget is built by the shared JS from these attributes, which
  # is what makes AFL Upload look and behave like every other list.
  test "each heading carries what the shared filter widget needs" do
    get afls_path, params: { col: { farmer_name: "Ramesh" }, colop: { farmer_name: "starts" } }
    assert_response :success

    assert_select "table#afl_list[data-column-filter-form=?]", "afl_search_form"
    assert_select "th[data-column-filter-param=?][data-column-filter-value=?]", "col[farmer_name]", "Ramesh"
    assert_select "th[data-column-filter-param=?][data-column-filter-operator=?]", "col[farmer_name]", "starts"
    assert_select "th[data-column-filter-param=?]", "col[tracenet_no]"
  end

  test "a total column offers no filter" do
    get afls_path, params: { summary_mode: "ics" }
    assert_response :success

    assert_select "th", text: /Farmer Count/
    assert_select "th[data-column-filter-param=?]", "col[farmer_count]", count: 0
  end

  test "Equals matches the whole value, Contains does not have to" do
    get afls_path, params: { col: { farmer_name: "Ramesh" }, colop: { farmer_name: "equals" } }
    assert_response :success
    refute_includes response.body, "Ramesh Kumar", "equals means the whole value"

    get afls_path, params: { col: { farmer_name: "Ramesh Kumar" }, colop: { farmer_name: "equals" } }
    assert_response :success
    assert_includes response.body, "Ramesh Kumar"
  end

  test "Starts with and Ends with anchor the match" do
    get afls_path, params: { col: { farmer_name: "Ramesh" }, colop: { farmer_name: "starts" } }
    assert_response :success
    assert_includes response.body, "Ramesh Kumar"
    refute_includes response.body, "Suresh Patel"

    get afls_path, params: { col: { farmer_name: "Patel" }, colop: { farmer_name: "ends" } }
    assert_response :success
    assert_includes response.body, "Suresh Patel"
    refute_includes response.body, "Ramesh Kumar"
  end

  test "a made-up operator falls back to Contains instead of erroring" do
    get afls_path, params: { col: { farmer_name: "amesh" }, colop: { farmer_name: "'; DROP TABLE afls; --" } }
    assert_response :success
    assert_includes response.body, "Ramesh Kumar"
    assert_predicate Afl.count, :positive?
  end

  test "heading search works on the grouped ICS view too" do
    get afls_path, params: { summary_mode: "ics", col: { fco: "turekela" } }
    assert_response :success

    assert_includes response.body, "ICS Beta"
    refute_includes response.body, "ICS Alpha"
  end

  test "an unknown column in the query string is ignored, not run as SQL" do
    get afls_path, params: { col: { "not_a_column" => "boom" } }
    assert_response :success
    assert_includes response.body, "Ramesh Kumar"
  end

  test "an empty box does not filter anything out" do
    get afls_path, params: { col: { fco: "  " } }
    assert_response :success

    assert_includes response.body, "Ramesh Kumar"
    assert_includes response.body, "Suresh Patel"
  end

  # The heading rows were rewritten to come from one list instead of four
  # hand-written blocks. Every mode has to still print exactly the headings it
  # printed before, in the same order.
  {
    "ics" => ["FCO ID", "FCO Name", "FPO ID", "FPO Name", "ICS ID", "ICS Name", "Farmer Count"],
    "village" => ["FCO ID", "FCO Name", "FPO ID", "FPO Name", "ICS ID", "ICS Name",
                  "Village ID", "Village Name", "Farmer Count"],
    "farmer" => ["FCO ID", "FCO Name", "FPO ID", "FPO Name", "ICS ID", "ICS Name",
                 "Village ID", "Village Name", "Tracenet No", "Farmer Name", "Father Name"],
    "" => ["", "ID", "Farm ID", "FCO ID", "FCO", "FPO ID", "FPO Name", "ICS ID", "ICS Name",
           "Village ID", "Village Name", "Farmer Name", "Father Name", "Tracenet No",
           "Total Farm Area", "Purchase Quantity Amount", "Estimate Quantity",
           "Purchase Quantity", "Purchase Date", "Mobile No", "Purchase Product", "Status"]
  }.each do |mode, expected|
    test "the #{mode.presence || 'full'} view prints the headings it always did" do
      get afls_path, params: { summary_mode: mode }
      assert_response :success

      headings = Nokogiri::HTML(response.body).css("table#afl_list thead th").map { |th| th.text.strip }
      assert_equal expected, headings
    end
  end

  private

  def farmer(fco_id, fco, ics_name, farmer_name, tracenet)
    Afl.create!(fco_id: fco_id, fco: fco, ics_id: "ics-#{ics_name.parameterize}", ics_name: ics_name,
      village_id: "v-#{tracenet}", village_name: "Village #{tracenet}",
      farmer_name: farmer_name, father_name: "Father", tracenet_no: tracenet)
  end
end
