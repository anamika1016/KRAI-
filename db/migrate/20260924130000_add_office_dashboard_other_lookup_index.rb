class AddOfficeDashboardOtherLookupIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # OfficeDashboardSections joins training entries to a target by the effective
  # JJ/VRP owner, reporting month and main activity. This expression matches
  # that join exactly and is built concurrently so dashboard reads keep working.
  def change
    add_index :module_records,
      "COALESCE(NULLIF((data::jsonb ->> 'vrp_id'), ''), CASE WHEN LOWER((data::jsonb ->> 'created_by_record_type')) = 'vrp' THEN (data::jsonb ->> 'created_by_id') END), LOWER(BTRIM((data::jsonb ->> 'month'))), LOWER(BTRIM((data::jsonb ->> 'main_activity')))",
      name: "index_training_forms_on_owner_month_activity",
      where: "module_slug = 'training-form'",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
