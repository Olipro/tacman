class Configuration < ActiveRecord::Base
    attr_protected :aaa_log_dir, :serial

    belongs_to :department
    has_many :aaa_log_archives, :dependent => :destroy, :order => :archived_on
    has_many :aaa_logs, :dependent => :destroy, :order => :timestamp
    has_many :aaa_reports, :dependent => :destroy, :order => :name
    has_many :acls, :dependent => :destroy, :order => :name
    has_many :author_avpairs, :dependent => :destroy, :order => :name
    has_many :command_authorization_profiles, :dependent => :destroy, :order => :name
    has_many :command_authorization_whitelist_entries, :dependent => :destroy, :order => :sequence
    has_many :network_object_groups, :dependent => :destroy, :order => :name
    has_many :shell_command_object_groups, :dependent => :destroy, :order => :name
    has_many :user_groups, :dependent => :destroy, :order => :name
    has_many :configured_users, :dependent => :destroy
    has_many :tacacs_daemons, :dependent => :nullify, :order => :name
    has_many :users, :through => :configured_users, :order => :username
    has_many :system_logs, :dependent => :nullify, :order => :id
    has_one :publish_lock, :class_name => 'Lock', :conditions => "lock_type = 'publish'", :dependent => :destroy


    validates_format_of :default_policy, :with => /(permit|deny)/
    validates_length_of :disabled_prompt, :maximum => 255, :allow_nil => true
    validates_presence_of :key
    validates_inclusion_of :log_level, :in => (0..4), :allow_nil => true
    validates_length_of :login_prompt, :maximum => 255, :allow_nil => true
    validates_presence_of :name
    validates_uniqueness_of :name
    validates_length_of :password_expired_prompt, :maximum => 255, :allow_nil => true
    validates_length_of :password_prompt, :maximum => 255, :allow_nil => true


    before_validation :default_settings
    after_create :setup
    after_create :create_locks
    after_destroy :destroy_on_remote_managers!
    after_destroy :cleanup
    after_update :update_on_remote_managers!


    def validate
        local_manager = Manager.local
        if (self.retain_aaa_logs_for < 0)
            self.errors.add(:retain_aaa_logs_for, "must be a non-negative integer.")
            return(false)
        elsif (local_manager.maximum_aaa_log_retainment > 0)
            if (self.retain_aaa_logs_for > local_manager.maximum_aaa_log_retainment || self.retain_aaa_logs_for == 0)
                self.errors.add(:retain_aaa_logs_for, "must be between 1 and #{local_manager.maximum_aaa_log_retainment}")
                return(false)
            end
        end

        if (self.archive_aaa_logs_for < 0)
            self.errors.add(:archive_aaa_logs_for, "must be a non-negative integer.")
            return(false)
        elsif (local_manager.maximum_aaa_archive_retainment > 0)
            if (self.archive_aaa_logs_for > local_manager.maximum_aaa_archive_retainment || self.archive_aaa_logs_for == 0)
                self.errors.add(:archive_aaa_logs_for, "must be between 1 and #{local_manager.maximum_aaa_archive_retainment}")
                return(false)
            end
        end
        return(true)
    end



    def acl_from_string(data)
        acl = self.acls.build

        if (data.length == 0)
            acl.errors.add_to_base("No data provided.")
            return(acl)
        end

        begin
            Configuration.transaction do
                data = data.split("\n")
                cmd,name = data.shift.split(' ', 2)
                if (cmd == 'access-list')
                    acl.name = name.strip.squeeze(" ").gsub(/ /, '_').downcase
                else
                    acl.errors.add_to_base("Unknown directive: #{cmd}")
                    raise
                end
                acl.save!

                count = 1
                data.each do |entry|
                    next if (entry.blank?)
                    permission,type,val1,val2 = entry.split(' ')
                    if (type == 'network-object-group')
                        nog = NetworkObjectGroup.find_by_name(val1, :conditions => "configuration_id = #{self.id}")
                        if (nog)
                            e = acl.acl_entries.create(:permission => permission, :network_object_group_id => nog.id)
                        else
                            acl.errors.add_to_base("entry #{count}: Unknown network-object-group: #{val1}")
                            raise
                        end
                    elsif (type == 'ip')
                        e = acl.acl_entries.create(:permission => permission, :ip => val1, :wildcard_mask => val2)
                    else
                        acl.errors.add_to_base("entry #{count}: unknown directive: #{type}")
                        raise
                    end

                    if (e.errors.length != 0)
                        e.errors.each_full {|x| acl.errors.add_to_base("entry #{count}: #{x}"); raise}
                    end
                    count = count + 1
                end
            end
        rescue
        end
        return(acl)
    end

    def archive_aaa_logs(date, logs)
        arch = AaaLogArchive.find_by_archived_on(date, :conditions => "configuration_id = #{self.id}")
        if (!arch)
            arch = self.aaa_log_archives.create(:archive_file => self.aaa_log_dir + date + ".txt", :archived_on => date)
        elsif (arch.zipped?)
            if (!arch.unzip!)
                local_manager.log(:message => "SystemLogArchive - Error unzipping #{arch.archive_file}: #{arch.errors.full_messages.join(' ')}")
                return(false)
            end
        end

        file = arch.archive_file

        begin
            f = File.open(arch.archive_file, 'a')
            f.print(logs)
            f.close
        rescue Exception => error
            self.errors.add_to_base("Error writing to archive file: #{error}")
            return(false)
        end
        return(true)
    end

    def author_avpair_from_string(data)
        author_avpair = self.author_avpairs.build

        if (data.length == 0)
            author_avpair.errors.add_to_base("No data provided.")
            return(author_avpair)
        end

        begin
            Configuration.transaction do
                data = data.split("\n")
                seq = nil
                acl = nil
                entry = nil
                count = 1
                data.each do |line|
                    next if (line.blank?)
                    line.strip!
                    elements = line.split(' ')
                    if (elements[0] == 'author-avpair-list')
                        acl = nil
                        entry = nil
                        if (author_avpair.name.blank?)
                            author_avpair.name = elements[1]
                            author_avpair.save!
                        elsif (author_avpair.name != elements[1])
                            author_avpair.errors.add_to_base("Line #{count}: may only create 1 author-avpair-list at a time.")
                            raise
                        end
                        seq = elements[2] if (elements[2])
                    elsif (elements[0] == 'match')
                        if (acl)
                            author_avpair.errors.add_to_base("Line #{count}: there may only be a single 'match' statment.")
                            raise
                        elsif (elements[1] == 'access-list')
                            acl = Acl.find_by_name(elements[2], :conditions => "configuration_id = #{self.id}")
                            if (!acl)
                                author_avpair.errors.add_to_base("Line #{count}: unknown access-list: #{elements[2]}")
                                raise
                            end
                        else
                            author_avpair.errors.add_to_base("Line #{count}: unknown directive: #{elements[1]}")
                            raise
                        end
                    elsif (elements[0] == 'set')
                        elements = line.split(' ', 2)
                        if (elements[1] =~ /^service=/)
                            entry = author_avpair.author_avpair_entries.build(:service => elements[1].split('service=')[1] )
                            entry.sequence = seq if (seq)
                            entry.acl_id = acl.id if (acl)
                            entry.save
                            if (entry.errors.length != 0)
                                entry.errors.each_full {|x| author_avpair.errors.add_to_base("Line #{count}: #{x}")}
                                raise
                            end
                        elsif (entry)
                            av = entry.avpairs.create(:avpair => elements[1])
                            if (av.errors.length != 0)
                                av.errors.each_full {|x| author_avpair.errors.add_to_base("Line #{count}: #{x}")}
                                raise
                            end
                        else
                            author_avpair.errors.add_to_base("Line #{count}: service must be specified before any other avpairs.")
                            raise
                        end
                    else
                        author_avpair.errors.add_to_base("Line #{count}: unknown directive: #{elements[0]}")
                        raise
                    end
                    author_avpair.save!

                    count = count + 1
                end
            end
        rescue
        end
        return(author_avpair)
    end

    def command_authorization_profile_from_string(data)
        command_authorization_profile = self.command_authorization_profiles.build

        if (data.length == 0)
            command_authorization_profile.errors.add_to_base("No data provided.")
            return(command_authorization_profile)
        end

        begin
            Configuration.transaction do
                data = data.split("\n")
                cmd,name = data.shift.split(' ', 2)
                if (cmd == 'command-authorization-profile')
                    command_authorization_profile.name = name.strip.squeeze(" ").gsub(/ /, '_').downcase
                else
                    command_authorization_profile.errors.add_to_base("Unknown directive: #{cmd}")
                    raise
                end
                command_authorization_profile.save!

                count = 1
                data.each do |entry|
                    next if (entry.blank?)
                    type,entry = entry.split(' ', 2)
                    if (type == 'shell-command-object-group')
                        scog_name,acl_data = entry.split(' ',2)
                        scog = ShellCommandObjectGroup.find_by_name(scog_name, :conditions => "configuration_id = #{self.id}")
                        if (scog)
                            attrs = {:shell_command_object_group_id => scog.id}
                        else
                            command_authorization_profile.errors.add_to_base("entry #{count}: unknown shell-command-object-group: #{scog_name}")
                            raise
                        end
                    elsif (type == 'command')
                        trash,command,acl_data = entry.split('/',3)
                        attrs = {:command => command}
                    else
                        command_authorization_profile.errors.add_to_base("entry #{count}: unknown directive: #{type}")
                        raise
                    end

                    if (acl_data && !acl_data.blank?)
                        cmd,name = acl_data.split(' ')
                        if (cmd == 'access-list')
                            acl = Acl.find_by_name(name, :conditions => "configuration_id = #{self.id}")
                            if (acl)
                                attrs[:acl_id] = acl.id
                            else
                                command_authorization_profile.errors.add_to_base("entry #{count}: unknown access-list: #{name}")
                                raise
                            end
                        else
                            command_authorization_profile.errors.add_to_base("entry #{count}: unknown directive: #{cmd}")
                            raise
                        end
                    end

                    e = command_authorization_profile.command_authorization_profile_entries.create(attrs)
                    if (e.errors.length != 0)
                        e.errors.each_full {|x| command_authorization_profile.errors.add_to_base("entry #{count}: #{x}"); raise}
                    end
                    count = count + 1
                end
            end
        rescue
        end
        return(command_authorization_profile)
    end

    def cleanup_logs!
        return(false) if (self.retain_aaa_logs_for == 0)

        date = (Date.today - self.retain_aaa_logs_for).to_s
        datetime = date + ' 23:59:59'
        AaaLog.delete_all("configuration_id = #{self.id} AND timestamp <= '#{datetime}'")
    end

    def cleanup_archives!
        return(false) if (self.archive_aaa_logs_for == 0)

        date = (Date.today - self.archive_aaa_logs_for).to_s
        AaaLogArchive.destroy_all("configuration_id = #{self.id} AND archived_on <= '#{date}'")
    end

    def configuration_hash
        return (@config) if (@config)

        shell_command_object_groups = {}
        network_object_groups = {}
        acls = {}
        author_avpairs = {}
        command_authorization_profiles = {}
        command_authorization_whitelist = []
        tacacs_daemon = {}
        user_groups = {}
        users = {}

        tacacs_daemon[:default_policy] = self.default_policy
        tacacs_daemon[:disabled_prompt] = self.disabled_prompt if (!self.disabled_prompt.blank?)
        tacacs_daemon[:key] = self.key
        tacacs_daemon[:log_level] = self.log_level
        tacacs_daemon[:login_prompt] = self.login_prompt if (!self.login_prompt.blank?)
        tacacs_daemon[:password_expired_prompt] = self.password_expired_prompt if (!self.password_expired_prompt.blank?)
        tacacs_daemon[:password_prompt] = self.password_prompt if (!self.password_prompt.blank?)
        tacacs_daemon[:log_accounting] = self.log_accounting
        tacacs_daemon[:log_authentication] = self.log_authentication
        tacacs_daemon[:log_authorization] = self.log_authorization

        self.configured_users.each do |configured_user|
            next if (configured_user.suspended?)
            user = configured_user.user
            attrs = user.configuration_hash
            users[user.username] = attrs
            if (configured_user.command_authorization_profile_id?)
                command_authorization_profiles[configured_user.command_authorization_profile.name] = {}
                users[user.username][:command_authorization_profile] = configured_user.command_authorization_profile.name
            end

            if (configured_user.enable_acl_id?)
                acls[configured_user.enable_acl.name] = []
                users[user.username][:enable_acl] = configured_user.enable_acl.name
            end

            if (configured_user.login_acl_id?)
                acls[configured_user.login_acl.name] = []
                users[user.username][:login_acl] = configured_user.login_acl.name
            end

            if (configured_user.author_avpair_id?)
                author_avpairs[configured_user.author_avpair.name] = {}
                users[user.username][:author_avpair] = configured_user.author_avpair.name
            end

            if (configured_user.user_group_id?)
                user_groups[configured_user.user_group.name] = {}
                users[user.username][:user_group] = configured_user.user_group.name
            end
        end

        user_groups.each_key do |name|
            user_group = self.user_groups.find_by_name(name)

            if (user_group.command_authorization_profile_id?)
                command_authorization_profiles[user_group.command_authorization_profile.name] = {}
            end

            if (user_group.enable_acl_id?)
                acls[user_group.enable_acl.name] = []
            end

            if (user_group.login_acl_id?)
                acls[user_group.login_acl.name] = []
            end

            if (user_group.author_avpair_id?)
                author_avpairs[user_group.author_avpair.name] = {}
            end

            user_groups[user_group.name] = user_group.configuration_hash
        end

        command_authorization_profiles.each_key do |name|
            command_authorization_profile = self.command_authorization_profiles.find_by_name(name)
            command_authorization_profile.command_authorization_profile_entries.each do |entry|
                if (entry.shell_command_object_group_id?)
                    shell_command_object_groups[entry.shell_command_object_group.name] = []
                end

                if (entry.acl_id?)
                    acls[entry.acl.name] = []
                end
            end
            command_authorization_profiles[command_authorization_profile.name] = command_authorization_profile.configuration_hash
        end

        self.command_authorization_whitelist_entries.each  do |entry|
            if (entry.shell_command_object_group_id?)
                shell_command_object_groups[entry.shell_command_object_group.name] = []
            end

            if (entry.acl_id?)
                acls[entry.acl.name] = []
            end
            command_authorization_whitelist.push(entry.configuration_hash)
        end

        author_avpairs.each_key do |name|
            author_avpair = self.author_avpairs.find_by_name(name)
            author_avpair.author_avpair_entries.each do |entry|
                if (entry.acl_id?)
                    acls[entry.acl.name] = []
                end

                entry.dynamic_avpairs.each do |dav|
                    dav.dynamic_avpair_values.each do |v|
                        if (v.network_object_group_id?)
                            network_object_groups[v.network_object_group.name] = []
                        end

                        if (v.shell_command_object_group_id?)
                            shell_command_object_groups[v.shell_command_object_group.name] = []
                        end
                    end
                end
            end
            author_avpairs[author_avpair.name] = author_avpair.configuration_hash
        end

        acls.each_key do |name|
            acl = Acl.find_by_name(name)
            acl.acl_entries.each do |entry|
                if (entry.network_object_group_id?)
                    network_object_groups[entry.network_object_group.name] = []
                end
            end
            acls[acl.name] = acl.configuration_hash
        end

        shell_command_object_groups.each_key do |name|
            shell_command_object_group = self.shell_command_object_groups.find_by_name(name)
            shell_command_object_groups[shell_command_object_group.name] = shell_command_object_group.configuration_hash
        end

        network_object_groups.each_key do |name|
            network_object_group = self.network_object_groups.find_by_name(name)
            network_object_groups[network_object_group.name] = network_object_group.configuration_hash
        end

        @config = {:shell_command_object_groups => shell_command_object_groups, :network_object_groups => network_object_groups,
                   :acls => acls, :command_authorization_profiles => command_authorization_profiles,
                   :command_authorization_whitelist => command_authorization_whitelist, :author_avpairs => author_avpairs,
                   :tacacs_daemon => tacacs_daemon, :user_groups => user_groups, :users => users}
        return(@config)
    end

    def import_aaa_logs(log)
        client_dns = {}
        users = {}
        login_times = {}
        to_archive = {}

        # split each log into appropriate fields. attempt dns lookup for client
        log.each_line do |line|
            next if (line.blank? || line =~/^#/)
            line.chomp!
            fields = {}
            begin
                line.split("\t").each do |field|
                    attr,val = field.split('=', 2)
                    fields[attr.to_sym] = val
                end
            rescue Exception => error
                self.errors.add_to_base("Error parsing aaa_log /#{line}/: #{error}")
                next
            end

            # attempt dns lookup of client ip
            if ( fields.has_key?(:client) && !fields[:client].blank? )
                ip = fields[:client]
                name = ''
                if ( client_dns.has_key?(ip) )
                    name = client_dns[ip]
                else
                    begin
                        name = Resolv.getname(ip)
                    rescue Exception
                    end
                    client_dns[ip] = name
                end
                fields[:client_name] = name
            end

            # add to archive list
            time = nil
            if ( fields.has_key?(:timestamp) && !fields[:timestamp].blank? )
                begin
                    time = Time.parse(fields[:timestamp])
                    day = time.strftime("%Y-%m-%d")

                    if ( !to_archive.has_key?(day) )
                        to_archive[day] = line + "\n"
                    else
                        to_archive[day] = to_archive[day] << line << "\n"
                    end

                rescue Exception => error
                    self.errors.add_to_base("Timestamp error /#{line}/: #{error}")
                    next
                end

            else
                self.errors.add_to_base("Timestamp missing from aaa_log /#{line}/")
                next
            end

            # get user login times
            if ( fields.has_key?(:user) && !fields[:user].blank? )
                username = fields[:user]
                msg_type = fields[:msg_type] if ( fields.has_key?(:msg_type) )
                status = fields[:status] if ( fields.has_key?(:status) )

                begin
                    users[username] = User.find_by_username(username)
                    user = users[username]
                rescue
                end

                if (user && msg_type == 'Authentication' && status == 'Pass')
                    if ( login_times.has_key?(username) )
                        login_times[username] = time if (login_times[username] < time)
                    else
                        login_times[username] = time
                    end
                end
            end

            # create aaa_log
            begin
                self.aaa_logs.create!(fields) if (!user || !user.disable_aaa_log_import)
            rescue Exception => err
                self.errors.add_to_base("Error adding aaa_log /#{line}/: #{err}")
            end

        end

        # update user last_login
        login_times.each_pair do |username,time|
            users[username].last_login = time
        end

        # archive logs
        to_archive.each_pair {|day,logs| self.archive_aaa_logs(day, logs )}

        return(true)
    end

    def network_object_group_from_string(data)
        nog = self.network_object_groups.build

        if (data.length == 0)
            nog.errors.add_to_base("No data provided.")
            return(nog)
        end

        begin
            Configuration.transaction do
                data = data.split("\n")
                cmd,name = data.shift.split(' ', 2)
                if (cmd == 'network-object-group')
                    nog.name = name.strip.squeeze(" ").gsub(/ /, '_').downcase
                else
                    nog.errors.add_to_base("Unknown directive: #{cmd}")
                    raise
                end
                nog.save!

                count = 1
                data.each do |entry|
                    next if (entry.blank?)
                    e = nog.network_object_group_entries.create(:cidr => entry.strip)
                    if (e.errors.length != 0)
                        e.errors.each_full {|x| nog.errors.add_to_base("entry #{count}: #{x}"); raise}
                    end
                    count = count + 1
                end
            end
        rescue
        end
        return(nog)
    end

    def shell_command_object_group_from_string(data)
        scog = self.shell_command_object_groups.build

        if (data.length == 0)
            scog.errors.add_to_base("No data provided.")
            return(scog)
        end

        begin
            Configuration.transaction do
                data = data.split("\n")
                cmd,name = data.shift.split(' ', 2)
                if (cmd == 'shell-command-object-group')
                    scog.name = name.strip.squeeze(" ").gsub(/ /, '_').downcase
                else
                    scog.errors.add_to_base("Unknown directive: #{cmd}")
                    raise
                end
                scog.save!

                count = 1
                data.each do |entry|
                    next if (entry.blank?)
                    e = scog.shell_command_object_group_entries.create(:command => entry.strip)
                    if (e.errors.length != 0)
                        e.errors.each_full {|x| scog.errors.add_to_base("entry #{count}: #{x}"); raise}
                    end
                    count = count + 1
                end
            end
        rescue
        end
        return(scog)
    end

    def publish
        local_daemons_count = self.tacacs_daemons.count(:conditions => "manager_id is null")
        remote_daemons = self.tacacs_daemons.find(:all, :conditions => "manager_id is not null")

        if (remote_daemons.length > 0)
            managers = {}
            remote_daemons.each {|td| managers[td.manager_id] = td.manager }
            managers.each_value do |m|
                m.add_to_outbox('update', "<publish><id type=\"integer\">#{self.id}</id></publish>" )
            end
        end

        # request delayed restart of tacacs daemons. this should prevent consecutive publish requests from
        # creating a dos situation on the daemons
        self.schedule_publish(60) if (local_daemons_count > 0 && !self.publish_scheduled?)

        return(true)
    end

    def publish_scheduled?
        return(true) if (self.publish_lock.active?)
        return(false)
    end

    def resequence_whitelist!
        begin
            seq = 10
            self.command_authorization_whitelist_entries.each do |e|
                CommandAuthorizationWhitelistEntry.update_all("sequence = #{seq}", "id = #{e.id}")
                seq = seq + 10
            end

            xml = "<resequence>" << self.to_xml(:indent => 0, :skip_instruct => true, :only => :id) << "</resequence>"
            Manager.replicate_to_slaves('update', xml )

        rescue Exception => error
            self.errors.add_to_base("Resequencing failed with errors: #{error}")
            return(false)
        end

        return(true)
    end

    def schedule_publish(seconds)
        self.publish_lock.update_attribute(:expires_at, Time.now + seconds)
        begin
            worker_key = "publish#{self.id}"
            if (MiddleMan.worker(:queue_worker, worker_key).worker_info[:status] == :stopped)
                MiddleMan.new_worker(:worker => :queue_worker, :worker_key => worker_key )
                MiddleMan.worker(:queue_worker, worker_key).async_publish_configuration(:arg => self.id)
            end
        rescue Exception => error
            Manager.local.log(:level => 'error', :configuration_id => self.id, :message => "Publishing error: #{error}")
            self.errors.add_to_base("Publishing error: #{error}")
            self.publish_lock.update_attribute(:expires_at, nil)
        end
    end

private

    def cleanup
        begin
            FileUtils.remove_entry_secure(self.aaa_log_dir)
        rescue Exception => err
            self.errors.add_to_base("Error removing aaa_log_dir: #{err}")
        end
    end

    def create_locks
        self.create_publish_lock(:lock_type => 'publish')
    end

    def create_on_remote_managers!
        Manager.replicate_to_slaves('create', self.to_xml(:skip_instruct => true) )
    end

    def default_settings
        local_manager = Manager.local
        self.retain_aaa_logs_for = local_manager.maximum_aaa_log_retainment if (!self.retain_aaa_logs_for && local_manager.maximum_aaa_log_retainment > 0)
        self.archive_aaa_logs_for = local_manager.maximum_aaa_archive_retainment if (!self.archive_aaa_logs_for && local_manager.maximum_aaa_archive_retainment > 0)
    end

    def destroy_on_remote_managers!
        Manager.replicate_to_slaves('destroy', self.to_xml(:skip_instruct => true, :only => :id) )
    end

    def setup
        self.serial = Time.now.strftime("%Y%m%d-%H%M%S-") << self.id.to_s
        self.aaa_log_dir = File.expand_path("#{RAILS_ROOT}/log/aaa_logs/") + "/#{self.serial}/"

        create_on_remote_managers!
        self.save

        begin
            FileUtils.mkdir(self.aaa_log_dir)
        rescue Exception => err
            self.errors.add_to_base("Error creating aaa_log_dir: #{err}")
        end
    end

    def update_on_remote_managers!
        Manager.replicate_to_slaves('update', self.to_xml(:skip_instruct => true) )
    end

end
