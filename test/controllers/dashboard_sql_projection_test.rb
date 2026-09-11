require "test_helper"

class DashboardSqlProjectionTest < ActiveSupport::TestCase
  setup do
    @farmers = 4.times.map { |index| Afl.create!(farmer_name: "Projection farmer #{index}", fco_id: "1004", fco: "Sausar") }
    @vrp = Vrp.new(name: "Projection JJ", aadhar_no: "123456789012", account_no: "1234", address: "Test", branch: "Test",
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current, email: "projection@example.test",
      experience_in_years: 1, father_husband_name: "Test", gender: :male, ifsc_code: "SBIN0001234",
      mobile_no: "9876543210", office_detail_id: 1, to_office_detail_id: 1)
    @vrp.save!(validate: false)
    @target = TargetMapping.create!(vrp: @vrp, fco_id: "1004", fco_name: "Sausar", ics_id: "projection", village_id: "projection",
      month_name: "August", main_activity_name: "Farmers' Training", activity_name: "Soil", target_quantity: 4, afl_ids: @farmers.map(&:id))
    first, repeat, _missing, duplicate = @farmers.map { |farmer| farmer.id.to_s }
    data = { "month" => " AUGUST ", "main_activity" => "Farmers' Training", "main_activity_type" => " Training ",
      "training_date" => "2026-08-01", "training_method" => "FFS", "trainer_name" => "Projection JJ",
      "training_register_upload" => "/uploads/register.pdf", "training_photo_upload_with_geo_tag" => "/uploads/photo.jpg" }
    ModuleRecord.create!(module_slug: "training-form", data: data.merge(
      "selected_farmer_ids" => [first, repeat, duplicate, duplicate], "target_mapping_ids" => [@target.id.to_s, @target.id.to_s]))
    ModuleRecord.create!(module_slug: "training-form", data: data.merge(
      "selected_farmer_ids" => [repeat], "target_mapping_id" => " #{@target.id} ", "training_date" => "2026-08-12"))
    ModuleRecord.create!(module_slug: "training-form", data: data.merge("month" => "July", "selected_farmer_ids" => @farmers.map { |farmer| farmer.id.to_s }))
    ModuleRecord.create!(module_slug: "training-form", data: data)
    @controller = ModulesController.new
    @controller.params = ActionController::Parameters.new(month: "August", vrp_id: @vrp.id)
    @controller.define_singleton_method(:current_app_user) { { "user_type" => "admin" } }
  end

  test "participation retains duplicate handling dates uploads and no-entry rows" do
    yellow = rows("yellow")
    green = rows("green")
    assert_equal [@farmers[0].id.to_s], yellow.map { |row| row[:farmer_id] }
    assert_equal [@farmers[1].id.to_s], green.map { |row| row[:farmer_id] }
    assert_equal 1, yellow.first[:attendance_count]
    assert_equal 2, green.first[:attendance_count]
    # Preserve the existing MIN date behavior and upload representation.
    assert_equal "2026-08-01", green.first[:last_training_date]
    assert_equal ["/uploads/register.pdf"], green.first[:training_register_urls]
    assert_equal ["/uploads/photo.jpg"], yellow.first[:training_photo_urls]
    assert_equal [@farmers[2].id.to_s], rows("red").map { |row| row[:farmer_id] }
    mapped = rows("unique")
    assert_equal @farmers.map { |farmer| farmer.id.to_s }.sort, mapped.map { |row| row[:farmer_id] }.sort
    assert_equal ["/uploads/register.pdf"], mapped.find { |row| row[:farmer_id] == @farmers.first.id.to_s }[:training_register_urls]
  end

  test "dashboard counts retain array and singular mapping IDs and distinct completions" do
    counts = @controller.send(:training_participation_dashboard_counts_from_sql, month_name: "August", fcoc_name: "Sausar", targets: [@target])
    assert_equal({ total: 4, green: 1, yellow: 2, red: 1, target_map_total: 4, completed_target_map_total: 3 },
      counts.slice(:total, :green, :yellow, :red, :target_map_total, :completed_target_map_total))
  end

  private

  def rows(status)
    ids = @farmers.map { |farmer| farmer.id.to_s }
    @controller.send(:farmer_training_participation_rows_from_sql, status, month_name: "August", fcoc_name: "1004")
      .select { |row| ids.include?(row[:farmer_id]) }
  end
end
