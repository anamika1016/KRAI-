class AddOtherTargetMonthLookupIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_other_targets_on_normalized_month"

  def change
    return if index_name_exists?(:module_records, INDEX_NAME)

    add_index :module_records,
      "LOWER(BTRIM(data::jsonb ->> 'month'))",
      name: INDEX_NAME,
      where: "module_slug IN ('seed-distribution-target', 'papl360-target')",
      algorithm: :concurrently
  end
end
