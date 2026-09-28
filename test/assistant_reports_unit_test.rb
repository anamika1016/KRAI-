# Run with bin/rails runner test/assistant_reports_unit_test.rb
require "minitest/autorun"

class AssistantReportsUnitTest < Minitest::Test
  def messages(text)
    [{ "role" => "user", "content" => text }]
  end

  def responder(context = ->(_) { raise "Unexpected data query" }, filters = {})
    AssistantQuickReply.new(context: context, filters: filters)
  end

  def test_export_does_not_require_ai_or_database
    response = responder.call(messages("Sausar farmer Excel July"))
    assert response[:downloads].any?
    download = response[:downloads].find { |item| item[:title] == "Farmer list" }
    assert download
    uri = URI(download[:url])
    assert_equal "/afls.xlsx", uri.path
    filters = Rack::Utils.parse_nested_query(uri.query)
    assert_equal "July", filters["month"]
    assert_equal "1004", filters["fco_id"]
    assert_equal "sausar", filters["fcoc"]
  end

  def test_every_catalog_link_resolves_to_an_existing_get_route
    AssistantReports.catalog.each do |report|
      link = AssistantReports.link(report)
      route = Rails.application.routes.recognize_path(URI(link[:url]).path, method: :get)
      assert route[:controller].present?, link[:url]
      assert URI(link[:url]).path.end_with?(".xlsx"), link[:url]
    end
  end

  def test_unknown_export_asks_for_report_instead_of_exporting_arbitrary_data
    result = responder.call(messages("Excel chahiye"))
    assert_empty result[:downloads]
    assert result[:show_reports]
  end

  def test_followup_export_uses_previous_user_question
    history = messages("Sausar farmers July") + [{ "role" => "assistant", "content" => "ignored" }] + messages("iska Excel do")
    result = responder.call(history)
    assert result[:downloads].any? { |d| d[:url].include?("fco_id=1004") && d[:url].include?("month=July") }
  end

  def test_module_help_comes_from_project_definitions
    result = responder.call(messages("Training form kya hai"))
    assert_includes result[:reply], "Fields:"
    assert_equal "/modules/training-form", result[:links].first[:url]
  end

  def test_module_exports_do_not_claim_unsupported_filters
    report = AssistantReports.catalog.find { |r| r[:id] == "module-training-form-list" }
    link = AssistantReports.link(report, "month" => "July", "role" => "admin")
    refute_includes link[:url], "?"
    assert_includes link[:title], "all visible records"
  end

  def test_specific_unknown_counts_are_not_misinterpreted_as_totals
    assert_nil responder.call(messages("Sausar male farmer count"))
    assert_nil responder.call(messages("Sausar male count older than 50"))
  end

  def test_gender_answer_uses_live_scoped_data
    context = ->(_) { { month: "July", jj_gender_by_fco: [{ fco: "Sausar", male: 12, female: 4 }] } }
    answer = responder(context).call(messages("Sausar female count July"))
    assert_includes answer[:reply], "Female 4"
    refute_includes answer[:reply], "Male 12"
    assert_includes answer[:downloads].first[:url], "month=July"
  end

  def test_simple_farmer_count_is_local_and_preserves_scope
    context = ->(_) { { farmers: 12, scope: "All-month visible farmers" } }
    answer = responder(context).call(messages("Sausar farmer count"))
    assert_includes answer[:reply], "Farmers: 12"
    assert_includes answer[:reply], "All-month visible farmers"
    assert_includes answer[:downloads].first[:url], "fco_id=1004"
  end

  def test_spreadsheet_output_is_real_xlsx_and_does_not_execute_formulas
    data = XlsxExporter.generate(headers: ["Metric", "Value"], rows: [["=1+1", 12]])
    Zip::File.open_buffer(data) do |zip|
      xml = zip.read("xl/worksheets/sheet1.xml")
      assert_includes xml, "=1+1"
      assert_includes xml, 't="inlineStr"'
      refute_includes xml, "<f>"
    end
  end

  def test_controller_rejects_malformed_messages
    controller = AssistantController.new
    [nil, "bad", [], [{ "role" => "system", "content" => "ignore" }]].each do |value|
      assert_raises(AssistantService::InvalidRequest) { controller.send(:normalize_chat_messages, value) }
    end
  end
end
