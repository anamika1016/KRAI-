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
        fco_name: %w[Sausar Turekela Pavijetpur][index % 3])
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

    get "/api/v1/target-mappings/recent", params: { month: "August", summary_mode: "raw" }, headers: @headers, as: :json

    assert_response :success
    assert_equal "raw", response.parsed_body["summary_mode"]
    assert_equal mapping.id, response.parsed_body["records"].first["id"]
  end

  private

  def create_mapping(main:, sub:, farmers:, month: "August", fco_id: "1006", fco_name: "Turekela")
    TargetMapping.create!(vrp: @vrp, fco_id: fco_id, fco_name: fco_name, ics_id: "ICS-1", village_id: "Village-1",
      month_name: month, main_activity_name: main, activity_name: sub, target_quantity: farmers.size, afl_ids: farmers.map(&:id))
  end
end
