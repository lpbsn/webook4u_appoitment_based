class RemoveFullAddressFromEnseignes < ActiveRecord::Migration[8.1]
  def up
    remove_column :enseignes, :full_address, :string
  end

  def down
    add_column :enseignes, :full_address, :string
  end
end
