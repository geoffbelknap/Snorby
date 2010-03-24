class AddSoleraApiToSensor < ActiveRecord::Migration
  def self.up
    add_column :sensor, :solera_api_host, :string
  end

  def self.down
    remove_column :sensor, :solera_api_host
  end
end
