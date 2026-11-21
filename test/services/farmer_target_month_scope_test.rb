require "test_helper"

class FarmerTargetMonthScopeTest < ActiveSupport::TestCase
  test "text-backed month filter retains explicit months legacy creation window and module scope" do
    travel_to Time.zone.local(2026, 11, 15, 12) do
      start = Time.current.beginning_of_month
      create = lambda do |month, time, slug = "training-form"|
        ModuleRecord.create!(module_slug: slug, data: { "month" => month, "note" => "Month filter" }, created_at: time)
      end
      named = create.call(" NOVEMBER ", start - 2.months)
      missing = create.call(nil, start)
      blank = create.call(" ", start + 2.days)
      create.call("August", start + 1.day)
      create.call(nil, start - 1.second)
      create.call(nil, start.next_month)
      create.call("November", start, "other-target")
      api = FarmerTargetApi.new(current_app_user: { "user_type" => "admin" }, module_slug: "training-form")
      # Include excluded records too; the original module predicate must still
      # constrain both sides of the month/fallback OR.
      scope = ModuleRecord.where(module_slug: "training-form")
      ids = api.send(:list_month_scope, scope, " November ").pluck(:id)
      assert_includes ids, named.id
      assert_includes ids, missing.id
      assert_includes ids, blank.id
      expected = scope.to_a.select do |record|
        value = record.data["month"].to_s.strip
        value.downcase == "november" || (value.empty? && record.created_at >= start && record.created_at < start.next_month)
      end.map(&:id)
      assert_equal expected.sort, ids.sort
      assert_equal scope.pluck(:id).sort, api.send(:list_month_scope, scope, nil).pluck(:id).sort
    end
  end
end
