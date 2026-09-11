class AddMainActivityFilterIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # The training/dashboard reports filter training-form records and target rows by
  # main activity (e.g. "Farmers' Training") after the month filter. Only month/FCO
  # were indexed, so the main-activity predicate still scanned every matching row.
  # These functional indexes match the exact predicates; no query/logic changes.
  def change
    add_index :module_records,
      "(LOWER(BTRIM(COALESCE((data::jsonb ->> 'main_activity'), ''))))",
      name: "index_training_forms_on_normalized_main_activity",
      where: "module_slug = 'training-form'",
      algorithm: :concurrently

    add_index :target_mappings,
      "(LOWER(BTRIM(main_activity_name)))",
      name: "index_targets_on_normalized_main_activity",
      algorithm: :concurrently

    add_index :target_mappings,
      "(LOWER(BTRIM(activity_name)))",
      name: "index_targets_on_normalized_activity_name",
      algorithm: :concurrently
  end
end
