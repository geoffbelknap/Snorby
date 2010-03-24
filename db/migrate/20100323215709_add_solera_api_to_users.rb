class AddSoleraApiToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :solera_api_user, :string
    add_column :users, :solera_api_pass, :string
    add_column :users, :solera_api_enabled, :integer
  end

  def self.down
    remove_column :users, :solera_api_pass
    remove_column :users, :solera_api_user
    remove_column :users, :solera_api_enabled
  end
end
