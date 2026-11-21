require "test_helper"

class MappedFarmerQueryLoadingTest < ActiveSupport::TestCase
  setup do
    @farmers = 3.times.map { |i| Afl.create!(farmer_name: "Scoped farmer #{i}", fco_id: "query-scope", fco: "Scoped FCO") }
    vrp = Vrp.new(name: "Scoped JJ", cluster_incharge: "Scoped CC", aadhar_no: "123456789012",
      account_no: "1234", address: "Test", branch: "Test", date_of_birth: Date.new(1990, 1, 1),
      date_of_joining: Date.current, email: "query-scope@example.test", experience_in_years: 1,
      father_husband_name: "Test", gender: :male, ifsc_code: "SBIN0001234", mobile_no: "9876543210",
      office_detail_id: 1, to_office_detail_id: 1)
    vrp.save!(validate: false)
    [ ["August", @farmers.first(2)], ["July", @farmers.last(1)] ].each do |month, farmers|
      TargetMapping.create!(vrp: vrp, fco_id: "query-scope", fco_name: "Scoped FCO", ics_id: "query-ics",
        village_id: "query-village", month_name: month, main_activity_name: "Farmers' Training",
        activity_name: "Soil", target_quantity: farmers.size, afl_ids: farmers.map(&:id))
    end
    ModuleRecord.create!(module_slug: "training-form", data: {
      "month" => "August", "selected_farmer_ids" => [@farmers.first.id.to_s],
      "main_activity_type" => "Training", "training_register_upload" => "/uploads/register.pdf",
      "training_photo_upload_with_geo_tag" => "/uploads/photo.jpg"
    })
  end

  test "monthly and all-month mapped lists retain population status and evidence" do
    monthly = query(month: "august", ids: @farmers.map(&:id))
    assert_equal @farmers.first(2).map(&:id).sort, monthly.map { |row| row["id"] }.sort
    trained = monthly.find { |row| row["id"] == @farmers.first.id }
    assert_equal "Training Entry Done", trained["status"]
    assert_equal "/uploads/register.pdf", trained["training_register_urls"]
    assert_equal "/uploads/photo.jpg", trained["training_photo_urls"]
    assert_equal "Scoped JJ", trained["vrp_name"]
    assert_equal "Scoped CC", trained["cluster_incharge"]
    all = query(month: nil, ids: @farmers.map(&:id))
    assert_equal @farmers.map(&:id).sort, all.map { |row| row["id"] }.sort
  end

  test "visible farmer IDs and FCO restrictions still apply before joins" do
    assert_equal [@farmers.second.id], query(month: nil, ids: [@farmers.second.id]).map { |row| row["id"] }
    assert_empty query(month: nil, ids: @farmers.map(&:id), fco: "another-office")
  end

  private

  def query(month:, ids:, fco: "query-scope")
    sql = Rails.root.join("app/queries/mapped_farmer_details.sql").read
      .gsub("%{target_month_filter}", month ? "LOWER(TRIM(t.month_name)) = :month_name" : "TRUE")
      .gsub("%{entry_month_filter}", month ? "LOWER(TRIM(mr.data::jsonb ->> 'month')) = :month_name" : "TRUE")
    sql = ActiveRecord::Base.send(:sanitize_sql_array, [sql, { month_name: month, fco_ids: [fco], visible_farmer_ids: ids }])
    ActiveRecord::Base.connection.exec_query(sql).to_a
  end
end
