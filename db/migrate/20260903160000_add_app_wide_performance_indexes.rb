class AddAppWidePerformanceIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :module_records,
      [:module_slug, :updated_at, :id],
      name: "index_module_records_on_slug_updated_at_id",
      order: { updated_at: :desc, id: :desc },
      algorithm: :concurrently,
      if_not_exists: true

    add_index :module_records,
      "LOWER(BTRIM((data::jsonb ->> 'status')))",
      name: "index_module_records_on_slug_normalized_status",
      where: "module_slug IN ('access-control', 'new-user', 'training-form', 'seed-distribution-target', 'papl360-target', 'other-target')",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :module_records,
      "(data::jsonb ->> 'select_vrp')",
      name: "index_module_records_bills_on_select_vrp",
      where: "module_slug = 'jeevika-jankar-bill-process'",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :module_records,
      "LOWER(BTRIM((data::jsonb ->> 'status')))",
      name: "index_module_records_bills_on_normalized_status",
      where: "module_slug = 'jeevika-jankar-bill-process'",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :module_records,
      "LOWER(BTRIM((data::jsonb ->> 'record_state')))",
      name: "index_module_records_bills_on_normalized_record_state",
      where: "module_slug = 'jeevika-jankar-bill-process'",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :module_records,
      "(data::jsonb ->> 'bill_id')",
      name: "index_module_records_bill_history_on_bill_id",
      where: "module_slug = 'jeevika-jankar-bill-approval-history'",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :module_records,
      "(data::jsonb ->> 'vrp_id')",
      name: "index_module_records_vrp_history_on_vrp_id",
      where: "module_slug = 'vrp-approval-history'",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :module_records,
      "(data::jsonb ->> 'jeevika_jankar_id')",
      name: "index_training_forms_on_jeevika_jankar_id",
      where: "module_slug = 'training-form'",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :module_records,
      "(data::jsonb ->> 'vrp_id')",
      name: "index_training_forms_on_vrp_id",
      where: "module_slug = 'training-form'",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :module_records,
      "(data::jsonb ->> 'target_mapping_id')",
      name: "index_training_forms_on_target_mapping_id",
      where: "module_slug = 'training-form'",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :module_records,
      "(data::jsonb -> 'target_mapping_ids')",
      name: "index_training_forms_on_target_mapping_ids_gin",
      using: :gin,
      where: "module_slug = 'training-form'",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :module_records,
      "(data::jsonb -> 'selected_farmer_ids')",
      name: "index_training_forms_on_selected_farmer_ids_gin",
      using: :gin,
      where: "module_slug = 'training-form'",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :users,
      :created_at,
      name: "index_users_on_created_at",
      order: { created_at: :desc },
      algorithm: :concurrently,
      if_not_exists: true

    add_index :users,
      :updated_at,
      name: "index_users_on_updated_at",
      order: { updated_at: :desc },
      algorithm: :concurrently,
      if_not_exists: true

    add_index :users,
      [:status, :created_at],
      name: "index_users_on_status_and_created_at",
      order: { created_at: :desc },
      algorithm: :concurrently,
      if_not_exists: true

    add_index :vrps,
      :created_at,
      name: "index_vrps_on_created_at",
      order: { created_at: :desc },
      algorithm: :concurrently,
      if_not_exists: true

    add_index :vrps,
      :updated_at,
      name: "index_vrps_on_updated_at",
      order: { updated_at: :desc },
      algorithm: :concurrently,
      if_not_exists: true

    add_index :vrps,
      [:is_deleted, :is_active, :fcoc],
      name: "index_vrps_on_deleted_active_fcoc",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :vrps,
      "LOWER(BTRIM(fcoc))",
      name: "index_vrps_on_normalized_fcoc",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :target_mappings,
      "LOWER(BTRIM(month_name))",
      name: "index_target_mappings_on_normalized_month_name",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :target_mappings,
      "LOWER(BTRIM(main_activity_name))",
      name: "index_target_mappings_on_normalized_main_activity",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :target_mappings,
      "LOWER(BTRIM(activity_name))",
      name: "index_target_mappings_on_normalized_activity",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :target_mappings,
      "LOWER(BTRIM(fco_id))",
      name: "index_target_mappings_on_normalized_fco_id",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :target_mappings,
      "LOWER(BTRIM(fco_name))",
      name: "index_target_mappings_on_normalized_fco_name",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :target_mappings,
      "LOWER(BTRIM(ics_id))",
      name: "index_target_mappings_on_normalized_ics_id",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :target_mappings,
      "LOWER(BTRIM(ics_name))",
      name: "index_target_mappings_on_normalized_ics_name",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :afls,
      "LOWER(BTRIM(fco_id))",
      name: "index_afls_on_normalized_fco_id",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :afls,
      "LOWER(BTRIM(fco))",
      name: "index_afls_on_normalized_fco",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :afls,
      "LOWER(BTRIM(ics_id))",
      name: "index_afls_on_normalized_ics_id",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :afls,
      "LOWER(BTRIM(ics_name))",
      name: "index_afls_on_normalized_ics_name",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :afls,
      "LOWER(BTRIM(village_id))",
      name: "index_afls_on_normalized_village_id",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :afls,
      "LOWER(BTRIM(village_name))",
      name: "index_afls_on_normalized_village_name",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :farmer_farm_information,
      :created_at,
      name: "index_farmer_farm_information_on_created_at",
      order: { created_at: :desc },
      algorithm: :concurrently,
      if_not_exists: true

    add_index :ics_exit_declarations,
      :created_at,
      name: "index_ics_exit_declarations_on_created_at",
      order: { created_at: :desc },
      algorithm: :concurrently,
      if_not_exists: true
  end
end
