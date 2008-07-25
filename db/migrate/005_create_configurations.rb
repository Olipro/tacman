class CreateConfigurations < ActiveRecord::Migration
  def self.up
    #configurations
    create_table :configurations do |t|
      t.integer :department_id
      t.string :serial
      t.string :name
      t.string :default_policy, :default => 'deny' # permit, deny
      t.string :disabled_prompt
      t.string :key
      t.string :aaa_log_dir
      t.integer :log_level, :default => 2
      t.string :login_prompt
      t.string :password_expired_prompt
      t.string :password_prompt
      t.boolean :log_accounting, :default => true
      t.boolean :log_authentication, :default => true
      t.boolean :log_authorization, :default => true
      t.integer :retain_aaa_logs_for, :default => 21
      t.integer :archive_aaa_logs_for, :default => 365

      t.timestamps
    end

    # configured users
    create_table :configured_users do |t|
      t.integer :configuration_id
      t.integer :user_id
      t.string :state, :default => 'pending' #requested, approved, denied
      t.string :role, :default => 'user' #admin, viewer, user
      t.boolean :is_active, :default => false
      t.text :notes

      t.integer :author_avpair_id
      t.integer :command_authorization_profile_id
      t.integer :enable_acl_id
      t.integer :login_acl_id
      t.integer :user_group_id

      t.timestamps
    end

    # author avpairs
    create_table :author_avpairs do |t|
      t.integer :configuration_id
      t.string :name

      t.timestamps
    end

    create_table :author_avpair_entries do |t|
      t.integer :author_avpair_id
      t.integer :acl_id
      t.string :service
      t.integer :sequence

      t.timestamps
    end

    create_table :avpairs do |t|
      t.integer :author_avpair_entry_id
      t.string :attr
      t.string :val
      t.boolean :mandatory, :default => false

      t.timestamps
    end

    # command authorization profiles
    create_table :command_authorization_profiles do |t|
      t.integer :configuration_id
      t.string :name

      t.timestamps
    end

    create_table :command_authorization_profile_entries do |t|
      t.integer :command_authorization_profile_id
      t.integer :acl_id
      t.integer :shell_command_object_group_id
      t.string :command
      t.integer :sequence

      t.timestamps
    end

    # network object groups
    create_table :network_object_groups do |t|
      t.integer :configuration_id
      t.string :name

      t.timestamps
    end

    create_table :network_object_group_entries do |t|
      t.integer :network_object_group_id
      t.string :cidr
      t.integer :sequence

      t.timestamps
    end

    # shell command object groups
    create_table :shell_command_object_groups do |t|
      t.integer :configuration_id
      t.string :name

      t.timestamps
    end

    create_table :shell_command_object_group_entries do |t|
      t.integer :shell_command_object_group_id
      t.string :command
      t.integer :sequence

      t.timestamps
    end

    # acls
    create_table :acls do |t|
      t.integer :configuration_id
      t.string :name

      t.timestamps
    end

    create_table :acl_entries do |t|
      t.integer :acl_id
      t.integer :network_object_group_id
      t.string :ip
      t.string :permission
      t.string :wildcard_mask
      t.integer :sequence
      t.string :comment

      t.timestamps
    end

    # user groups
    create_table :user_groups do |t|
      t.integer :configuration_id
      t.string :name
      t.integer :author_avpair_id
      t.integer :command_authorization_profile_id
      t.integer :enable_acl_id
      t.integer :login_acl_id

      t.timestamps
    end

    # whitelists
    create_table :command_authorization_whitelist_entries do |t|
      t.integer :configuration_id
      t.integer :acl_id
      t.integer :shell_command_object_group_id
      t.string :command
      t.integer :sequence

      t.timestamps
    end

  end

  def self.down
    begin
        FileUtils.rm_r( Dir.glob("#{RAILS_ROOT}/log/aaa_logs/*") )
    rescue Exception => error
        puts "error deleting configuration files: #{error}"
    end

    drop_table :command_authorization_whitelist_entries
    drop_table :user_groups
    drop_table :acl_entries
    drop_table :acls
    drop_table :shell_command_object_group_entries
    drop_table :shell_command_object_groups
    drop_table :network_object_group_entries
    drop_table :network_object_groups
    drop_table :command_authorization_profile_entries
    drop_table :command_authorization_profiles
    drop_table :avpairs
    drop_table :author_avpair_entries
    drop_table :author_avpairs
    drop_table :configured_users
    drop_table :configurations
  end
end
