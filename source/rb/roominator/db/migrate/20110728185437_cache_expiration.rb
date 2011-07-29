class CacheExpiration < ActiveRecord::Migration
  def self.up
    add_column :rooms, :last_refresh, :integer
  end

  def self.down
    remove_column :rooms, :last_refresh
  end
end
