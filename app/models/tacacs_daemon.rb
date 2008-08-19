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
    validates_uniqueness_of :port, :scope => [:manager_id, :ip], :message => "IP/port combination must be unique."


    before_validation_on_create :name_lookup
    after_create :setup
    after_create :create_locks
    after_destroy :destroy_on_remote_managers!
    after_destroy :cleanup
    after_update :update_on_remote_managers!



    # expects comma delimited string with fields:
    #name,manager,configuration,ip,port
    # return hash of errors by name
    def TacacsDaemon.import(data)
        errors = {}
        name = nil
        managers = {}
        configurations = {}
        Manager.find(:all).each {|x| managers[x.name] = x.id}
        Configuration.find(:all).each {|x| configurations[x.name] = x.id}
        begin
            TacacsDaemon.transaction do
                data.each_line do |line|
                    next if (line.blank?)
                    name,manager,configuration,ip,port = line.split(",")
                    td = TacacsDaemon.new
                    td.name = name.strip if (name)
                    td.ip = ip.strip if (ip)
                    td.port = port.to_i if (port)

                    if (manager)
                        manager.strip!
                        td.manager_id = managers[manager] if ( managers.has_key?(manager) )
                    end

                    if (configuration)
                        configuration.strip!
                        td.configuration_id = configurations[configuration] if ( configurations.has_key?(configuration) )
                    end

                    if (!td.save)
                        errors[name] = td.errors.full_messages
                        raise
                    end
                end
            end
        rescue
        end

        return(errors)
    end



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
        return(false) if (self.aaa_file_locked? || !self.configuration_id)
        self.lock_aaa_file(3600) # 60 min lock

        # return if aaa_log_file contains no data
        begin
            if ( !File.exists?(self.aaa_log_file) || File.zero?(self.aaa_log_file) )
                self.unlock_aaa_file()
                return(false)
            end
        rescue Exception => error
            self.errors.add_to_base("Error checking aaa_log_file size: #{error}")
            self.unlock_aaa_file()
            return(false)
        end

        # move aaa_log to aaa_scratch
        begin
            FileUtils.mv(self.aaa_log_file, self.aaa_scratch_file)
            FileUtils.touch(self.aaa_log_file)
        rescue Exception => error
            self.errors.add_to_base("Error rotating aaa_log_file: #{error}")
            self.unlock_aaa_file()
            return(false)
        end

        # read aaa_scratch
        log = ''
        begin
            file = File.open(self.aaa_scratch_file)
        rescue Exception => error
            self.errors.add_to_base("Error reading aaa_scratch_file: #{error}")
            FileUtils.mv(self.aaa_scratch_file, self.aaa_log_file, :force => true)
            self.unlock_aaa_file()
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

        # import logs directly for master systems, place into system_message for slaves
        master = Manager.find(:first, :conditions => "manager_type = 'master'") if (Manager.local.slave?)
        configuration = self.configuration
        eof = false
        while(1)
            logs = ''
            begin
                10000.times {logs << file.readline}
            rescue EOFError
                eof = true
            rescue Exception => error
                self.errors.add_to_base("Error processing aaa_scratch_file. Cannot continue. Error: #{error}")
                self.unlock_aaa_file()
                return(false)
            end

            if (logs.length > 0 )
                if (master)
                    aaa_xml = REXML::Element.new("aaa-logs")
                    id = REXML::Element.new("id")
                    id.add_attribute('type', 'integer')
                    id.text = configuration.id
                    log = REXML::Element.new("log")
                    log.add_attribute('type', 'string')
                    log.text = logs
                    aaa_xml.add_element(id)
                    aaa_xml.add_element(log)
                    master.add_to_outbox('create', aaa_xml.to_s)

                else
                    configuration.import_aaa_logs(logs)
                    if (configuration.errors.length > 0)
                        configuration.errors.each_full {|e| self.errors.add_to_base("AAA log import error: #{e}")}
                    end
                end
            end
            break if (eof)
        end

        self.unlock_aaa_file()
        return(true)
    end

    def migrate(manager)
        orig_manager = self.manager_id
        begin
            TacacsDaemon.transaction do
                if (self.local?)
                    cleanup
                else
                    destroy_on_remote_managers!
                end
                manager.add_to_outbox('create', self.export_xml ) if (!manager.is_local)

                if (!manager.is_local)
                    self.manager_id = manager.id
                    m_id = manager.id
                else
                    self.manager_id = nil
                    m_id = 'null'
                end

                raise("validation failure") if (!self.valid?)
                TacacsDaemon.update_all("manager_id = #{m_id}", "id = #{self.id}")
            end
        rescue Exception => error
            self.manager_id = orig_manager
            self.errors.add_to_base("Migration failed: #{error}")
            return(false)
        end

        return(true)
    end

    def local?
        return(true) if (!self.manager_id)
        return(false)
    end

    def lock_aaa_file(seconds)
        self.aaa_lock.update_attribute(:expires_at, Time.now + seconds)
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
            `ruby #{RAILS_ROOT}/lib/tacacs_plus_server.rb --pid_file #{self.pid_file} --error_log #{self.error_log_file} --log_file #{self.aaa_log_file} --conf_file #{self.configuration_file} --start`
        end

        sleep(1)
        if (self.running?)
            started = true
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
            rescue Errno::ESRCH => error
                self.errors.add_to_base("Could not stop daemon. #{error}")
            end
        end

        return(stopped)
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

    def export_xml
        self.to_xml(:skip_instruct => true, :only => [:id, :serial, :configuration_id, :name, :ip, :port, :max_clients, :sock_timeout])
    end

private

    def cleanup
        if (self.local?)
            self.stop if (self.running?)
            self.gather_aaa_logs!
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
        end
    end

    def create_on_remote_managers!
        if (!self.local?)
            self.manager.add_to_outbox('create', self.export_xml )
        end
    end

    def name_lookup
        if (self.name.blank?)
            begin
                self.name = Resolv.getname(self.ip)
            rescue Exception
                self.name = self.ip
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
        create_on_remote_managers!
        self.save
        self.start if (self.local? && self.desire_start)
    end

    def update_on_remote_managers!
        if (!self.local?)
            self.manager.add_to_outbox('update', self.export_xml )
        end
    end

end
