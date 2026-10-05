class AddNormalizedTargetOwnerMonthIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Bill totals and scoped target lists filter owner and normalized month
    # together; the existing raw-month composite cannot serve that expression.
    add_index :target_mappings,
      "vrp_id, LOWER(BTRIM(month_name))",
      name: "index_target_mappings_on_owner_normalized_month",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
