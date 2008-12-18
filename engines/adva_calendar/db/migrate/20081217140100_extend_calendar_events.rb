class ExtendCalendarEvents < ActiveRecord::Migration
  def self.up
    change_column :calendar_events, :location_id, :string, :nil => false
    add_column :calendar_events, :recurrence, :string
  end

  def self.down
    remove_column :table_name, :column_name
  end
end