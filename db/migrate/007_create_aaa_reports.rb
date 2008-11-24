class CreateAaaReports < ActiveRecord::Migration
  def self.up
    create_table :aaa_reports do |t|
      t.integer :configuration_id
      t.string :name
      t.boolean :enable_notifications

      t.string :client
      t.string :client_name
      t.string :command
      t.string :message
      t.string :msg_type
      t.string :status
      t.string :user

      t.timestamps
    end
  end

  def self.down
    drop_table :aaa_reports
  end
end
