require "test_helper"

class PaymentListLoadingPerformanceTest < ActiveSupport::TestCase
  test "payment attachment links preserve missing uploads without per-row queries" do
    vrps = 4.times.map do |index|
      vrp = Vrp.new(name: "Payment performance #{index}", email: "payment-perf-#{index}@example.test",
        aadhar_no: "123456789012", account_no: "1234", address: "Test", branch: "Test",
        date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
        experience_in_years: 1, father_husband_name: "Test", gender: :male,
        ifsc_code: "SBIN0001234", mobile_no: "9876543210", office_detail_id: 1, to_office_detail_id: 1)
      vrp.save!(validate: false)
      vrp
    end
    blobs = vrps.first(3).map do |vrp|
      blob = ActiveStorage::Blob.create_before_direct_upload!(filename: "passbook.png",
        byte_size: 0, checksum: "1B2M2Y8AsgTpgAmY7PhCfg==", content_type: "image/png")
      ActiveStorage::Attachment.create!(record: vrp, name: "bank_passbook_upload", blob: blob)
      blob
    end
    # Fresh instances have no attachment association populated by test setup.
    by_id = Vrp.where(id: vrps.map(&:id)).index_by { |vrp| vrp.id.to_s }
    records = vrps.map.with_index do |vrp, index|
      ModuleRecord.new(id: index + 1, module_slug: "jeevika-jankar-bill-process",
        data: { "select_vrp" => vrp.id.to_s, "bill_month" => "August" })
    end
    controller = ModulesController.new
    controller.define_singleton_method(:jeevika_bill_final_approved?) { |_| true }
    controller.define_singleton_method(:jeevika_bill_vrp) { |record| by_id[record.data["select_vrp"]] }
    controller.define_singleton_method(:jeevika_bill_rows) { |rows| rows.map { |record| { id: record.id } } }
    controller.define_singleton_method(:jeevika_bill_bank_rows) { |_| [ { bank_name: "Bank", ifsc_code: "IFSC", account_number: "123" } ] }
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      payload = args.last
      queries << payload[:sql] if payload[:name] != "SCHEMA" && payload[:sql].match?(/FROM "active_storage_(attachments|blobs)"/)
    end
    rows = controller.send(:jeevika_bill_payment_rows, records, "August")
    links = rows.map { |row| row[:passbook_attachment].signed_id if row[:passbook_attachment].attached? }
    assert_equal blobs.map(&:signed_id) + [ nil ], links
    assert_equal [ 1, 2, 3, 4 ], rows.map { |row| row[:id] }
    assert rows.all? { |row| row[:bank_name] == "Bank" && row[:account_number] == "123" }
    assert_operator queries.size, :<=, 2, "Attachment presence and links must use bounded queries"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
