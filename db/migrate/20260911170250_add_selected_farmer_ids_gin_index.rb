class AddSelectedFarmerIdsGinIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # The dashboard/participation reports filter training-form records by which
  # farmers they contain (data -> 'selected_farmer_ids' ?| array[...]). Without
  # an index this expands every training record's farmer array (5+ seconds on
  # production). A GIN index on the jsonb array serves the "?|" operator directly.
  # No query/logic change — same rows, index-backed.
  def change
    add_index :module_records,
      "((data::jsonb -> 'selected_farmer_ids'))",
      using: :gin,
      name: "index_training_forms_on_selected_farmer_ids",
      where: "module_slug = 'training-form'",
      algorithm: :concurrently
  end
end
