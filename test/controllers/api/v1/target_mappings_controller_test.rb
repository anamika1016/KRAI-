require "test_helper"

class Api::V1::TargetMappingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @vrp = Vrp.new(name: "Mapping API JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: "9876543210", email: "mapping-api@example.test",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    @vrp.save!(validate: false)
    @headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(@vrp)}" }
    @farmer_1 = Afl.create!(farmer_name: "One")
    @farmer_2 = Afl.create!(farmer_name: "Two")
    @farmer_3 = Afl.create!(farmer_name: "Three")
  end

  test "recent target mappings require authentication" do
    get "/api/v1/target-mappings/recent", as: :json

    assert_response :unauthorized
  end

  test "default list uses the same row-level records as the web recent target mapping list" do
    create_mapping(main: "Farmers' Training", sub: "Soil", farmers: [@farmer_1, @farmer_2])
    create_mapping(main: "Farmers' Training", sub: "Water", farmers: [@farmer_2, @farmer_3])
    create_mapping(main: "Farmers WhatsApp Groups", sub: "Group", farmers: [@farmer_3], fco_id: "1004", fco_name: "Sausar")
    create_mapping(main: "Farmers' Training", sub: "Excluded", farmers: [@farmer_1], month: "July")

    other = @vrp.dup
    other.email = "other-mapping-api@example.test"
    other.save!(validate: false)
    TargetMapping.create!(vrp: other, fco_id: "1006", fco_name: "Turekela", ics_id: "ICS-1", village_id: "Village-1",
      month_name: "August", main_activity_name: "Farmers' Training", activity_name: "Private",
      target_quantity: 1, afl_ids: [@farmer_1.id])

    get "/api/v1/target-mappings/recent", params: { month: "August", fco: "All", ics: "All", page: 1, per_page: 1 }, headers: @headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal "raw", body["summary_mode"]
    assert_equal 3, body["count"]
    assert_equal 1, body["records"].size
    assert_equal 3, body.dig("pagination", "total_pages")

    get "/api/v1/target-mappings/recent", params: { month: "August", fco: "All", ics: "All", summary_mode: "main_activity", page: 1, per_page: 100 }, headers: @headers, as: :json
    rows = response.parsed_body["records"].index_by { |row| row["main_activity"] }

    assert_equal({ "sub_activity_count" => 2, "farmer_count" => 3, "target_count" => 2 }, rows.fetch("Farmers' Training").slice("sub_activity_count", "farmer_count", "target_count"))
    assert_equal 3, rows.fetch("Farmers' Training")["mapped_farmer_count"]
    assert_equal 2, rows.fetch("Farmers' Training")["target_mapping_count"]
    assert_equal({ "sub_activity_count" => 1, "farmer_count" => 1, "target_count" => 1 }, rows.fetch("Farmers WhatsApp Groups").slice("sub_activity_count", "farmer_count", "target_count"))
  end

  test "FCO aliases filter summary rows like the web target mapping list" do
    create_mapping(main: "Farmers' Training", sub: "Soil", farmers: [@farmer_1], fco_id: "1006", fco_name: "Turekela")
    create_mapping(main: "Farmers WhatsApp Groups", sub: "Group", farmers: [@farmer_2], fco_id: "1004", fco_name: "Sausar")

    get "/api/v1/target-mappings/recent", params: { month: "August", fco: "FCO-C Turekela", ics: "All" }, headers: @headers, as: :json

    assert_response :success
    assert_equal 1, response.parsed_body["count"]
    row = response.parsed_body["records"].first
    assert_equal "Farmers' Training", row["main_activity"]
    assert_equal 1, row["farmer_count"]
  end

  test "sub activity summary includes every web row for multiple FCO IDs" do
    %w[Soil Water Seed Compost Irrigation Induction].each_with_index do |sub, index|
      create_mapping(main: "Farmers' Training", sub: sub, farmers: [@farmer_1],
        fco_id: %w[1004 1006 1095][index % 3],
        fco_name: %w[Sausar Turekela Direct to HO][index % 3])
    end

    get "/api/v1/target-mappings/recent", params: {
      month: "August", summary_mode: "sub_major_work_indicators",
      fco_id: %w[1004 1006 1095], per_page: 100
    }, headers: @headers, as: :json

    assert_response :success
    assert_equal "sub_activity", response.parsed_body["summary_mode"]
    assert_equal 6, response.parsed_body["count"]
    assert_equal %w[Compost Induction Irrigation Seed Soil Water],
      response.parsed_body["records"].map { |row| row["sub_activity"] }
    assert response.parsed_body["records"].all? { |row|
      row["mapped_farmer_count"] == 1 && row["target_mapping_count"] == 1
    }
  end

  test "raw mode remains available for consumers that need individual mappings" do
    mapping = create_mapping(main: "Farmers' Training", sub: "Soil", farmers: [@farmer_1])
    @vrp.update!(cluster_incharge: "Mapping CC")
    mapping.update!(cc_target: 7)

    get "/api/v1/target-mappings/recent", params: { month: "August", summary_mode: "raw" }, headers: @headers, as: :json

    assert_response :success
    assert_equal "raw", response.parsed_body["summary_mode"]
    record = response.parsed_body["records"].first
    assert_equal mapping.id, record["id"]
    assert_equal "Mapping CC", record["cc_name"]
    assert_equal "Mapping CC", record["cluster_incharge"]
    assert_equal 7, record["cc_target"]
  end

  test "raw recent list treats All month as every visible saved mapping" do
    august = create_mapping(main: "Farmers' Training", sub: "Soil", farmers: [@farmer_1])
    july = create_mapping(main: "Farmers' Training", sub: "Water", farmers: [@farmer_2], month: "July")

    get "/api/v1/target-mappings/recent", params: { month: "All", fco: "All", ics: "All", per_page: 100 }, headers: @headers, as: :json

    assert_response :success
    assert_equal "raw", response.parsed_body["summary_mode"]
    assert_equal [august.id, july.id].sort, response.parsed_body["records"].map { |row| row["id"] }.sort
  end

  test "raw recent pagination returns farmers only for the requested page" do
    first = create_mapping(main: "Farmers' Training", sub: "Soil", farmers: [@farmer_1])
    second = create_mapping(main: "Farmers' Training", sub: "Water", farmers: [@farmer_2], month: "July")
    first.update_columns(updated_at: 2.days.ago)
    second.update_columns(updated_at: 1.day.ago)

    get "/api/v1/target-mappings/recent", params: { month: "All", page: 2, per_page: 1 }, headers: @headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal 2, body.fetch("count")
    assert_equal 2, body.dig("pagination", "total_pages")
    assert_equal [first.id], body.fetch("records").map { |row| row.fetch("id") }
    assert_equal [@farmer_1.id.to_s], body.fetch("records").first.fetch("farmers").map { |farmer| farmer.fetch("id") }
    assert_equal body.fetch("records"), body.fetch("target_mappings")
  end

  test "mapped farmer pagination preserves total and requested farmer" do
    mapping = create_mapping(main: "Farmers' Training", sub: "Soil", farmers: [@farmer_1, @farmer_2])
    get "/api/v1/target-mappings/mapped-farmers", params: { month: "All", page: 2, per_page: 1 }, headers: @headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal 2, body.fetch("count")
    assert_equal 2, body.dig("pagination", "total_pages")
    assert_equal mapping.id.to_s, body.fetch("records").first.fetch("target_mapping_id")
    assert_equal @farmer_2.id.to_s, body.fetch("records").first.fetch("farmer_id")
    assert_equal body.fetch("records"), body.fetch("mapped_farmers")
  end

  test "admin recent groups activity mappings like the web list before pagination" do
    admin = User.create!(first_name: "Mapping", last_name: "Admin", user_name: "mapping_admin",
      email: "mapping-admin@example.test", mobile_no: "9876500199", password: "secret", user_type: "admin", status: "Active")
    first = create_mapping(main: "Farmers' Training", sub: "Soil", farmers: [@farmer_1])
    second = create_mapping(main: "Farmers' Training", sub: "Water", farmers: [@farmer_2])
    first.update!(mapping_group_key: "same-assignment")
    second.update!(mapping_group_key: "same-assignment")
    third = create_mapping(main: "Other", sub: "Other", farmers: [@farmer_3])
    get "/api/v1/target-mappings/recent", params: { month: "All", per_page: 100 },
      headers: { "Authorization" => "Bearer #{ApiAuthToken.encode(admin)}" }, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal 2, body.fetch("count")
    group = body.fetch("records").find { |row| row.fetch("target_mapping_ids").include?(first.id) }
    assert_equal [first.id, second.id].sort, group.fetch("target_mapping_ids").sort
    assert_equal %w[Soil Water], group.fetch("sub_activities").sort
    assert_equal 2, group.fetch("farmer_count")
    assert body.fetch("records").any? { |row| row.fetch("target_mapping_ids").include?(third.id) }
  end

  private

  def create_mapping(main:, sub:, farmers:, month: "August", fco_id: "1006", fco_name: "Turekela")
    TargetMapping.create!(vrp: @vrp, fco_id: fco_id, fco_name: fco_name, ics_id: "ICS-1", village_id: "Village-1",
      month_name: month, main_activity_name: main, activity_name: sub, target_quantity: farmers.size, afl_ids: farmers.map(&:id))
  end
end
