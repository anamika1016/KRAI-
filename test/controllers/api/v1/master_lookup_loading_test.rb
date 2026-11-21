require "test_helper"

class Api::V1::MasterLookupLoadingTest < ActionDispatch::IntegrationTest
  test "master lookup avoids record hydration while retaining filters order and inactive rows" do
    user = User.create!(first_name: "Lookup", user_name: "lookup-load-#{SecureRandom.hex(4)}",
      password: "secret", user_type: "admin", status: "Active")
    headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(user)}" }
    entries = [
      { "state" => " Bihar ", "village_name" => "First", "village_code" => 7, "status" => " active " },
      { "state" => "Bihar", "village_name" => "Inactive", "status" => "Inactive" },
      { "state" => "Bihar", "village_name" => "Legacy", "status" => "" },
      { "state" => "Other", "village_name" => "Excluded", "status" => "Active" }
    ].map.with_index do |data, index|
      ModuleRecord.create!(module_slug: "village-master", data: data, created_at: (10 - index).minutes.ago)
    end
    # Preserve the original relation's ordering, field types and Ruby matching.
    original = ModuleRecord.where(module_slug: "village-master").order(created_at: :desc).to_a
    hydrated = 0
    subscription = ActiveSupport::Notifications.subscribe("instantiation.active_record") do |*args|
      event = args.last
      hydrated += event[:record_count] if event[:class_name] == "ModuleRecord"
    end
    get "/api/v1/jeevika-jankar-masters/villages", params: { state: "bihar" }, headers: headers
    assert_response :success
    expected = original.select { |record| record.data["state"].to_s.strip.casecmp("bihar").zero? && (record.data["status"].to_s.strip.blank? || record.data["status"].to_s.strip.casecmp("active").zero?) }
    assert_equal expected.map(&:id), response.parsed_body.fetch("villages").map { |row| row["id"] }
    assert_equal 7, response.parsed_body.fetch("villages").find { |row| row["id"] == entries.first.id }["village_code"]
    get "/api/v1/jeevika-jankar-masters/villages", params: { state: " BIHAR ", include_inactive: true }, headers: headers
    assert_response :success
    assert_equal original.select { |record| record.data["state"].to_s.strip.casecmp("bihar").zero? }.map(&:id), response.parsed_body.fetch("villages").map { |row| row["id"] }
    assert_equal 0, hydrated
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end
end
