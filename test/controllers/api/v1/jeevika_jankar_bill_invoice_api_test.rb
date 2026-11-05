require "test_helper"

# GET /api/v1/jeevika-jankar-bills/:id/invoice
#
# The app needs the printable invoice the web renders at
# /modules/jeevika-jankar-bill-list/records/:id/download_bill. Every value is
# read through the same helpers that print view calls, so the sheet and the
# API cannot drift apart. The web is untouched.
#
# The rule that matters most here: the invoice lists only the dates work was
# actually recorded on -- a zero-achievement row is dropped and the rest are
# renumbered. The existing payments API (`time_slots`) still returns every row
# and that contract is unchanged.
class Api::V1::JeevikaJankarBillInvoiceApiTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(first_name: "Admin", last_name: "Invoice",
      user_name: "invoice_admin_#{SecureRandom.hex(3)}",
      email: "invoice-admin-#{SecureRandom.hex(3)}@example.test",
      mobile_no: "9876500981", password: "secret", user_type: "admin", status: "Active")

    @vrp = Vrp.new(name: "Invoice JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789081", account_no: "1754810001538", bank_name: "Bank of baroda",
      branch: "Branch", ifsc_code: "BARB0DUNVAD", address: "dungarvant -Pavijetpur Gujrat",
      mobile_no: "9510940165", email: "invoice-jj@example.test",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0,
      user_name: "invoice_jj_#{SecureRandom.hex(3)}", password: "secret",
      fcoc: "FCO-C Sausar", to_name: "TO-Pavijetpur", status: 55, is_active: true)
    @vrp.save!(validate: false)

    @bill = ModuleRecord.create!(module_slug: "jeevika-jankar-bill-process", data: {
      "select_vrp" => @vrp.id.to_s,
      "select_vrp_name" => "Rathva sunilbhai",
      "bill_month" => "October",
      "bill_status" => "pending",
      "record_state" => "Active",
      "bill_items" => [
        {
          "village" => "Jamba",
          "main_activity" => "Farmers' Training",
          "activity" => "Module-4 Organic Nutrient Management",
          "timesheet_dates" => "2026-10-29,2026-10-07",
          # Only the 29th has farmers, so the 7th is a zero-achievement row
          # and must not reach the invoice.
          "farmer_details" => [
            { "training_date" => "2026-10-29" },
            { "training_date" => "2026-10-29" }
          ]
        }
      ]
    })
  end

  test "the invoice endpoint requires auth" do
    get "/api/v1/jeevika-jankar-bills/#{@bill.id}/invoice", as: :json
    assert_response :unauthorized
  end

  test "an unknown bill is a 404, not a crash" do
    get "/api/v1/jeevika-jankar-bills/999999999/invoice", headers: auth
    assert_response :not_found
    refute response.parsed_body["success"]
  end

  test "the invoice carries every block the printed sheet shows" do
    invoice = fetch_invoice

    assert_equal @bill.id, invoice["bill_id"]
    assert_equal "##{@bill.id}", invoice["worksheet_id"]
    assert_equal "October", invoice["invoice_month"]
    assert invoice["invoice_date"].present?, "the sheet prints an invoice date"

    assert_equal "Rathva sunilbhai", invoice.dig("jeevika_jankar", "name")
    assert_equal "9510940165", invoice.dig("jeevika_jankar", "mobile_no")

    office = invoice.fetch("office")
    assert_equal "TO-Pavijetpur", office["to"]
    assert_includes office["line"], "FCO:"
    assert_includes office["line"], "Block:"

    %w[worksheet bank_details approvals total_payment total_payment_label status stamp].each do |key|
      assert invoice.key?(key), "the invoice must carry #{key}"
    end
    assert_equal({ "label" => "Prepared by" }, invoice.dig("approvals", "prepared_by").slice("label"))
  end

  test "zero achievement rows are left out and the rest renumbered" do
    rows = fetch_invoice.fetch("worksheet")

    assert_equal 1, rows.size, "the date with no farmers trained must not be listed"
    assert_equal 1, rows.first["serial"], "the remaining rows are renumbered from 1"
    assert_equal 2, rows.first["achievement"]
    assert rows.none? { |row| row["achievement"].to_i.zero? }
  end

  test "the worksheet columns read the way the printed sheet reads them" do
    row = fetch_invoice.fetch("worksheet").first

    assert_equal "Jamba", row["village_visited"]
    assert_equal "Farmers' Training", row["major_work_indicator"]
    assert_equal "Module-4 Organic Nutrient Management", row["activity"]
  end

  # The sheet prints the JJ's own bank record, not anything stored on the bill.
  test "bank details are numbered and complete" do
    bank = fetch_invoice.fetch("bank_details").first

    assert_equal 1, bank["serial"]
    assert_equal "Bank of baroda", bank["bank_name"]
    assert_equal "1754810001538", bank["account_number"]
    assert_equal "BARB0DUNVAD", bank["ifsc_code"]
    assert_equal "dungarvant -Pavijetpur Gujrat", bank["address"]
  end

  test "a bill that is not final approved is stamped pending" do
    assert_equal "pending", fetch_invoice.fetch("stamp")
  end

  # The strongest check: the numbers must be the ones the print view computes.
  test "the invoice totals match the web print sheet" do
    invoice = fetch_invoice
    web = ModulesController.new
    web.request = ActionDispatch::TestRequest.create
    web.instance_variable_set(:@current_app_user,
      ApplicationController.new.send(:app_user_session_payload, @admin))

    expected_rows = web.send(:jeevika_bill_time_slot_rows, @bill).reject { |row| row[:number].to_i.zero? }
    assert_equal expected_rows.size, invoice.fetch("worksheet").size
    assert_equal web.send(:jeevika_bill_summary, @bill)[:total_amount].to_f, invoice.fetch("total_payment")
    assert_equal web.send(:jeevika_bill_status_label, @bill).to_s, invoice.fetch("status")
    assert_equal web.send(:jeevika_bill_bank_rows, @bill).size, invoice.fetch("bank_details").size
  end

  private

  def auth = { "Authorization" => "Bearer #{ApiAuthToken.encode(@admin)}" }

  def fetch_invoice
    get "/api/v1/jeevika-jankar-bills/#{@bill.id}/invoice", headers: auth
    assert_response :success
    assert response.parsed_body["success"]
    response.parsed_body.fetch("invoice")
  end
end
