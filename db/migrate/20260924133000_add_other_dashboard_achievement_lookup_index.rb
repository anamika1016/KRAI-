class AddOtherDashboardAchievementLookupIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # The Other dashboard joins activity entries by reporting month, main activity
  # and FCO. This covers that read-only reporting predicate without changing data.
  def change
    add_index :module_records,
      "LOWER(BTRIM((data::jsonb ->> 'month'))), LOWER(BTRIM((data::jsonb ->> 'main_activity'))), LOWER(BTRIM((data::jsonb ->> 'fco_name')))",
      name: "index_module_records_on_month_activity_fco",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
