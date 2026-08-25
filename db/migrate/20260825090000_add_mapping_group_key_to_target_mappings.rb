class AddMappingGroupKeyToTargetMappings < ActiveRecord::Migration[8.1]
  def change
    add_column :target_mappings, :mapping_group_key, :string
    add_index :target_mappings, :mapping_group_key
  end
end
