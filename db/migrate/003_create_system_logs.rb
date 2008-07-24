class CreateSystemLogs < ActiveRecord::Migration
  def self.up

    # system logs
    create_table :system_logs do |t|
      t.integer :owning_manager_id
      t.string :username
      t.string :level, :default => 'info' # info, warn, error
      t.text :message

      t.integer :manager_id
      t.integer :user_id
      t.integer :configuration_id
      t.integer :tacacs_daemon_id
      t.integer :configured_user_id
      t.integer :author_avpair_id
      t.integer :command_authorization_profile_id
      t.integer :network_object_group_id
      t.integer :shell_command_object_group_id
      t.integer :user_group_id
      t.integer :acl_id

      t.datetime :archived_on
      t.timestamps
    end
    add_index(:system_logs, [:archived_on, :username])

    # aaa logs
    create_table :aaa_logs do |t|
      t.integer :configuration_id
      t.datetime :timestamp
      t.string :action
      t.string :authen_method
      t.string :authen_type
      t.string :client
      t.string :client_name
      t.string :command
      t.string :flags
      t.integer :level
      t.string :message
      t.string :msg_type
      t.string :port
      t.string :priv_lvl
      t.string :rem_addr
      t.string :service
      t.string :status
      t.string :tacacs_daemon
      t.string :user
    end
    add_index(:aaa_logs, [:user, :client, :client_name])

    # aaa log archives
    create_table :aaa_log_archives do |t|
      t.integer :configuration_id
      t.string :archive_file
      t.date :archived_on
    end

    # system log archives
    create_table :system_log_archives do |t|
      t.string :archive_file
      t.date :archived_on
    end

  end

  def self.down
    begin
        FileUtils.rm( Dir.glob("#{RAILS_ROOT}/log/system_logs/*") )
    rescue Exception => error
        puts "error deleting files: #{error}"
    end

    drop_table :system_log_archives
    drop_table :aaa_log_archives
    drop_table :aaa_logs
    drop_table :system_logs
  end
end
