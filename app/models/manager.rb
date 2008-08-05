class Manager < ActiveRecord::Base
    attr_protected :serial

    has_many :logs, :class_name => 'SystemLog', :foreign_key => :owning_manager_id, :order => :created_at
    has_many :system_logs, :dependent => :nullify, :order => :created_at
    has_many :system_messages, :dependent => :destroy, :order => :id
    has_many :tacacs_daemons, :dependent => :nullify, :order => :name
    has_many :system_revisions, :dependent => :destroy
    has_one :inbox_lock, :class_name => 'Lock', :conditions => "lock_type = 'inbox'", :dependent => :destroy
    has_one :outbox_lock, :class_name => 'Lock', :conditions => "lock_type = 'outbox'", :dependent => :destroy


    validates_presence_of :base_url, :if => Proc.new { |x| !x.is_local}
    validates_uniqueness_of :base_url, :if => Proc.new { |x| !x.base_url.blank?}
    validates_presence_of :base_url, :if => Proc.new { |x| !x.base_url.blank?}
    validates_presence_of :manager_type
    validates_format_of :manager_type, :with => /(master|slave|stand_alone)/, :message => "must be either 'master', 'slave', or 'stand_alone'."
    validates_presence_of :name
    validates_uniqueness_of :name, :if => Proc.new { |x| !x.name.blank?}
    validates_presence_of :password, :if => Proc.new { |x| !x.is_local}
    validates_presence_of :mail_from, :if => Proc.new { |x| !x.enable_mailer}


    before_destroy :prevent_local_manager_delete
    before_validation :default_settings
    after_create :create_locks
    after_create :set_revisions
    after_create :set_serial
    after_update :update_settings_on_remote_managers!


    def validate
        # only allow 1 local manager
        if ( self.is_local && Manager.count(:conditions => "is_local = true") > 1 )
            self.errors.add_to_base("There may only be 1 local TacacsPlus Manager.")
            return(false)
        end

        # only local system can be in maintenance mode
        if (!self.is_local && self.in_maintenance_mode)
            self.errors.add(:in_maintenance_mode, "may only be set on the local system.")
            return(false)
        end

        if (self.pagination_per_page < 5)
            self.errors.add(:pagination_per_page, "must be 5 or greater.")
            return(false)
        end

        if (self.retain_system_logs_for < 0)
            self.errors.add(:retain_system_logs_for, "must be a non-negative integer.")
            return(false)
        end

        if (self.disable_inactive_users_after < 0)
            self.errors.add(:disable_inactive_users_after, "must be a non-negative integer.")
            return(false)
        end

        if (self.archive_system_logs_for < 0)
            self.errors.add(:archive_system_logs_for, "must be a non-negative integer.")
            return(false)
        end

        if (self.maximum_aaa_log_retainment < 0)
            self.errors.add(:maximum_aaa_log_retainment, "must be a non-negative integer.")
            return(false)
        end

        if (self.maximum_aaa_archive_retainment < 0)
            self.errors.add(:maximum_aaa_archive_retainment, "must be a non-negative integer.")
            return(false)
        end

        if ( !(0..365).include?(self.default_enable_password_lifespan) )
            self.errors.add(:default_enable_password_lifespan, "must be between 0 and 365 inclusive.")
            return(false)
        end

        if ( !(0..365).include?(self.default_login_password_lifespan) )
            self.errors.add(:default_login_password_lifespan, "must be between 0 and 365 inclusive.")
            return(false)
        end

        if (self.password_history_length < 0)
            self.errors.add(:password_history_length, "must be a non-negative integer.")
            return(false)
        end

        if (self.password_minimum_length > 255)
            self.errors.add(:password_minimum_length, "must be 255 or less.")
            return(false)
        end

        if (self.password_minimum_length < 8)
            self.errors.add(:password_minimum_length, "must be 8 or more.")
            return(false)
        end

        if (self.maximum_network_object_group_length < 0)
            self.errors.add(:maximum_network_object_group_length, "must be a non-negative integer.")
            return(false)
        end

        if (self.maximum_acl_length < 0)
            self.errors.add(:maximum_acl_length, "must be a non-negative integer.")
            return(false)
        end

        # verify non-local managers are allowed to exist
        if (!self.is_local)
            local = Manager.local
           if (local.stand_alone?)
                self.errors.add_to_base("No remote managers may exist when local system is set as 'stand_alone'.")
                return(false)
           elsif (local.master? && !self.slave?)
                self.errors.add_to_base("Remote manager must be set as 'slave' when local system is set as 'master'.")
                return(false)
           elsif (local.slave? && !self.master?)
                self.errors.add_to_base("Remote manager must be set as 'master' when local system is set as 'slave'.")
                return(false)
           end
        end

        return(true)
    end

    # cmd = start,stop
    # status = error,started,stopped
    def Manager.backgroundrb_control(cmd=nil)
        status = 'stopped'
        msg = ''

        if (cmd == 'restart')
            child_pid = Process.fork do
                Process.setsid

                # have to do this to stop this proccess from inheriting the open
                # TCPServer IO from mongrel
                ObjectSpace.each_object(TCPSocket) {|sock| sock.reopen('/dev/null', 'r'); sock.close}

                exec "#{RAILS_ROOT}/script/backgroundrb stop; #{RAILS_ROOT}/script/backgroundrb start -e #{RAILS_ENV}"
            end
            Process.wait(child_pid)
            return(Manager.backgroundrb_control)

        elsif (cmd == 'start')
            child_pid = Process.fork do
                Process.setsid

                # have to do this to stop this proccess from inheriting the open
                # TCPServer IO from mongrel
                ObjectSpace.each_object(TCPSocket) {|sock| sock.reopen('/dev/null', 'r'); sock.close}

                exec "#{RAILS_ROOT}/script/backgroundrb start -e #{RAILS_ENV}"
            end
            Process.wait(child_pid)
            return(Manager.backgroundrb_control)

        elsif (cmd == 'stop')
            child_pid = Process.fork do
                Process.setsid

                # have to do this to stop this proccess from inheriting the open
                # TCPServer IO from mongrel
                ObjectSpace.each_object(TCPSocket) {|sock| sock.reopen('/dev/null', 'r'); sock.close}

                exec "#{RAILS_ROOT}/script/backgroundrb stop"
            end
            Process.wait(child_pid)
            return(Manager.backgroundrb_control)

        else
            conf_file = "#{RAILS_ROOT}/config/backgroundrb.yml"
            begin
                config = YAML.load_file(conf_file)
                pid_file = "#{RAILS_ROOT}/tmp/pids/backgroundrb_#{config[:backgroundrb][:port]}.pid"
                pid = File.open(pid_file).read.to_i if ( File.exists?(pid_file) )

                if (pid && pid > 0)
                    begin
                        Process.kill(0, pid)
                        status = 'started'
                        msg = "Running with pid #{pid}."
                    rescue Errno::ESRCH
                    rescue Exception => error
                        status = 'error'
                        msg = "Error reading BackgrounDRB status: #{error}"
                    end
                end

            rescue Exception => error
                msg = error
            end
        end

        return({:status => status, :message => msg})
    end

    # retrieve manager credentials from xml doc
    # expects xml document as <manager><serial>xxxx</serial><password>xxxxx</password></manager>
    # returns [serial,password] or nil
    def Manager.credentials_from_xml(doc)
        if (doc.root.name == 'manager')
            serial_xml = REXML::XPath.first(doc.root, "serial")
            serial = serial_xml.text if (serial_xml)
            pwd_xml = REXML::XPath.first(doc.root, "password") if (serial)
            pwd = pwd_xml.text if (pwd_xml)
            return([serial,pwd]) if (pwd)
        end
        return(nil)
     end

    def Manager.destroy_non_local!
        Manager.find(:all, :conditions => "is_local = false").each {|m| m.destroy}
        return(nil)
    end

    # return string of xml elements. no root element provided
    def Manager.export(full=false)
        xml = "<system-export>"
        xml << Department.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << User.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << PasswordHistory.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << Configuration.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << NetworkObjectGroup.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << NetworkObjectGroupEntry.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << ShellCommandObjectGroup.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << ShellCommandObjectGroupEntry.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << Acl.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << AclEntry.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << CommandAuthorizationProfile.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << CommandAuthorizationProfileEntry.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << AuthorAvpair.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << AuthorAvpairEntry.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << Avpair.find(:all).to_xml(:indent => 0, :skip_instruct => true, :except => [:attr, :val], :methods => :avpair)
        xml << CommandAuthorizationWhitelistEntry.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << UserGroup.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        xml << ConfiguredUser.find(:all).to_xml(:indent => 0, :skip_instruct => true)

        if (full)
            xml << Manager.find(:all).to_xml(:indent => 0, :skip_instruct => true)
            xml << TacacsDaemon.find(:all).to_xml(:indent => 0, :skip_instruct => true)
        end

        xml << "</system-export>"
        return(xml)
    end

    def Manager.local
        Manager.find(:first, :conditions => "is_local = true")
    end

    def Manager.non_local
        Manager.find(:all, :conditions => "is_local = false", :order => :name)
    end

    # used by master to register a slave
    # return master, or slave on error
    def Manager.register(url, from=nil)
        local = Manager.local
        if (local.master?)
            # create and save new slave
            s = Manager.new(:base_url => url)
            s.slave!
            s.name = URI.parse(s.base_url).host
            s.password = (1..32).collect { (i = Kernel.rand(62); i += ((i < 10) ? 48 : ((i < 36) ? 55 : 61 ))).chr }.join

            if (s.save)
                # modify self to send to slave
                local.id = nil
                local.serial = s.serial
                local.password = s.password
                local.is_approved = true
                local.is_local = false
                local.system_logs.create(:level => 'warn', :message => "Successful remote system registration for (#{s.serial}) from #{from}")
                return(local)
            else
                return(s)
            end

        else
            s = Manager.new
            s.errors.add_to_base("Registration could not proceed. This is not a Master system.")
            return(s)
        end
    end

    # add message to outbox of master
    # expects a valid verb, and an xml string
    # return manager
    def Manager.replicate_to_master(verb, message)
        if (Manager.local.slave?)
            master = Manager.find(:first, :conditions => "manager_type = 'master'")
            master.add_to_outbox(verb, message) if (master)
        end
        return(master)
    end

    # add message to outbox of all slaves
    # expects a valid verb, and an xml string
    # return array of managers
    def Manager.replicate_to_slaves(verb, message)
        if (Manager.local.master?)
            non_local = Manager.non_local
            non_local.each do |rs|
                rs.add_to_outbox(verb, message)
            end
        end
        return(non_local)
    end

    # used by slave to register with master
    # return manager
    def Manager.request_registration(master_url)
        m = Manager.new(:base_url => master_url)
        if (!local.slave?)
            m.errors.add_to_base("Only slave systems may request registration with a master system.")
            return(m)
        end

        data = "manager[base_url]=#{Manager.local.base_url}"
        http, uri = m.prepare_http_request("/register")

        begin
            response = http.post(uri.path, data, {'Accept' => 'text/xml'})

            if ( response.kind_of?(Net::HTTPAccepted) )
                doc = Hash.from_xml(response.body)
                if ( doc.has_key?('manager') )
                    m = Manager.new(doc['manager'])
                    m.serial = doc['manager']['serial']
                    m.save
                else
                    m.errors.add_to_base("Response contained no Manager data.")
                end

            elsif (response.kind_of?(Net::HTTPNotAcceptable))
                body = response.body
                doc = REXML::Document.new(body)
                if (doc.root.name == 'errors')
                     doc.root.each_element {|e| m.errors.add_to_base(e) }
                end
            else
                m.errors.add_to_base("Unexpected response: #{response.class}")
            end

        rescue Exception => error
            m.errors.add_to_base("Web services call raised errors: #{error}")
        end

        return(m)
    end

    # take hash with key = TacacsDaemon and val = (read,start,stop)
    # return {:managers => [], :tacacs_daemons => []}
    def Manager.start_stop_tacacs_daemons(tds,cmd)
        m_by_id = {}
        td_by_m = {}
        local_manager = nil
        Manager.find(:all).each {|m| m_by_id[m.id] = m; td_by_m[m] = []; local_manager = m if (m.is_local) }

        td_by_id = {}
        tds.each do |td|
            td_by_id[td.id] = td
            if ( !td.local?)
                td_by_m[ m_by_id[td.manager_id] ].push(td)
            else
                td_by_m[local_manager].push(td)
            end
        end

        # make threaded requests
        managers = []
        tacacs_daemons = []
        threads = []
        td_by_m.each_pair do |manager, tacacs_daemons_list|
            threads << Thread.new(manager, tacacs_daemons_list) do |m, td_list|
                statuses = []
                if (!m.is_local)
                    data = "serial=#{m.serial}&password=#{m.password}&command=#{cmd}"
                    td_list.each {|td| data << "&ids[#{td.id}]=#{td.id}" }
                    http, uri = m.prepare_http_request("/tacacs_daemon_control")

                    begin
                        response = http.post(uri.path, data.to_s, {'Accept' => 'text/xml'})
                        if ( response.kind_of?(Net::HTTPOK) )
                            h = Hash.from_xml(response.body)
                            h['tacacs_daemons'].each do |attrs|
                                td = td_by_id[ attrs['id'] ]
                                td.status = attrs['status']
                                td.errors.add_to_base(attrs['errors']) if (attrs.has_key?('errors') )
                                tacacs_daemons.push(td)
                            end
                        elsif ( response.kind_of?(Net::HTTPForbidden) )
                            m.errors.add_to_base("Authentication failure.")
                            Manager.local.log(:manager_id => self.id, :message => "Authorization failure on Manager #{self.name}. Disabling messaging.")
                            m.disable!('authentication failure.')
                            tacacs_daemons.concat(td_list)
                        elsif (response.kind_of?(Net::HTTPNotAcceptable))
                            body = response.body
                            doc = REXML::Document.new(body)
                            if (doc.root.name == 'errors')
                                doc.root.each_element {|e| m.errors.add_to_base(e.text) }
                            end
                            tacacs_daemons.concat(td_list)
                        else
                            m.errors.add_to_base("Unexpected response: #{response.class}")
                            tacacs_daemons.concat(td_list)
                        end

                    rescue Exception => error
                        m.errors.add_to_base("Web services call raised errors: #{error}")
                        tacacs_daemons.concat(td_list)
                    end

                else
                    if (cmd == 'start')
                        td_list.each {|td| td.start; tacacs_daemons.push(td) }
                    elsif (cmd == 'stop')
                        td_list.each {|td| td.stop; tacacs_daemons.push(td) }
                    elsif (cmd == 'reload')
                        td_list.each {|td| td.reload; tacacs_daemons.push(td) }
                    elsif (cmd == 'restart')
                        td_list.each {|td| td.restart; tacacs_daemons.push(td) }
                    else
                        tacacs_daemons = td_list.dup
                    end
                end

                managers.push(m)
            end
        end
        threads.each { |aThread|  aThread.join }

        return({:managers => managers, :tacacs_daemons => tacacs_daemons})
    end




    # take xml messages and create ManagerMessage objects out of them
    # expects xml document with the following element <messages> <message verb="save|destroy|sync"></message> </messages>
    # returns true or false
    def add_to_inbox(doc)
        messages = REXML::XPath.first(doc.root, "system-messages")
        if (messages)
            begin
                SystemMessage.transaction do
                    messages.each_element do |message|
                        if (message.name == 'system-message')
                            verb = REXML::XPath.first(message, 'verb')
                            revision = REXML::XPath.first(message, 'revision')
                            content = REXML::XPath.first(message, 'content')
                            content_data = REXML::XPath.first(content) if (content)
                            if (verb && content_data)
                                msg = self.system_messages.create(:queue => 'inbox', :verb => verb.text,
                                                                  :revision => revision.text, :content => content_data.to_s)
                                if (msg.errors.length != 0)
                                    msg.errors.each_full {|e| self.errors.add_to_base(e)}
                                    return(false)
                                end
                            else
                                self.errors.add_to_base("Verb and Content are required as part of all system messages.")
                            end
                        end
                    end
                end

            rescue Exception => error
                self.errors.add_to_base("Error processing system messages: #{error}")
                return(false)
            end

            begin
                # fire off background job to process the inbox
                MiddleMan.new_worker(:worker => :queue_worker)
                MiddleMan.worker(:queue_worker).async_process_inbox(:arg => self.id)
            rescue Exception => error
                Manager.local.log(:level => 'error', :message => "Manager#add_to_inbox - Error with BackgrounDRB: #{error}")
            end
        else
            self.errors.add_to_base("No messages could be found.")
            return(false)
        end

        return(true)
    end

    # add a message to the outbox for this manager
    # expects a valid verb, and an xml string
    # returns true or false
    def add_to_outbox(verb, content)
        if (self.is_approved)
            msg = self.system_messages.build(:queue => 'outbox', :verb => verb, :content => content)
            if (msg.save)
                begin
                    #MiddleMan.new_worker(:worker => :queue_worker, :worker_key => Time.now.strftime("%Y%m%d%H%M%S") )
                    #MiddleMan.worker(:queue_worker).async_write_remote(:arg => self.id) if (self.is_enabled && !self.outbox_locked?)

                    worker_key = "outbox#{self.id}-" + Time.now.strftime("%Y%m%d%H%M%S")
                    MiddleMan.new_worker(:worker => :queue_worker, :worker_key => worker_key )
                    MiddleMan.worker(:queue_worker, worker_key).async_write_remote(:arg => self.id)
                rescue Exception => error
                    local_manager = Manager.local
                    local_manager.log(:level => 'error', :message => "Manager#add_to_outbox - BackgrounDRb error: #{error}") if (!local_manager.slave?)
                end
                return(true)
            else
                msg.errors.each_full {|e| self.errors.add_to_base("Error adding to outbox: #{e}")}
                return(false)
            end
        else
            self.errors.add_to_base("Error adding to outbox: Manager has not been approved.")
            return(false)
        end
    end

    # approve a newly registered manager
    def approve!
        if (!self.is_approved)
            self.is_approved = true
            self.is_enabled = true
            self.add_to_outbox('create', Manager.export)
            return(self.save)
        else
            return(false)
        end
    end

    def authenticate(pwd)
        if (self.password == pwd)
            if (self.is_approved)
                self.enable! if (!self.is_enabled)
                return(true)
            else
                self.errors.add_to_base("Manager has not yet been approved by a system administrator.")
            end
        end
        return(false)
    end

    def disable!(msg=nil)
        if (self.is_enabled)
            self.is_enabled = false
            self.disabled_message = msg
            return(self.save)
        else
            self.errors.add_to_base("Manager is already disabled.")
            return(false)
        end
    end

    def enable!
        if (!self.is_approved)
            self.errors.add_to_base("Manager may not be enabled until it is approved.")
            return(false)
        elsif (!self.is_enabled)
            self.is_enabled = true
            self.disabled_message = nil
            return(self.save)
        else
            self.errors.add_to_base("Manager is already enabled.")
            return(false)
        end
    end

    # messages for local system from this manager
    def inbox()
        messages = self.system_messages.find(:all, :conditions => "queue = 'inbox'", :order => "id")
        return(messages)
    end

    def inbox_locked?
        return(true) if (self.inbox_lock.active?)
        return(false)
    end

    def inbox_revision
        self.system_revisions.find(:first, :conditions => "queue = 'inbox'").revision
    end

    def inbox_revision=(val)
        self.system_revisions.find(:first, :conditions => "queue = 'inbox'").update_attribute(:revision, val)
    end

    def lock_inbox(seconds)
        self.inbox_lock.update_attribute(:expires_at, Time.now + seconds)
    end

    def lock_outbox(seconds)
        self.outbox_lock.update_attribute(:expires_at, Time.now + seconds)
    end

    def log(attrs)
        self.logs.create(attrs)
    end

    def master?
        return(true) if (self.manager_type == 'master')
        return(false)
    end

    def master!
        if (self.is_local)
            Manager.destroy_non_local!
            self.manager_type = 'master'
            return(self.save)
        else
            if (Manager.local.slave?)
                self.manager_type = 'master'
                return(self.save)
            else
                self.errors.add_to_base("Remote manager may not be set as 'master' unless local manager is set as 'slave'.")
                return(false)
            end
        end
    end

    # messages for manager from local system
    def outbox()
        messages = self.system_messages.find(:all, :conditions => "queue = 'outbox'", :order => "id")
        return(messages)
    end

    def outbox_locked?
        return(true) if (self.outbox_lock.active?)
        return(false)
    end

    def outbox_revision
        self.system_revisions.find(:first, :conditions => "queue = 'outbox'").revision
    end

    def outbox_revision=(val)
        self.system_revisions.find(:first, :conditions => "queue = 'outbox'").update_attribute(:revision, val)
    end

    def prepare_http_request(path)
        uri = URI.parse(self.base_url + path)
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = 20
        http.use_ssl = true if (uri.scheme == 'https')
        return([http, uri])
    end

    def process_inbox!
        rev = self.inbox_revision
        self.inbox.each do |m|
            rev = m.process_content(rev)
            if (rev == 0 && self.master?) # if revision mismatch clear inbox and request resync
                SystemMessage.destroy_all("manager_id = #{self.id} and queue = 'inbox'")
                self.request_system_sync!
                break
            end
        end
        self.inbox_revision = rev
    end

    # attempt to read remote log file. return string or false.
    def read_remote_log_file(tacacs_daemon,log)
        http, uri = prepare_http_request("/read_log_file")
        data = "serial=#{self.serial}&password=#{self.password}&tacacs_daemon=#{tacacs_daemon.id}&log=#{log}"

        begin
            response = http.post(uri.path, data, {'Accept' => 'text/xml'})

            if ( response.kind_of?(Net::HTTPOK) )
                doc = REXML::Document.new(response.body)
                if (doc.root.name == 'log')
                     return(doc.root.text)
                end
            elsif ( response.kind_of?(Net::HTTPForbidden) )
                self.errors.add_to_base("Authentication failure.")
                Manager.local.log(:manager_id => self.id, :message => "Authorization failure on Manager #{self.name}. Disabling messaging.")
                self.disable!('authentication failure.')
            elsif (response.kind_of?(Net::HTTPNotAcceptable))
                body = response.body
                doc = REXML::Document.new(body)
                if (doc.root.name == 'errors')
                     doc.root.each_element {|e| self.errors.add_to_base(e.text) }
                end
            else
                self.errors.add_to_base("Unexpected response: #{response.class}")
            end

        rescue Exception => error
            self.errors.add_to_base("Web services call raised errors: #{error}")
        end

        return(false)
    end

    def request_system_sync!
        http, uri = prepare_http_request("/resync")
        data = "serial=#{self.serial}&password=#{self.password}"

        begin
            response = http.post(uri.path, data, {'Accept' => 'text/xml'})

            if ( response.kind_of?(Net::HTTPOK) )
                return(true)

            elsif ( response.kind_of?(Net::HTTPForbidden) )
                self.errors.add_to_base("Authentication failure.")
                Manager.local.log(:manager_id => self.id, :message => "Authorization failure on Manager #{self.name}. Disabling messaging.")
                self.disable!('authentication failure.')
            elsif (response.kind_of?(Net::HTTPNotAcceptable))
                body = response.body
                doc = REXML::Document.new(body)
                if (doc.root.name == 'errors')
                     doc.root.each_element {|e| self.errors.add_to_base(e.text) }
                end
            else
                self.errors.add_to_base("Unexpected response: #{response.class}")
            end

        rescue Exception => error
            self.errors.add_to_base("Web services call raised errors: #{error}")
        end

        return(false)
    end

    # tell manager to perform complete re-sync of all system data
    def send_system_sync!
        if (!self.is_local && self.is_enabled && self.slave?)
            SystemMessage.destroy_all("manager_id = #{self.id} and queue = 'outbox'")
            self.outbox_revision = 0
            self.add_to_outbox('create', Manager.export)
            self.save
        end
        return(true)
    end

    def slave?
        return(true) if (self.manager_type == 'slave')
        return(false)
    end

    def slave!
        if (self.is_local)
            Manager.destroy_non_local!
            self.manager_type = 'slave'
            return(self.save)
        else
            if (Manager.local.master?)
                self.manager_type = 'slave'
                return(self.save)
            else
                self.errors.add_to_base("Remote manager may not be set as 'slave' unless local manager is set as 'master'.")
                return(false)
            end
        end
    end

    def stand_alone?
        return(true) if (self.manager_type == 'stand_alone')
        return(false)
    end

    def stand_alone!
        if (self.is_local)
            Manager.destroy_non_local!
            self.manager_type = 'stand_alone'
            return(self.save)
        else
            self.errors.add_to_base("Only the local system may be set as 'stand_alone'.")
            return(false)
        end
    end

    def toggle_maintenance_mode!
        if (self.in_maintenance_mode)
            self.in_maintenance_mode = false
        else
            self.in_maintenance_mode = true
        end
        self.save
    end

    def unlock_inbox()
        self.inbox_lock.update_attribute(:expires_at, nil)
    end

    def unlock_outbox()
        self.outbox_lock.update_attribute(:expires_at, nil)
    end

    # messages from inbox which could not be processed
    def unprocessable_messages()
        messages = self.system_messages.find(:all, :conditions => "queue = 'unprocessable'", :order => "id")
        return(messages)
    end

    # write messages into inbox of manager
    def write_remote_inbox!
        if (!self.is_enabled)
            self.errors.add_to_base("Messaging is not enabled.")
            return(false)
        end

        # if no messages, then exit
        cur_revision = self.outbox_revision
        out_msgs = self.outbox
        return(true) if (out_msgs.length == 0)

        http, uri = prepare_http_request("/write_to_inbox")
        data = REXML::Element.new("manager")
        ser = REXML::Element.new("serial")
        ser.text = self.serial
        data.add_element(ser)
        pw = REXML::Element.new("password")
        pw.text = self.password
        data.add_element(pw)
        messages = REXML::Element.new("system-messages")
        out_msgs.each do |m|
            if (m.content.blank?)
                msg = "Error with outbox message #{m.id}. Content empty or content file missing."
                Manager.local.log(:level => 'error', :message => msg)
                m.error_log = msg
                m.queue = 'unprocessable'
                m.save
                next
            end
            cur_revision += 1
            m.revision = cur_revision
            messages.add_element(m.to_xml)
        end
        data.add_element(messages)

        begin
            response = http.post(uri.path, data.to_s, {'Accept' => 'text/xml', 'Content-type' => 'text/xml'})

            if ( response.kind_of?(Net::HTTPOK) )
                out_msgs.each {|m| m.destroy}
                self.outbox_revision = cur_revision
                return(true)

            elsif ( response.kind_of?(Net::HTTPForbidden) )
                Manager.local.log(:manager_id => self.id, :message => "Manager#write_remote_inbox! - authorization failure on Manager #{self.name}. Disabling messaging.")
                self.disable!('authentication failure.')
            elsif (response.kind_of?(Net::HTTPNotAcceptable))
                body = response.body
                doc = REXML::Document.new(body)
                if (doc.root.name == 'errors')
                    error = ''
                    doc.root.each_element {|e| error << e.text + "\n" }
                    Manager.local.log(:level => 'warn', :message => "Manager#write_remote_inbox! - raised errors: #{error}")
                end
            else
                Manager.local.log(:level => 'warn', :message => "Manager#write_remote_inbox! - unexpected response: #{response.class}")
            end

        rescue Exception => error
            Manager.local.log(:level => 'warn', :message => "Manager#write_remote_inbox! - raised errors: #{error}")
        end

        return(false)
    end


