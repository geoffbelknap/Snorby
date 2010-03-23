class AddSoleraApiToSensors < ActiveRecord::Migration
  def self.up
    add_column :sensors, :solera_api_host, :string
  end

  def self.down
    remove_column :sensors, :solera_api_host
  end
end
