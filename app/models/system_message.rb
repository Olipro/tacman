class SystemMessage < ActiveRecord::Base
    belongs_to :manager


    validates_format_of :queue, :with => /(inbox|outbox|unprocessable)/, :message => "must be either 'inbox', 'outbox', or 'unprocessable'."
    validates_format_of :verb, :with => /(create|destroy|update)/, :message => "must be either 'create', 'destroy', or 'update'."
    validates_presence_of :manager_id

    after_create :set_content_file
    after_destroy :cleanup


    def content
        if (!@content)
            @content = ''
            begin
                file = File.open(self.content_file)
                @content = file.read
                file.close
            rescue Exception => error
                self.errors.add_to_base("Error reading #{self.content_file}: #{error}")
            end
        end

        return(@content)
    end

    def content=(txt)
        @content = txt
        write_content!
    end


    # process the content of the message
    # returns true or false on error
    def process_content(rev)
        expected_revision = rev + 1

        # convert content xml to hash
        content_hash = nil
        begin
            content_hash = Hash.from_xml(self.content)
        rescue Exception => error
            self.error_log = "Error decoding content XML from inbox message: #{error}"
            self.queue = 'unprocessable'
            self.save
            return(expected_revision)
        end

        # process content hash
        content_hash.each_pair do |key,val|
            begin
                if (key == 'system_export')
                    expected_revision = 1
                    ordered = ['departments','users','password_histories','configurations',
                               'network_object_groups','network_object_group_entries',
                               'shell_command_object_groups', 'shell_command_object_group_entries','acls',
                               'acl_entries','author_avpairs','author_avpair_entries','avpairs',
                               'command_authorization_profiles', 'command_authorization_profile_entries',
                               'user_groups', 'configured_users', 'command_authorization_whitelist_entries']

                    Manager.transaction do
                        AaaLog.delete_all
                        AaaLogArchive.destroy_all
                        Lock.delete_all("manager_id is null")
                        ConfiguredUser.delete_all
                        PasswordHistory.delete_all
                        UserLastLogin.delete_all
                        User.delete_all
                        UserGroup.delete_all
                        CommandAuthorizationWhitelistEntry.delete_all
                        Avpair.delete_all
                        AuthorAvpairEntry.delete_all
                        AuthorAvpair.delete_all
                        CommandAuthorizationProfileEntry.delete_all
                        CommandAuthorizationProfile.delete_all
                        AclEntry.delete_all
                        Acl.delete_all
                        ShellCommandObjectGroupEntry.delete_all
                        ShellCommandObjectGroup.delete_all
                        NetworkObjectGroupEntry.delete_all
                        NetworkObjectGroup.delete_all
                        Configuration.destroy_all
                        Department.destroy_all

                        ordered.each do |type|
                            if ( val.has_key?(type) && val[type].kind_of?(Array) )
                                val[type].each {|fields| hash_to_model(type.singularize, fields)}
                            end
                        end
                    end
                    Configuration.find(:all).each {|c| c.publish}

                else
                    hash_to_model(key,val)
                end

            rescue Exception => error
                Manager.local.log(:level => 'error', :message => "Unprocessable SystemMessage encountered.")
                self.error_log = "Processing error:\n" + error + "\n" + error.backtrace.join("\n")
                self.queue = 'unprocessable'
                self.save
                return(expected_revision)
            end
        end

        # check revision number
        if (self.revision != expected_revision)
            manager = self.manager
            if (manager.master?)
                msg = "Error processing inbox for #{manager.name}. Expected message with revision #{expected_revision} but was #{self.revision}. Requesting resync."
                Manager.local.log(:level => 'error', :manager_id => manager.id, :message => msg )
                expected_revision = 0
            else
                msg = "Error processing inbox for #{manager.name}. Expected message with revision #{expected_revision} but was #{self.revision}. Adjusting to match slave settings."
                Manager.local.log(:level => 'error', :manager_id => manager.id, :message => msg )
                expected_revision = self.revision
            end

            self.error_log = msg
            self.queue = 'unprocessable'
            self.save
            return(expected_revision)
        end

        self.destroy
        return(expected_revision)
    end

    def to_xml
        content = REXML::Element.new("content")
        content.add_element( REXML::Document.new(self.content) )

        verb = REXML::Element.new("verb")
        verb.text = self.verb

        rev = REXML::Element.new("revision")
        rev.text = self.revision

        message = REXML::Element.new("system-message")
        message.add_element(verb)
        message.add_element(rev)
        message.add_element(content)
        return(message)
    end


