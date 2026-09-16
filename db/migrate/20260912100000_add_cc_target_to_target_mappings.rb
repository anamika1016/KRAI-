class AddCcTargetToTargetMappings < ActiveRecord::Migration[7.1]
  def change
    add_column :target_mappings, :cc_target, :integer, default: 0
  end
end
