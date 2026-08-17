class AddTrainingFormMonthLookupIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_training_forms_on_normalized_month"

  def up
    return if index_name_exists?(:module_records, INDEX_NAME)

    add_index :module_records,
      "LOWER(BTRIM(data::jsonb ->> 'month'))",
      name: INDEX_NAME,
      where: "module_slug = 'training-form'",
      algorithm: :concurrently
  end

  def down
    remove_index :module_records,
      name: INDEX_NAME,
      algorithm: :concurrently,
      if_exists: true
  end
end