private

    def cleanup
        begin
            File.delete(self.content_file) if ( File.exists?(self.content_file) )
        rescue Exception => err
            self.errors.add_to_base("Error removing #{self.content_file}: #{err}")
        end
    end

    def hash_to_model(type,fields)
       if (type == 'manager')
            local = Manager.local
            if ( !local.update_attributes(fields) )
                raise( Exception, local.errors.full_messages.join("\n") )
            end

        elsif (type == 'tacacs_daemon')
            if (self.verb == 'update')
                tacacs_daemon = TacacsDaemon.find(fields['id'])
                raise( tacacs_daemon.errors.full_messages.join("\n") ) if ( !tacacs_daemon.update_attributes(fields) )
            elsif (self.verb == 'create')
                tacacs_daemon = TacacsDaemon.new(fields)
                tacacs_daemon.serial = fields['serial']
                tacacs_daemon.id = fields['id']
                raise( tacacs_daemon.errors.full_messages.join("\n") ) if ( !tacacs_daemon.save )
            else
                tacacs_daemon = TacacsDaemon.find(fields['id'])
                raise( tacacs_daemon.errors.full_messages.join("\n") ) if ( !tacacs_daemon.destroy )
            end

        elsif (type == 'department')
            if (self.verb == 'update')
                department = Deparment.find(fields['id'])
                raise( department.errors.full_messages.join("\n") ) if ( !department.update_attributes(fields) )
            elsif (self.verb == 'create')
                department = Department.new(fields)
                department.id = fields['id']
                raise( department.errors.full_messages.join("\n") ) if ( !department.save )
            else
                department = Department.find(fields['id'])
                raise( department.errors.full_messages.join("\n") ) if ( !department.destroy )
            end

        elsif (type == 'configured_user')
            if (self.verb == 'update')
                configured_user = ConfiguredUser.find(fields['id'])
                raise( configured_user.errors.full_messages.join("\n") ) if ( !configured_user.update_attributes(fields) )
            elsif (self.verb == 'create')
                configured_user = ConfiguredUser.new(fields)
                configured_user.user_id = fields['user_id']
                configured_user.configuration_id = fields['configuration_id']
                configured_user.id = fields['id']
                raise( configured_user.errors.full_messages.join("\n") ) if ( !configured_user.save )
            else
                configured_user = ConfiguredUser.find(fields['id'])
                raise( configured_user.errors.full_messages.join("\n") ) if ( !configured_user.destroy )
            end

        elsif (type == 'user_group')
            if (self.verb == 'update')
                user_group = UserGroup.find(fields['id'])
                raise( user_group.errors.full_messages.join("\n") ) if ( !user_group.update_attributes(fields) )
            elsif (self.verb == 'create')
                user_group = UserGroup.new(fields)
                user_group.configuration_id = fields['configuration_id']
                user_group.id = fields['id']
                raise( user_group.errors.full_messages.join("\n") ) if ( !user_group.save )
            else
                user_group = UserGroup.find(fields['id'])
                raise( user_group.errors.full_messages.join("\n") ) if ( !user_group.destroy )
            end

        elsif (type == 'command_authorization_whitelist_entry')
            if (self.verb == 'update')
                command_authorization_whitelist_entry = CommandAuthorizationWhitelistEntry.find(fields['id'])
                raise( command_authorization_whitelist_entry.errors.full_messages.join("\n") ) if ( !command_authorization_whitelist_entry.update_attributes(fields) )
            elsif (self.verb == 'create')
                command_authorization_whitelist_entry = CommandAuthorizationWhitelistEntry.new(fields)
                command_authorization_whitelist_entry.configuration_id = fields['configuration_id']
                command_authorization_whitelist_entry.id = fields['id']
                raise( command_authorization_whitelist_entry.errors.full_messages.join("\n") ) if ( !command_authorization_whitelist_entry.save )
            else
                command_authorization_whitelist_entry = CommandAuthorizationWhitelistEntry.find(fields['id'])
                raise( command_authorization_whitelist_entry.errors.full_messages.join("\n") ) if ( !command_authorization_whitelist_entry.destroy )
            end

        elsif (type == 'avpair')
            if (self.verb == 'update')
                avpair = Avpair.find(fields['id'])
                raise( avpair.errors.full_messages.join("\n") ) if ( !avpair.update_attributes(fields) )
            elsif (self.verb == 'create')
                avpair = Avpair.new(fields)
                avpair.author_avpair_entry_id = fields['author_avpair_entry_id']
                avpair.id = fields['id']
                raise( avpair.errors.full_messages.join("\n") ) if ( !avpair.save )
            else
                avpair = Avpair.find(fields['id'])
                raise( avpair.errors.full_messages.join("\n") ) if ( !avpair.destroy )
            end

        elsif (type == 'author_avpair_entry')
            if (self.verb == 'update')
                author_avpair_entry = AuthorAvpairEntry.find(fields['id'])
                raise( author_avpair_entry.errors.full_messages.join("\n") ) if ( !author_avpair_entry.update_attributes(fields) )
            elsif (self.verb == 'create')
                author_avpair_entry = AuthorAvpairEntry.new(fields)
                author_avpair_entry.author_avpair_id = fields['author_avpair_id']
                author_avpair_entry.id = fields['id']
                raise( author_avpair_entry.errors.full_messages.join("\n") ) if ( !author_avpair_entry.save )
            else
                author_avpair_entry = AuthorAvpairEntry.find(fields['id'])
                raise( author_avpair_entry.errors.full_messages.join("\n") ) if ( !author_avpair_entry.destroy )
            end

        elsif (type == 'author_avpair')
            if (self.verb == 'update')
                author_avpair = AuthorAvpair.find(fields['id'])
                raise( author_avpair.errors.full_messages.join("\n") ) if ( !author_avpair.update_attributes(fields) )
            elsif (self.verb == 'create')
                author_avpair = AuthorAvpair.new(fields)
                author_avpair.configuration_id = fields['configuration_id']
                author_avpair.id = fields['id']
                raise( author_avpair.errors.full_messages.join("\n") ) if ( !author_avpair.save )
            else
                author_avpair = AuthorAvpair.find(fields['id'])
                raise( author_avpair.errors.full_messages.join("\n") ) if ( !author_avpair.destroy )
            end

        elsif (type == 'command_authorization_profile_entry')
            if (self.verb == 'update')
                command_authorization_profile_entry = CommandAuthorizationProfileEntry.find(fields['id'])
                raise( command_authorization_profile_entry.errors.full_messages.join("\n") ) if ( !command_authorization_profile_entry.update_attributes(fields) )
            elsif (self.verb == 'create')
                command_authorization_profile_entry = CommandAuthorizationProfileEntry.new(fields)
                command_authorization_profile_entry.command_authorization_profile_id = fields['command_authorization_profile_id']
                command_authorization_profile_entry.id = fields['id']
                raise( command_authorization_profile_entry.errors.full_messages.join("\n") ) if ( !command_authorization_profile_entry.save )
            else
                command_authorization_profile_entry = CommandAuthorizationProfileEntry.find(fields['id'])
                raise( command_authorization_profile_entry.errors.full_messages.join("\n") ) if ( !command_authorization_profile_entry.destroy )
            end

        elsif (type == 'command_authorization_profile')
            if (self.verb == 'update')
                command_authorization_profile = CommandAuthorizationProfile.find(fields['id'])
                raise( command_authorization_profile.errors.full_messages.join("\n") ) if ( !command_authorization_profile.update_attributes(fields) )
            elsif (self.verb == 'create')
                command_authorization_profile = CommandAuthorizationProfile.new(fields)
                command_authorization_profile.configuration_id = fields['configuration_id']
                command_authorization_profile.id = fields['id']
                raise( command_authorization_profile.errors.full_messages.join("\n") ) if ( !command_authorization_profile.save )
            else
                command_authorization_profile = CommandAuthorizationProfile.find(fields['id'])
                raise( command_authorization_profile.errors.full_messages.join("\n") ) if ( !command_authorization_profile.destroy )
            end

        elsif (type == 'acl_entry')
            if (self.verb == 'update')
                acl_entry = AclEntry.find(fields['id'])
                raise( acl_entry.errors.full_messages.join("\n") ) if ( !acl_entry.update_attributes(fields) )
            elsif (self.verb == 'create')
                acl_entry = AclEntry.new(fields)
                acl_entry.acl_id = fields['acl_id']
                acl_entry.id = fields['id']
                raise( acl_entry.errors.full_messages.join("\n") ) if ( !acl_entry.save )
            else
                acl_entry = AclEntry.find(fields['id'])
                raise( acl_entry.errors.full_messages.join("\n") ) if ( !acl_entry.destroy )
            end

        elsif (type == 'acl')
            if (self.verb == 'update')
                acl = Acl.find(fields['id'])
                raise( acl.errors.full_messages.join("\n") ) if ( !acl.update_attributes(fields) )
            elsif (self.verb == 'create')
                acl = Acl.new(fields)
                acl.configuration_id = fields['configuration_id']
                acl.id = fields['id']
                raise( acl.errors.full_messages.join("\n") ) if ( !acl.save )
            else
                acl = Acl.find(fields['id'])
                raise( acl.errors.full_messages.join("\n") ) if ( !acl.destroy )
            end

        elsif (type == 'shell_command_object_group_entry')
            if (self.verb == 'update')
                shell_command_object_group_entry = ShellCommandObjectGroupEntry.find(fields['id'])
                   raise( shell_command_object_group_entry.errors.full_messages.join("\n") ) if ( !shell_command_object_group_entry.update_attributes(fields) )
            elsif (self.verb == 'create')
                shell_command_object_group_entry = ShellCommandObjectGroupEntry.new(fields)
                shell_command_object_group_entry.shell_command_object_group_id = fields['shell_command_object_group_id']
                shell_command_object_group_entry.id = fields['id']
                raise( shell_command_object_group_entry.errors.full_messages.join("\n") ) if ( !shell_command_object_group_entry.save )
            else
                shell_command_object_group_entry = ShellCommandObjectGroupEntry.find(fields['id'])
                raise( shell_command_object_group_entry.errors.full_messages.join("\n") ) if ( !shell_command_object_group_entry.destroy )
            end

        elsif (type == 'shell_command_object_group')
            if (self.verb == 'update')
                shell_command_object_group = ShellCommandObjectGroup.find(fields['id'])
                raise( shell_command_object_group.errors.full_messages.join("\n") ) if ( !shell_command_object_group.update_attributes(fields) )
            elsif (self.verb == 'create')
                shell_command_object_group = ShellCommandObjectGroup.new(fields)
                shell_command_object_group.configuration_id = fields['configuration_id']
                shell_command_object_group.id = fields['id']
                raise( shell_command_object_group.errors.full_messages.join("\n") ) if ( !shell_command_object_group.save )
            else
                shell_command_object_group = ShellCommandObjectGroup.find(fields['id'])
                raise( shell_command_object_group.errors.full_messages.join("\n") ) if ( !shell_command_object_group.destroy )
            end

        elsif (type == 'network_object_group_entry')
            if (self.verb == 'update')
                network_object_group_entry = NetworkObjectGroupEntry.find(fields['id'])
                raise( network_object_group_entry.errors.full_messages.join("\n") ) if ( !network_object_group_entry.update_attributes(fields) )
            elsif (self.verb == 'create')
                network_object_group_entry = NetworkObjectGroupEntry.new(fields)
                network_object_group_entry.network_object_group_id = fields['network_object_group_id']
                network_object_group_entry.id = fields['id']
                raise( network_object_group_entry.errors.full_messages.join("\n") ) if ( !network_object_group_entry.save )
            else
                network_object_group_entry = NetworkObjectGroupEntry.find(fields['id'])
                raise( network_object_group_entry.errors.full_messages.join("\n") ) if ( !network_object_group_entry.destroy )
            end

        elsif (type == 'network_object_group')
            if (self.verb == 'update')
                network_object_group = NetworkObjectGroup.find(fields['id'])
                raise( network_object_group.errors.full_messages.join("\n") ) if ( !network_object_group.update_attributes(fields) )
            elsif (self.verb == 'create')
                network_object_group = NetworkObjectGroup.new(fields)
                network_object_group.configuration_id = fields['configuration_id']
                network_object_group.id = fields['id']
                raise( network_object_group.errors.full_messages.join("\n") ) if ( !network_object_group.save )
            else
                network_object_group = NetworkObjectGroup.find(fields['id'])
                raise( network_object_group.errors.full_messages.join("\n") ) if ( !network_object_group.destroy )
            end

        elsif (type == 'configuration')
            if (self.verb == 'update')
                configuration = Configuration.find(fields['id'])
                raise( configuration.errors.full_messages.join("\n") ) if ( !configuration.update_attributes(fields) )
            elsif (self.verb == 'create')
                configuration = Configuration.new(fields)
                configuration.serial = fields['serial']
                configuration.id = fields['id']
                raise( configuration.errors.full_messages.join("\n") ) if ( !configuration.save )
            else
                configuration = Configuration.find(fields['id'])
                if ( !configuration.destroy )
                    raise( configuration.errors.full_messages.join("\n") )
                end
            end

        elsif (type == 'user')
            if (self.verb == 'update')
                user = User.find(fields['id'])
                user.role = fields['role']
                user.salt = fields['salt']
                raise( user.errors.full_messages.join("\n") ) if ( !user.update_attributes(fields) )
            elsif (self.verb == 'create')
                user = User.new(fields)
                user.role = fields['role']
                user.salt = fields['salt']
                user.id = fields['id']
                raise( user.errors.full_messages.join("\n") ) if ( !user.save )
            else
                user = User.find(fields['id'])
                raise( user.errors.full_messages.join("\n") )  if ( !user.destroy )
            end

        elsif (type == 'password_history')
            if (self.verb == 'update')
                password_history = PasswordHistory.find(fields['id'])
                raise( password_history.errors.full_messages.join("\n") )if ( !password_history.update_attributes(fields) )
            elsif (self.verb == 'create')
                password_history = PasswordHistory.new(fields)
                password_history.id = fields['id']
                raise( password_history.errors.full_messages.join("\n") )if ( !password_history.save )
            else
                password_history = PasswordHistory.find(fields['id'])
                raise( password_history.errors.full_messages.join("\n") ) if ( !password_history.destroy )
            end
        elsif (type == 'resequence')
            fields.each_pair do |model, attrs|
                if (model == 'configuration')
                    configuration = Configuration.find(attrs['id'])
                    raise( configuration.errors.full_messages.join("\n") ) if (!configuration.resequence_whitelist!)
                elsif (model == 'acl')
                    acl = Acl.find(attrs['id'])
                    raise( acl.errors.full_messages.join("\n") ) if (!acl.resequence!)
                elsif (model == 'network_object_group')
                    network_object_group = NetworkObjectGroup.find(attrs['id'])
                    raise( network_object_group.errors.full_messages.join("\n") ) if (!network_object_group.resequence!)
                elsif (model == 'shell_command_object_group')
                    shell_command_object_group = ShellCommandObjectGroup.find(attrs['id'])
                    raise( shell_command_object_group.errors.full_messages.join("\n") ) if (!shell_command_object_group.resequence!)
                elsif (model == 'author_avpair')
                    author_avpair = AuthorAvpair.find(attrs['id'])
                    raise( author_avpair.errors.full_messages.join("\n") ) if (!author_avpair.resequence!)
                elsif (model == 'command_authorization_profile')
                    command_authorization_profile = CommandAuthorizationProfile.find(attrs['id'])
                    raise( command_authorization_profile.errors.full_messages.join("\n") ) if (!command_authorization_profile.resequence!)
                end
            end
        elsif (type == 'publish')
            configuration = Configuration.find(fields['id'])
            configuration.publish
        elsif (type == 'aaa_logs')
            configuration = Configuration.find(fields['id'])
            log = fields['log']
            configuration.import_aaa_logs(log)
        elsif (type == 'system_log')
            system_log = SystemLog.new(fields)
            system_log.owning_manager_id = self.manager_id
            raise( system_log.errors.full_messages.join("\n") )if ( !system_log.save )
        end
        return(nil)
    end

    def set_content_file
        self.content_file = File.expand_path("#{RAILS_ROOT}/tmp/system_messages/") + "/#{self.id.to_s}"
        self.save
        write_content!
    end

    def write_content!
        return(false) if (!self.content_file)

        begin
            file = File.open(self.content_file, 'w')
            file.puts(@content)
            file.close
        rescue Exception => error
            self.errors.add_to_base("Error writing #{self.content_file}: #{error}")
            return(false)
        end

        return(true)
    end

end
