class TacacsDaemon < ActiveRecord::Base
    attr_protected  :configuration_file, :error_log_file, :aaa_log_file, :aaa_scratch_file, :pid_file, :manager_id, :serial
    attr_writer :status

    belongs_to :configuration
    belongs_to :manager
    has_many :system_logs, :dependent => :nullify, :order => :id
    has_one :aaa_lock, :class_name => 'Lock', :conditions => "lock_type = 'aaa'", :dependent => :destroy


    validates_presence_of :ip
    validates_presence_of :name
    validates_uniqueness_of :name
    validates_inclusion_of :port, :in => (1..65535)


    after_create :setup
    after_create :create_locks
    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_destroy :cleanup
    after_update :update_on_remote_managers!


    def aaa_file_locked?
        return(true) if (self.aaa_lock.active?)
        return(false)
    end

    def aaa_log
        if (local?)
            log = ''
            begin
                if ( File.exists?(self.aaa_log_file) )
                    file = File.open(self.aaa_log_file)
                    log = file.read
                    file.close
                else
                    log = ''
                end
            rescue Exception => error
                self.errors.add_to_base("Error reading aaa_log_file: #{error}")
            end

        else
            manager = self.manager
            log = manager.read_remote_log_file(self,'aaa')
            if (manager.errors.length != 0)
                log = ''
                self.errors.add_to_base("Error collecting remote log.")
                manager.errors.each_full {|e| self.errors.add_to_base(e) }
            end
        end

        return(log)
    end

    def clear_error_log!
        if (!local?)
            self.errors.add_to_base("Action prohibited on a non-local TACACS+ Daemon.")
            return(false)
        end

        begin
            File.open(self.error_log_file, 'w').close
        rescue Exception => error
            self.errors.add_to_base("Error clearing error_log_file: #{error}")
            return(false)
        end
        return(true)
    end

    def down!
        self.is_down = true
        self.save
    end

    def error_log
        if (local?)
            log = ''
            begin
                if (File.size(self.error_log_file) < 1000000)
                    file = File.open(self.error_log_file)
                    log = file.read
                    file.close
                else
                    log = "Error log too large"
                end
            rescue Exception => error
                self.errors.add_to_base("Error reading error_log file: #{error}")
            end

        else
            manager = self.manager
            log = manager.read_remote_log_file(self,'error')
            if (manager.errors.length != 0)
                log = ''
                self.errors.add_to_base("Error collecting remote log.")
                manager.errors.each_full {|e| self.errors.add_to_base(e) }
            end
        end

        return(log)
    end

    def gather_aaa_logs!
        return(false) if (self.aaa_file_locked?)
        self.lock_aaa_file(600) # 10 min lock

        # move aaa_log to aaa_scratch
        begin
            FileUtils.mv(self.aaa_log_file, self.aaa_scratch_file) if ( File.exists?(self.aaa_log_file) )
        rescue Exception => error
            self.errors.add_to_base("Error rotating aaa_log_file: #{error}")
            self.update_attribute(:aaa_logs_locked_until, nil)
            return(false)
        end

        # reload daemon if running
        if (self.running?)
            begin
                Process.kill('HUP', self.pid)
            rescue Errno::ESRCH => error
                self.errors.add_to_base("Reload failed. #{error}")
            end
        end

        # read aaa_scratch
        log = ''
        begin
            if ( File.exists?(self.aaa_scratch_file) )
                file = File.open(self.aaa_scratch_file)
                log = file.read
                file.close
            end
        rescue Exception => error
            self.errors.add_to_base("Error reading aaa_scratch_file: #{error}")
            FileUtils.mv(self.aaa_scratch_file, self.aaa_log_file, :force => true)
            self.update_attribute(:aaa_logs_locked_until, nil)
            return(false)
        end

        if (log.length > 0 && self.configuration_id)
            # if slave put scratch_log_file into message for master, else import into db
            if (Manager.local.slave?)
                master = Manager.find(:first, :conditions => "manager_type = 'master'")
                master.add_to_outbox('create', "<aaa-logs>\n  <id type=\"integer\">#{self.configuration_id}</id>\n  <log type=\"string\">\n#{log}</log>\n</aaa-logs>\n" )
            else
                configuration = self.configuration
                configuration.import_aaa_logs(log)
                if (configuration.errors.length > 0)
                    configuration.errors.each_full {|e| self.errors.add_to_base("Error writing logs to configuration: #{e}") }
                end
            end
        end

        self.unlock_aaa_file()
        return(true)
    end

    def local?
        return(true) if (!self.manager_id)
        return(false)
    end

    def lock_aaa_file(seconds)
        self.aaa_lock.update_attribute(:expires_at, Time.now + seconds)
    end

    def monitor_on!
        if (!self.is_monitored)
            self.is_monitored = true
            self.save
        end
    end

    def monitor_off!
        if (self.is_monitored)
            self.is_monitored = false
            self.save
        end
    end

    def pid
        if (!local?)
            self.errors.add_to_base("Action prohibited on a non-local TACACS+ Daemon.")
            return(nil)
        end

        my_pid = nil
        begin
            if ( File.exists?(self.pid_file) )
                file = File.open(self.pid_file)
                my_pid = file.readline.to_i
                file.close
            end
        rescue Exception => error
            self.errors.add_to_base("Error reading PID file: #{error}")
        end
        return(my_pid)
    end

    def reload_server
        if (!local?)
            self.errors.add_to_base("Action prohibited on a non-local TACACS+ Daemon.")
            return(false)
        end

        reloaded = false
        if (self.running?)
            begin
                Process.kill('HUP', self.pid)
                reloaded = true
            rescue Errno::ESRCH => error
                self.errors.add_to_base("Reload failed. #{error}")
            end
        end
        return(reloaded)
    end

    def restart
        if (!local?)
            self.errors.add_to_base("Action prohibited on a non-local TACACS+ Daemon.")
            return(false)
        end

        started = false
        started = self.start if (self.running? && self.stop)
        return(started)
    end

    def running?
        if (!local?)
            self.errors.add_to_base("Action prohibited on a non-local TACACS+ Daemon.")
            return(false)
        end

        is_running = true

        if (self.pid)
            begin
                Process.kill(0, self.pid)
            rescue Errno::ESRCH
                is_running = false
            end
        else
            is_running = false
        end
        return(is_running)
    end

    def start
        if (!self.local?)
            self.errors.add_to_base("Action prohibited on a non-local TACACS+ Daemon.")
            return(false)
        end

        if (!self.configuration_id)
            self.errors.add_to_base("Cannot Start. No Configuration has been provided.")
            return(false)
        end

        started = false

        if (self.running?)
            self.errors.add_to_base("Failed to initialize TACACS+ server. Server is already running with PID #{self.pid}.")
            return(false)
        else
            self.write_config_file
            child_pid = Process.fork do
                Process.setsid

                # have to do this to stop this proccess from inheriting the open
                # TCPServer IO from mongrel
                ObjectSpace.each_object(TCPSocket) {|sock| sock.reopen('/dev/null', 'r'); sock.close}

                exec "ruby #{RAILS_ROOT}/lib/tacacs_plus_server.rb --pid_file #{self.pid_file} --error_log #{self.error_log_file} " +
                    "--log_file #{self.aaa_log_file} --conf_file #{self.configuration_file} --start"
            end
            Process.wait(child_pid)
        end

        sleep(1)
        if (self.running?)
            started = true
            self.monitor_on!
        else
            self.errors.add_to_base("TACACS+ server failed to start. See error log.")
        end

        return(started)
    end

    def status
        if (self.local?)
            if (self.errors.length > 0)
                return('error')
            elsif (self.running?)
                return('running')
            else
                return('stopped')
            end
        else
            if (@status)
                return(@status)
            else
                return('unknown')
            end
        end
    end

    def stop
        if (!self.local?)
            self.errors.add_to_base("Action prohibited on a non-local TACACS+ Daemon.")
            return(false)
        end

        stopped = false
        if(!self.running?)
            self.errors.add_to_base("Could not stop daemon. No registered PID or daemon not running.")
        else
            begin
                Process.kill('INT', self.pid)
                sleep(1)
                stopped = true
                self.monitor_off!
            rescue Errno::ESRCH => error
                self.errors.add_to_base("Could not stop daemon. #{error}")
            end
        end

        return(stopped)
    end

    def up!
        self.is_down = false
        self.save
    end

    def unlock_aaa_file()
        self.aaa_lock.update_attribute(:expires_at, nil)
    end

    def write_config_file
        if (!self.local?)
            self.errors.add_to_base("Action prohibited on a non-local TACACS+ Daemon.")
            return(false)
        end

        written = true
        begin
            file = File.open(self.configuration_file, 'w')
            file.print(self.yaml_config)
            file.close
        rescue Exception => error
            written = false
            self.errors.add_to_base("Error writing config file: #{error}")
        end
        return(written)
    end

    def yaml_config
        if (self.configuration)
            config = self.configuration.configuration_hash
        else
            config = {:tacacs_daemon => {}}
        end
        my_attrs = {:ip => self.ip, :name => self.name}
        my_attrs[:port] = self.port if (!self.port.blank?)
        my_attrs[:key] = self.name if ( !config[:tacacs_daemon].has_key?(:key) )
        my_attrs[:max_clients] = self.max_clients if (self.max_clients)
        my_attrs[:sock_timeout] = self.sock_timeout if (self.sock_timeout)

        config[:tacacs_daemon].merge!(my_attrs)
        return(config.to_yaml)
    end


