class AddStructuredAddressFieldsToEnseignes < ActiveRecord::Migration[8.1]
  def change
    add_column :enseignes, :address, :string
    add_column :enseignes, :postal_code, :string
    add_column :enseignes, :city, :string
    add_column :enseignes, :country, :string
  end
end
