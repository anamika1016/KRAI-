class AddDashboardFarmerFcoExpressionIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :afls, "LOWER(BTRIM(fco_id))",
      name: "index_afls_on_normalized_fco_id", algorithm: :concurrently, if_not_exists: true
    add_index :afls, "LOWER(BTRIM(COALESCE(fco_id, '')))",
      name: "index_afls_on_normalized_coalesced_fco_id", algorithm: :concurrently, if_not_exists: true
    add_index :afls, "LOWER(BTRIM(fco))",
      name: "index_afls_on_normalized_fco_name", algorithm: :concurrently, if_not_exists: true
  end
end