private

    def cleanup
        if (self.local?)
            self.stop if (self.running?)
            begin
                File.delete(self.configuration_file) if ( File.exists?(self.configuration_file) )
                File.delete(self.error_log_file) if ( File.exists?(self.error_log_file) )
                File.delete(self.pid_file) if ( File.exists?(self.pid_file) )
                File.delete(self.aaa_log_file) if ( File.exists?(self.aaa_log_file) )
                File.delete(self.aaa_scratch_file) if ( File.exists?(self.aaa_scratch_file) )
            rescue Exception => err
                self.errors.add_to_base("Error removing files: #{err}")
            end
        end
    end

    def create_locks
        self.create_aaa_lock(:lock_type => 'aaa')
    end

    def destroy_on_remote_managers!
        if (!self.local?)
            self.manager.add_to_outbox('destroy', self.to_xml(:skip_instruct => true, :only => :id) )
            begin
                MiddleMan.worker(:queue_worker).async_write_remote(:arg => self.manager_id)
            rescue Exception => error
                self.errors.add_to_base("Publishing error: #{error}")
            end
        end
    end

    def create_on_remote_managers!
        if (!self.local?)
            self.manager.add_to_outbox('create', self.to_xml(:skip_instruct => true,
                                       :only => [:id, :configuration_id, :name, :ip, :port, :max_clients, :sock_timeout]) )
            begin
                MiddleMan.worker(:queue_worker).async_write_remote(:arg => self.manager_id)
            rescue Exception => error
                self.errors.add_to_base("Publishing error: #{error}")
            end
        end
    end


    def setup
        self.serial = Time.now.strftime("%Y%m%d-%H%M%S-") << self.id.to_s
        self.error_log_file = File.expand_path("#{RAILS_ROOT}/log/tacacs_daemon_error_logs/") + "/#{self.serial}"
        self.pid_file = File.expand_path("#{RAILS_ROOT}/tmp/pids/tacacs_daemon_pid_files/") + "/#{self.serial}"
        self.configuration_file = File.expand_path("#{RAILS_ROOT}/tmp/configurations/") + "/#{self.serial}"
        self.aaa_log_file = File.expand_path("#{RAILS_ROOT}/tmp/aaa_logs/") + "/#{self.serial}"
        self.aaa_scratch_file = File.expand_path("#{RAILS_ROOT}/tmp/aaa_logs_scratch/") + "/#{self.serial}"
        self.save
    end

    def update_on_remote_managers!
        if (!self.local?)
            self.manager.add_to_outbox('update', self.to_xml(:skip_instruct => true,
                                       :only => [:id, :configuration_id, :name, :ip, :port, :max_clients, :sock_timeout]) )
            begin
                MiddleMan.worker(:queue_worker).async_write_remote(:arg => self.manager_id)
            rescue Exception => error
                self.errors.add_to_base("Publishing error: #{error}")
            end
        end
    end

end