private

    def create_locks
        self.create_inbox_lock(:lock_type => 'inbox')
        self.create_outbox_lock(:lock_type => 'outbox')
    end

    def default_settings
        self.pagination_per_page = 100 if (!self.pagination_per_page)
        self.retain_system_logs_for = 90 if (!self.retain_system_logs_for)
        self.archive_system_logs_for = 365 if (!self.archive_system_logs_for)
        self.disable_inactive_users_after = 0 if (!self.disable_inactive_users_after)
        self.default_enable_password_lifespan = 90 if (!self.default_enable_password_lifespan)
        self.default_login_password_lifespan = 90 if (!self.default_login_password_lifespan)
        self.password_history_length = 3 if (!self.password_history_length)
        self.password_minimum_length = 8 if (!self.password_minimum_length)
        self.password_require_mixed_case = false if (self.password_require_mixed_case.nil?)
        self.password_require_alphanumeric = false if (self.password_require_alphanumeric.nil?)

        self.maximum_network_object_group_length = 50 if (!self.maximum_network_object_group_length)
        self.maximum_acl_length = 10 if (!self.maximum_acl_length)
        self.maximum_aaa_log_retainment = 21 if (!self.maximum_aaa_log_retainment)
        self.maximum_aaa_archive_retainment = 365 if (!self.maximum_aaa_archive_retainment)

        self.enable_mailer = false if (self.enable_mailer.nil?)
        begin
            self.mail_account_disabled = File.open("#{RAILS_ROOT}/tmp/mailer_templates/account_disabled.txt").read if (self.mail_account_disabled.blank?)
            self.mail_new_account = File.open("#{RAILS_ROOT}/tmp/mailer_templates/new_account.txt").read if (self.mail_new_account.blank?)
            self.mail_password_expired = File.open("#{RAILS_ROOT}/tmp/mailer_templates/password_expired.txt").read if (self.mail_password_expired.blank?)
            self.mail_password_reset = File.open("#{RAILS_ROOT}/tmp/mailer_templates/password_reset.txt").read if (self.mail_password_reset.blank?)
            self.mail_pending_password_expiry = File.open("#{RAILS_ROOT}/tmp/mailer_templates/pending_password_expiry.txt").read if (self.mail_pending_password_expiry.blank?)
        rescue Exception => error
            self.errors.add_to_base("Error setting up default mailer messages: #{error}")
        end
    end

    def prevent_local_manager_delete
        if (self.is_local)
            self.errors.add_to_base("You may not delete the local TacacsPlus Manager.")
            return(false)
        end
        return(true)
    end

    def set_revisions
        self.system_revisions.create(:queue => 'inbox', :revision => 0)
        self.system_revisions.create(:queue => 'outbox', :revision => 0)
    end

    def set_serial
        self.serial = Time.now.strftime("%Y%m%d-%H%M%S-") << self.id.to_s
        self.save
    end

    def update_settings_on_remote_managers!
        if (self.is_local)
            Manager.replicate_to_slaves('update',
                                        Manager.local.to_xml(:skip_instruct => true, :except => [:id, :is_approved,
                                        :is_enabled, :is_local, :base_url, :manager_type, :name, :password, :serial,
                                        :disabled_message, :created_at, :updated_at]) )
        elsif (self.is_enabled && self.slave?)
            self.add_to_outbox( 'update', self.to_xml(:skip_instruct => true, :only => [:name, :base_url]) )
        end
    end

end
