class AddDashboardSummaryPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :target_mappings,
      [:month_name, :main_activity_name, :activity_name],
      name: "index_target_mappings_on_month_and_activities",
      if_not_exists: true

    add_index :target_mappings,
      [:vrp_id, :month_name, :main_activity_name, :activity_name],
      name: "index_target_mappings_on_vrp_month_and_activities",
      if_not_exists: true

    add_index :target_mappings,
      [:fco_id, :month_name],
      name: "index_target_mappings_on_fco_and_month",
      if_not_exists: true

    add_index :target_mappings,
      [:fco_name, :month_name],
      name: "index_target_mappings_on_fco_name_and_month",
      if_not_exists: true

    add_index :target_mappings,
      [:ics_id, :month_name],
      name: "index_target_mappings_on_ics_and_month",
      if_not_exists: true

    add_index :target_mappings,
      [:ics_name, :month_name],
      name: "index_target_mappings_on_ics_name_and_month",
      if_not_exists: true

    add_index :module_records,
      "(data::jsonb ->> 'target_mapping_id')",
      name: "index_module_records_other_targets_on_target_mapping_id",
      where: "module_slug IN ('seed-distribution-target', 'papl360-target')",
      if_not_exists: true
  end
end
