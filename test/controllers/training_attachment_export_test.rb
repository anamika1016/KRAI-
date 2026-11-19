require "test_helper"

class TrainingAttachmentExportTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(first_name: "Export", last_name: "Admin", user_name: "training_export_admin",
      email: "training-export@example.test", mobile_no: "9876500033", password: "secret",
      user_type: "admin", status: "Active")
    post login_path, params: { login: user.user_name, password: "secret" }
    @directory = Rails.root.join("public/uploads/module_records")
    FileUtils.mkdir_p(@directory)
    @filename = "training-export-#{SecureRandom.hex(8)}.jpg"
    @path = @directory.join(@filename)
    File.binwrite(@path, "training evidence")
    @record = ModuleRecord.create!(module_slug: "training-form", data: {
      "photo_close-up_view" => [ "/uploads/module_records/#{@filename}" ],
      "training_register_upload" => [ "/uploads/module_records/../../../../config/database.yml" ]
    })
  end

  teardown do
    FileUtils.rm_f(@path)
  end

  test "exports streamed evidence without reading paths outside upload storage" do
    get export_module_path("training-form-list", format: :zip)
    assert_response :success
    assert_equal "no", response.headers["X-Accel-Buffering"]
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_includes response.headers["Content-Disposition"], ".zip"
    Zip::File.open_buffer(response.body) do |zip|
      assert_equal [ StreamingAttachmentZip::DIRECTORY, "training_attachments/#{@filename}" ], zip.entries.map(&:name)
      assert_equal "training evidence", zip.read("training_attachments/#{@filename}")
    end
  end

  test "ZIP keeps repeated attachments and does not route or update edit approvals" do
    ModuleRecord.create!(module_slug: "training-form", data: @record.data.deep_dup)
    saved_data = { "record_id" => @record.id, "status" => "Pending", "step" => 7,
      "before" => { "selected_farmer_names" => [ "large snapshot" * 10_000 ] },
      "requester" => {}, "evidence" => [ { "base64" => "x" * 100_000 } ] }
    revision = ModuleRecord.create!(module_slug: TrainingEditApproval::SLUG, data: saved_data)
    queries = []
    subscriber = ->(*args) do
      payload = args.last
      queries << [ payload[:sql], Array(payload[:binds]).map { |bind| bind.value_for_database.to_s } ]
    end
    body = nil
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      get export_module_path("training-form-list", format: :zip)
      assert_response :success
      body = response.body
    end
    refute queries.any? { |sql, binds| sql.include?(TrainingEditApproval::SLUG) || binds.include?(TrainingEditApproval::SLUG) },
      "ZIP must not load the approval queue"
    Zip::File.open_buffer(body) do |zip|
      files = zip.entries.reject(&:directory?)
      assert_equal 2, files.size
      assert_equal [ "training evidence", "training evidence" ], files.map { |file| file.get_input_stream.read }
      assert_equal files.size, files.map(&:name).uniq.size
    end
    assert_equal saved_data, revision.reload.data
  end

  test "streamed export includes only records visible to the signed in user" do
    user = User.create!(first_name: "Export", last_name: "Staff", user_name: "training_export_staff",
      email: "training-export-staff@example.test", mobile_no: "9876500034", password: "secret",
      user_type: "User", status: "Active", role: "agricultural specialist", stakeholder_role: "Agronomist")
    ModuleRecord.create!(module_slug: "access-control", data: {
      "stakeholder_role" => "Agronomist", "role" => "agricultural specialist",
      "sub_module_names" => [ "Training Form List" ], "can_view" => "Yes"
    })
    own_name = "own-#{@filename}"
    own_path = @directory.join(own_name)
    File.write(own_path, "own evidence")
    ModuleRecord.create!(module_slug: "training-form", data: {
      "created_by_id" => user.id.to_s, "created_by_record_type" => "User",
      "training_register_upload" => [ "/uploads/module_records/#{own_name}" ]
    })
    post login_path, params: { login: user.user_name, password: "secret" }
    get export_module_path("training-form-list", format: :zip)
    assert_response :success
    Zip::File.open_buffer(response.body) do |zip|
      assert_equal [ StreamingAttachmentZip::DIRECTORY, "training_attachments/#{own_name}" ], zip.entries.map(&:name)
    end
    get export_module_path("training-form-list", format: :xlsx)
    assert_response :success
    Zip::File.open_buffer(response.body) do |zip|
      sheet = zip.read("xl/worksheets/sheet1.xml")
      assert_includes sheet, own_name
      refute_includes sheet, "/module_records/#{@filename}"
    end
  ensure
    FileUtils.rm_f(own_path) if own_path
  end

  test "Excel matches existing export values and order across record batches" do
    records = 802.times.map do |index|
      { module_slug: "training-form", data: {
        "month" => "Month #{index}", "main_activity" => "Activity & <#{index}>",
        "training_register_upload" => [ "/uploads/module_records/#{@filename}" ]
      }, created_at: Time.utc(2026, 1, 1) + index.seconds, updated_at: Time.current }
    end
    ModuleRecord.insert_all!(records)
    pending_record = ModuleRecord.where(module_slug: "training-form").order(:created_at).first
    ModuleRecord.create!(module_slug: TrainingEditApproval::SLUG, data: {
      "record_id" => pending_record.id, "status" => "Pending", "approval_role" => "agronomist"
    })
    ordered = ModuleRecord.where(module_slug: "training-form").to_a.sort_by do |record|
      [ record.id == pending_record.id ? 0 : 1, -record.created_at.to_f, -record.id ]
    end
    baseline = ModulesController.new
    baseline.instance_variable_set(:@module, ModulesController::MODULES["training-form-list"])
    baseline.set_request!(ActionDispatch::TestRequest.create)
    baseline.request.set_header("HTTP_HOST", "www.example.com")
    csv = baseline.send(:module_records_csv, ordered)
    expected = XlsxExporter.from_csv(csv, sheet_name: "Training Form List")

    get export_module_path("training-form-list", format: :xlsx)
    assert_response :success
    assert_equal "no", response.headers["X-Accel-Buffering"]
    Zip::File.open_buffer(expected) do |old_zip|
      Zip::File.open_buffer(response.body) do |zip|
        cells = ->(archive) do
          Nokogiri::XML(archive.read("xl/worksheets/sheet1.xml"))
            .xpath("//*[local-name()='row']").map { |row| row.xpath(".//*[local-name()='t']").map(&:text) }
        end
        assert_equal cells.call(old_zip), cells.call(zip)
        assert_equal 804, cells.call(zip).size
      end
    end
  end

  test "list retains rows and ordering while displaying only first page initially" do
    16.times { |index| ModuleRecord.create!(module_slug: "training-form", data: { "month" => "Screen #{index}" }) }
    get module_path("training-form-list")
    assert_response :success
    assert_select "#training_form_list_table tbody tr", count: 17
    assert_select '#training_form_list_table tbody tr[style="display: none;"]', count: 2
    assert_select '#training_form_list_table[data-page-size="15"][data-preserve-order="true"]'
    assert_select 'a[data-turbo="false"][href*="format=xlsx"]', text: "Export"
    assert_select 'a[data-turbo="false"][href*="format=zip"]', text: "Download Attachments"
  end
end
