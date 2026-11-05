require "test_helper"

# End-to-end smoke test for the mobile API surface, over real HTTP routing and
# auth: every endpoint answers, the TO filter works on both the user and the
# admin dashboard path, and a TO-filtered card still agrees with the list
# behind it -- the invariant that caught a real card-vs-list bug earlier.
class Api::V1::ApiEndpointsSmokeTest < ActionDispatch::IntegrationTest
  MONTH = "June".freeze

  setup do
    @old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    @admin = User.create!(first_name: "Scan", last_name: "Admin",
      user_name: "scan_admin_#{SecureRandom.hex(3)}",
      email: "scan-admin-#{SecureRandom.hex(3)}@example.test",
      mobile_no: "9876500991", password: "secret", user_type: "admin", status: "Active")
    @cc = User.create!(first_name: "Scan", last_name: "Cc",
      user_name: "scan_cc_#{SecureRandom.hex(3)}",
      email: "scan-cc-#{SecureRandom.hex(3)}@example.test",
      mobile_no: "9876500992", password: "secret", user_type: "User",
      status: "Active", role: "Cluster Incharge")

    @north = mapped_jj("Scan North", "123456789101", "9876543301", "TO-North", "ics-north", "Module-1")
    @south = mapped_jj("Scan South", "123456789102", "9876543302", "TO-South", "ics-south", "Module-2")
    @bill = ModuleRecord.create!(module_slug: "jeevika-jankar-bill-process", data: {
      "select_vrp" => @north.id.to_s, "bill_month" => MONTH,
      "bill_status" => "pending", "record_state" => "Active",
      "bill_items" => [{ "village" => "Jamba", "main_activity" => "Other",
                         "activity" => "Module-1", "timesheet_dates" => "2026-06-10",
                         "farmer_details" => [{ "training_date" => "2026-06-10" }] }]
    })
  end

  teardown { Rails.cache = @old_cache }

  test "every endpoint in this batch answers for an admin token" do
    [
      ["/api/v1/user-dashboard", { month: MONTH, to: "TO-North" }],
      ["/api/v1/user-dashboard/filters", { month: MONTH }],
      ["/api/v1/admin-dashboard", { month: MONTH, to: "TO-North" }],
      ["/api/v1/jeevika-jankar-bills", {}],
      ["/api/v1/jeevika-jankar-bills/#{@bill.id}", {}],
      ["/api/v1/jeevika-jankar-bills/#{@bill.id}/invoice", {}]
    ].each do |path, params|
      get path, params: params, headers: auth(@admin)
      assert_response :success, "#{path} did not answer"
      assert response.parsed_body["success"], "#{path} returned success=false"
    end
  end

  test "every endpoint in this batch answers for an office token" do
    [
      ["/api/v1/user-dashboard", { month: MONTH, to: "TO-North" }],
      ["/api/v1/user-dashboard/boxes", { month: MONTH, to: "TO-North" }],
      ["/api/v1/user-dashboard/filters", { month: MONTH }],
      ["/api/v1/user-dashboard/configuration", {}]
    ].each do |path, params|
      get path, params: params, headers: auth(@cc)
      assert_response :success, "#{path} did not answer"
      assert response.parsed_body["success"], "#{path} returned success=false"
    end
  end

  test "both dashboard paths expose the TO options and echo the filter" do
    [[@admin, "admin"], [@cc, "user"]].each do |user, kind|
      get "/api/v1/user-dashboard", params: { month: MONTH, to: "TO-North" }, headers: auth(user)
      assert_response :success
      body = response.parsed_body
      assert_equal kind, body["dashboard_type"]
      assert_includes Array(body.dig("filter_options", "tos")), "TO-North", "#{kind}: no TO options"
      assert_equal "TO-North", body.dig("filters", "to"), "#{kind}: TO not echoed"
    end
  end

  # The invariant that caught a real bug earlier: a card and the list behind it
  # must agree -- including when a TO filter is on.
  test "with a TO selected every card still matches its own list" do
    get "/api/v1/user-dashboard", params: { month: MONTH, to: "TO-North" }, headers: auth(@cc)
    assert_response :success
    cards = response.parsed_body.fetch("sections")
      .select { |section| %w[gender fco_requirement].include?(section["key"]) }
      .flat_map { |section| Array(section["cards"]) }
      .to_h { |card| [card["key"].to_s, card["value"]] }
    refute_empty cards

    cards.each do |key, value|
      get "/api/v1/user-dashboard/lists/#{key}", params: { month: MONTH, to: "TO-North" }, headers: auth(@cc)
      assert_response :success
      records = Array(response.parsed_body.fetch("records"))
      actual = key.end_with?("_required", "_vacant") ? records.first&.fetch("value") : records.size
      assert_equal value, actual, "card #{key} shows #{value} but its list returns #{actual}"
    end
  end

  test "the invoice endpoint returns a complete sheet" do
    get "/api/v1/jeevika-jankar-bills/#{@bill.id}/invoice", headers: auth(@admin)
    assert_response :success
    invoice = response.parsed_body.fetch("invoice")

    %w[bill_id worksheet_id invoice_date invoice_month status stamp jeevika_jankar
       office worksheet total_payment total_payment_label bank_details approvals].each do |key|
      assert invoice.key?(key), "invoice is missing #{key}"
    end
    assert_equal 1, invoice.fetch("worksheet").size
    assert invoice.fetch("worksheet").none? { |row| row["achievement"].to_i.zero? }
  end

  test "the edit endpoints are routable and reject an unknown id cleanly" do
    [["/api/v1/farmer-trainings/999999999", { farmer_training: { training_location: "x" } }],
     ["/api/v1/other-targets/999999999", { other_target: { village: "x" } }]].each do |path, params|
      patch path, params: params, headers: auth(@admin), as: :json
      assert_response :not_found, "#{path} should 404, not crash"
    end
  end

  private

  def auth(user) = { "Authorization" => "Bearer #{ApiAuthToken.encode(user)}" }

  def mapped_jj(name, aadhar, mobile, to_name, ics_id, activity)
    vrp = Vrp.new(name: name, father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: aadhar, account_no: "1234", bank_name: "Bank", branch: "Test",
      ifsc_code: "TEST0123456", address: "Test", mobile_no: mobile,
      email: "#{aadhar}@example.test", fcoc: "FCO-C Sausar", to_name: to_name,
      cluster_incharge: @cc.full_name, is_active: true, status: 55,
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    vrp.save!(validate: false)
    TargetMapping.new(vrp: vrp, fco_id: "1004", fco_name: "Sausar",
      ics_id: ics_id, ics_name: "ICS #{ics_id}", village_id: "village-#{ics_id}",
      month_name: MONTH, main_activity_name: "Other", activity_name: activity,
      target_quantity: 1).save!(validate: false)
    vrp
  end
end
