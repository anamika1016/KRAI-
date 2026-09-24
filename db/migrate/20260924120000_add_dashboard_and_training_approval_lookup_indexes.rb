class AddDashboardAndTrainingApprovalLookupIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # The Other dashboard aggregates all ModuleRecord slugs by normalized month.
    # A global expression index supports that existing filter without narrowing its data scope.
    add_index :module_records,
      "LOWER(BTRIM((data::jsonb ->> 'month')))",
      name: "index_module_records_on_normalized_month_all",
      algorithm: :concurrently,
      if_not_exists: true

    # Dashboard and mobile reporting always narrow training rows by month and main activity.
    add_index :module_records,
      "LOWER(BTRIM((data::jsonb ->> 'month'))), LOWER(BTRIM(COALESCE((data::jsonb ->> 'main_activity'), '')))",
      name: "index_training_forms_on_month_and_main_activity",
      where: "module_slug = 'training-form'",
      algorithm: :concurrently,
      if_not_exists: true

    # The training list displays the latest revision for each training form, regardless of status.
    add_index :module_records,
      [:module_slug, :id],
      order: { id: :desc },
      name: "index_training_edit_requests_on_slug_and_id",
      where: "module_slug = 'training-form-edit-request'",
      algorithm: :concurrently,
      if_not_exists: true

    # Sidebar pending badges and the approval list read pending revisions in newest-first order.
    add_index :module_records,
      :id,
      order: { id: :desc },
      name: "index_training_edit_requests_on_pending_id",
      where: "module_slug = 'training-form-edit-request' AND data::jsonb ->> 'status' = 'Pending'",
      algorithm: :concurrently,
      if_not_exists: true

    # Editing a training form looks up its pending revision by record_id.
    add_index :module_records,
      "(data::jsonb ->> 'record_id')",
      name: "index_training_edit_requests_on_pending_record_id",
      where: "module_slug = 'training-form-edit-request' AND data::jsonb ->> 'status' = 'Pending'",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
