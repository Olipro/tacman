# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 6) do

  create_table "aaa_log_archives", :force => true do |t|
    t.integer "configuration_id", :limit => 11
    t.string  "archive_file"
    t.date    "archived_on"
  end

  create_table "aaa_logs", :force => true do |t|
    t.integer  "configuration_id", :limit => 11
    t.datetime "timestamp"
    t.string   "action"
    t.string   "authen_method"
    t.string   "authen_type"
    t.string   "client"
    t.string   "client_name"
    t.string   "command"
    t.string   "flags"
    t.integer  "level",            :limit => 11
    t.string   "message"
    t.string   "msg_type"
    t.string   "port"
    t.string   "priv_lvl"
    t.string   "rem_addr"
    t.string   "service"
    t.string   "status"
    t.string   "tacacs_daemon"
    t.string   "user"
  end

  add_index "aaa_logs", ["user", "client", "client_name"], :name => "index_aaa_logs_on_user_and_client_and_client_name"

  create_table "acl_entries", :force => true do |t|
    t.integer  "acl_id",                  :limit => 11
    t.integer  "network_object_group_id", :limit => 11
    t.string   "ip"
    t.string   "permission"
    t.string   "wildcard_mask"
    t.integer  "sequence",                :limit => 11
    t.string   "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "acls", :force => true do |t|
    t.integer  "configuration_id", :limit => 11
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "author_avpair_entries", :force => true do |t|
    t.integer  "author_avpair_id", :limit => 11
    t.integer  "acl_id",           :limit => 11
    t.string   "service"
    t.integer  "sequence",         :limit => 11
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "author_avpairs", :force => true do |t|
    t.integer  "configuration_id", :limit => 11
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "avpairs", :force => true do |t|
    t.integer  "author_avpair_entry_id", :limit => 11
    t.string   "attr"
    t.string   "val"
    t.boolean  "mandatory",                            :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "command_authorization_profile_entries", :force => true do |t|
    t.integer  "command_authorization_profile_id", :limit => 11
    t.integer  "acl_id",                           :limit => 11
    t.integer  "shell_command_object_group_id",    :limit => 11
    t.string   "command"
    t.integer  "sequence",                         :limit => 11
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "command_authorization_profiles", :force => true do |t|
    t.integer  "configuration_id", :limit => 11
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "command_authorization_whitelist_entries", :force => true do |t|
    t.integer  "configuration_id",              :limit => 11
    t.integer  "acl_id",                        :limit => 11
    t.integer  "shell_command_object_group_id", :limit => 11
    t.string   "command"
    t.integer  "sequence",                      :limit => 11
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "configurations", :force => true do |t|
    t.integer  "department_id",           :limit => 11
    t.string   "serial"
    t.string   "name"
    t.string   "default_policy",                        :default => "deny"
    t.string   "disabled_prompt"
    t.string   "key"
    t.string   "aaa_log_dir"
    t.integer  "log_level",               :limit => 11, :default => 2
    t.string   "login_prompt"
    t.string   "password_expired_prompt"
    t.string   "password_prompt"
    t.boolean  "log_accounting",                        :default => true
    t.boolean  "log_authentication",                    :default => true
    t.boolean  "log_authorization",                     :default => true
    t.integer  "retain_aaa_logs_for",     :limit => 11
    t.integer  "archive_aaa_logs_for",    :limit => 11
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "configured_users", :force => true do |t|
    t.integer  "configuration_id",                 :limit => 11
    t.integer  "user_id",                          :limit => 11
    t.string   "role",                                           :default => "user"
    t.boolean  "is_active",                                      :default => false
    t.text     "notes"
    t.integer  "author_avpair_id",                 :limit => 11
    t.integer  "command_authorization_profile_id", :limit => 11
    t.integer  "enable_acl_id",                    :limit => 11
    t.integer  "login_acl_id",                     :limit => 11
    t.integer  "user_group_id",                    :limit => 11
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "departments", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "locks", :force => true do |t|
    t.integer  "manager_id",       :limit => 11
    t.integer  "tacacs_daemon_id", :limit => 11
    t.integer  "configuration_id", :limit => 11
    t.string   "lock_type"
    t.datetime "expires_at"
  end

  create_table "managers", :force => true do |t|
    t.boolean  "is_approved",                                       :default => false
    t.boolean  "is_enabled",                                        :default => false
    t.boolean  "is_local",                                          :default => false
    t.boolean  "in_maintenance_mode",                               :default => false
    t.string   "base_url"
    t.string   "manager_type",                                      :default => "stand_alone"
    t.string   "name"
    t.string   "password"
    t.string   "serial"
    t.string   "disabled_message",                                  :default => "pending approval from master system."
    t.integer  "pagination_per_page",                 :limit => 11
    t.integer  "retain_system_logs_for",              :limit => 11
    t.integer  "archive_system_logs_for",             :limit => 11
    t.integer  "disable_inactive_users_after",        :limit => 11
    t.integer  "default_enable_password_lifespan",    :limit => 11
    t.integer  "default_login_password_lifespan",     :limit => 11
    t.integer  "password_history_length",             :limit => 11
    t.integer  "password_minimum_length",             :limit => 11
    t.boolean  "password_require_mixed_case"
    t.boolean  "password_require_alphanumeric"
    t.integer  "maximum_network_object_group_length", :limit => 11
    t.integer  "maximum_acl_length",                  :limit => 11
    t.integer  "maximum_aaa_log_retainment",          :limit => 11
    t.integer  "maximum_aaa_archive_retainment",      :limit => 11
    t.boolean  "enable_mailer"
    t.string   "mail_from",                                         :default => "noreply@localhost.localdomain"
    t.text     "mail_account_disabled"
    t.text     "mail_new_account"
    t.text     "mail_password_expired"
    t.text     "mail_password_reset"
    t.text     "mail_pending_password_expiry"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "network_object_group_entries", :force => true do |t|
    t.integer  "network_object_group_id", :limit => 11
    t.string   "cidr"
    t.integer  "sequence",                :limit => 11
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "network_object_groups", :force => true do |t|
    t.integer  "configuration_id", :limit => 11
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "password_histories", :force => true do |t|
    t.integer  "user_id",       :limit => 11
    t.boolean  "is_enable",                   :default => false
    t.string   "password_hash"
    t.date     "expires_on"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "sessions", :force => true do |t|
    t.string   "session_id", :default => "", :null => false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "shell_command_object_group_entries", :force => true do |t|
    t.integer  "shell_command_object_group_id", :limit => 11
    t.string   "command"
    t.integer  "sequence",                      :limit => 11
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "shell_command_object_groups", :force => true do |t|
    t.integer  "configuration_id", :limit => 11
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "system_log_archives", :force => true do |t|
    t.string "archive_file"
    t.date   "archived_on"
  end

  create_table "system_logs", :force => true do |t|
    t.integer  "owning_manager_id",                :limit => 11
    t.string   "username"
    t.string   "level",                                          :default => "info"
    t.text     "message"
    t.integer  "manager_id",                       :limit => 11
    t.integer  "user_id",                          :limit => 11
    t.integer  "configuration_id",                 :limit => 11
    t.integer  "department_id",                    :limit => 11
    t.integer  "tacacs_daemon_id",                 :limit => 11
    t.integer  "configured_user_id",               :limit => 11
    t.integer  "author_avpair_id",                 :limit => 11
    t.integer  "command_authorization_profile_id", :limit => 11
    t.integer  "network_object_group_id",          :limit => 11
    t.integer  "shell_command_object_group_id",    :limit => 11
    t.integer  "user_group_id",                    :limit => 11
    t.integer  "acl_id",                           :limit => 11
    t.datetime "archived_on"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "system_logs", ["archived_on", "username"], :name => "index_system_logs_on_archived_on_and_username"

  create_table "system_messages", :force => true do |t|
    t.integer  "manager_id",   :limit => 11
    t.string   "queue"
    t.string   "verb"
    t.integer  "revision",     :limit => 11
    t.string   "content_file"
    t.text     "error_log"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "system_revisions", :force => true do |t|
    t.integer "manager_id", :limit => 11
    t.string  "queue"
    t.integer "revision",   :limit => 11
  end

  create_table "tacacs_daemons", :force => true do |t|
    t.integer  "manager_id",         :limit => 11
    t.integer  "configuration_id",   :limit => 11
    t.boolean  "desire_start",                     :default => false
    t.string   "aaa_log_file"
    t.string   "aaa_scratch_file"
    t.string   "configuration_file"
    t.string   "error_log_file"
    t.string   "pid_file"
    t.string   "serial"
    t.string   "name"
    t.string   "ip"
    t.integer  "port",               :limit => 11, :default => 4949
    t.integer  "max_clients",        :limit => 11, :default => 30
    t.integer  "sock_timeout",       :limit => 11, :default => 100
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "user_groups", :force => true do |t|
    t.integer  "configuration_id",                 :limit => 11
    t.string   "name"
    t.integer  "author_avpair_id",                 :limit => 11
    t.integer  "command_authorization_profile_id", :limit => 11
    t.integer  "enable_acl_id",                    :limit => 11
    t.integer  "login_acl_id",                     :limit => 11
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "user_last_logins", :force => true do |t|
    t.integer  "user_id",       :limit => 11
    t.datetime "last_login_at"
  end

  create_table "users", :force => true do |t|
    t.integer  "department_id",            :limit => 11
    t.boolean  "allow_web_login",                        :default => true
    t.boolean  "disable_aaa_log_import",                 :default => false
    t.boolean  "disabled",                               :default => false
    t.string   "email"
    t.integer  "enable_password_lifespan", :limit => 11
    t.integer  "login_password_lifespan",  :limit => 11
    t.text     "notes"
    t.string   "real_name"
    t.string   "role",                                   :default => "user"
    t.string   "salt"
    t.string   "username"
    t.integer  "password_history_length",  :limit => 11
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
