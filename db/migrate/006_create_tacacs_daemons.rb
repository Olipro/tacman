class CreateTacacsDaemons < ActiveRecord::Migration
  def self.up
    create_table :tacacs_daemons do |t|
      t.integer :manager_id
      t.integer :configuration_id

      t.string :aaa_log_file
      t.string :aaa_scratch_file
      t.string :configuration_file
      t.string :error_log_file
      t.string :pid_file

      t.string :serial
      t.string :name
      t.string :ip
      t.boolean :is_monitored, :default => false
      t.boolean :is_down, :default => true
      t.integer :port, :default => 4949
      t.integer :max_clients, :default => 30
      t.integer :sock_timeout, :default => 100

      t.timestamps
    end
  end

  def self.down
    begin
        FileUtils.rm( Dir.glob("#{RAILS_ROOT}/log/tacacs_daemon_error_logs/*") )
        FileUtils.rm( Dir.glob("#{RAILS_ROOT}/tmp/configurations/*") )
        FileUtils.rm( Dir.glob("#{RAILS_ROOT}/tmp/aaa_logs/*") )
        FileUtils.rm( Dir.glob("#{RAILS_ROOT}/tmp/aaa_logs_scratch/*") )
    rescue Exception => error
        puts "error deleting tacacs_daemon files: #{error}"
    end
    drop_table :tacacs_daemons
  end
end
