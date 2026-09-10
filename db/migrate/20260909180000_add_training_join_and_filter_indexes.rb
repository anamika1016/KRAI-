class AddTrainingJoinAndFilterIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # JSON farmer IDs are joined to a.id::text in the existing reports.
    # The bigint primary-key index cannot serve that expression.
    add_index :afls, "(id::text)",
      name: "index_afls_on_text_id", algorithm: :concurrently

    # Match the existing normalized month/FCO predicates before expanding
    # target farmer arrays. Keep both branches of the FCO id/name OR indexable.
    add_index :target_mappings,
      "LOWER(BTRIM(month_name)), LOWER(BTRIM(fco_id))",
      name: "index_targets_on_normalized_month_fco_id", algorithm: :concurrently
    add_index :target_mappings,
      "LOWER(BTRIM(month_name)), LOWER(BTRIM(fco_name))",
      name: "index_targets_on_normalized_month_fco_name", algorithm: :concurrently
  end
end
