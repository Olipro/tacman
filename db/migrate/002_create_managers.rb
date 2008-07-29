class CreateManagers < ActiveRecord::Migration
  def self.up

    # locks
    create_table :locks do |t|
      t.integer :manager_id
      t.integer :tacacs_daemon_id
      t.integer :configuration_id
      t.string :lock_type
      t.datetime :expires_at
    end

    # system system_revisions
    create_table :system_revisions do |t|
      t.integer :manager_id
      t.string :queue # inbox, outbox
      t.integer :revision
    end

    # managers
    create_table :managers do |t|
      t.boolean :is_approved, :default => false
      t.boolean :is_enabled, :default => false
      t.boolean :is_local, :default => false
      t.boolean :in_maintenance_mode, :default => false

      t.string :base_url
      t.string :manager_type, :default => 'stand_alone' # master, slave, stand_alone
      t.string :name
      t.string :password
      t.string :serial
      t.string :disabled_message, :default => 'pending approval from master system.'

      # settings
      t.integer :pagination_per_page
      t.integer :retain_system_logs_for
      t.integer :archive_system_logs_for
      t.integer :disable_inactive_users_after

      t.integer :default_enable_password_lifespan
      t.integer :default_login_password_lifespan
      t.integer :password_history_length
      t.integer :password_minimum_length
      t.boolean :password_require_mixed_case
      t.boolean :password_require_alphanumeric

      t.integer :maximum_network_object_group_length
      t.integer :maximum_acl_length
      t.integer :maximum_aaa_log_retainment
      t.integer :maximum_aaa_archive_retainment

      t.boolean :enable_mailer
      t.text :mail_account_disabled
      t.text :mail_new_account
      t.text :mail_password_expired
      t.text :mail_password_reset
      t.text :mail_pending_password_expiry

      t.timestamps
    end

    # local manager
    manager = Manager.new()
    manager.name = "Manager#{Time.now.strftime("%Y%m%d%H%M%S")}"
    manager.is_local = true
    manager.save

    # system messages
    create_table :system_messages do |t|
      t.integer :manager_id
      t.string :queue # inbox, outbox, unprocessable
      t.string :verb # save, destroy
      t.integer :revision
      t.string :content_file
      t.text :error_log

      t.timestamps
    end



  end

  def self.down
    begin
        FileUtils.rm( Dir.glob("#{RAILS_ROOT}/tmp/system_messages/*") )
    rescue Exception => error
        puts "error deleting system_message files: #{error}"
    end

    drop_table :system_messages
    drop_table :managers
    drop_table :system_revisions
    drop_table :locks
  end
end
