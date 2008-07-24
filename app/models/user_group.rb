class UserGroup < ActiveRecord::Base
    attr_protected :configuration_id

    belongs_to :configuration
    belongs_to :author_avpair
    belongs_to :command_authorization_profile
    belongs_to :enable_acl, :class_name => 'Acl', :foreign_key => :enable_acl_id
    belongs_to :login_acl, :class_name => 'Acl', :foreign_key => :login_acl_id
    has_many :configured_users, :dependent => :nullify
    has_many :system_logs, :dependent => :nullify, :order => :id

    validates_presence_of :configuration_id
    validates_presence_of :name
    validates_uniqueness_of :name, :scope => :configuration_id

    before_save :set_name
    before_destroy :no_delete_if_in_use
    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_update :update_on_remote_managers!

    def validate
        if (self.command_authorization_profile_id && self.command_authorization_profile.configuration_id != self.configuration_id)
            self.errors.add_to_base("Command Authorization Profile does not belong to the same Configuration as this User Group")
            return(false)
        elsif (self.enable_acl_id && self.enable_acl.configuration_id != self.configuration_id)
            self.errors.add_to_base("Enable ACL does not belong to the same Configuration as this User Group")
            return(false)
        elsif (self.login_acl_id && self.login_acl.configuration_id != self.configuration_id)
            self.errors.add_to_base("Login ACL does not belong to the same Configuration as this User Group")
            return(false)
        elsif (self.author_avpair_id && self.author_avpair.configuration_id != self.configuration_id)
            self.errors.add_to_base("Author AvPair does not belong to the same Configuration as this User Group")
            return(false)
        end
        return(true)
    end

    def configuration_hash
        config = {}
        config[:enable_acl] = self.enable_acl.name if (self.enable_acl_id?)
        config[:login_acl] = self.login_acl.name if (self.login_acl_id?)
        config[:author_avpair] = self.author_avpair.name if (self.author_avpair_id?)
        config[:command_authorization_profile] = self.command_authorization_profile.name if (self.command_authorization_profile_id?)
        return(config)
    end

    def in_use?
        return(true) if (self.configured_users.count > 0)
        return(false)
    end

private

    def no_delete_if_in_use
        if (self.in_use?)
            self.errors.add_to_base("Shell Command Object Group is currently being used.")
            return(false)
        end
        return(true)
    end

    def destroy_on_remote_managers!
        Manager.replicate_to_slaves('destroy', self.to_xml(:skip_instruct => true, :only => :id) )
    end

    def create_on_remote_managers!
        Manager.replicate_to_slaves('create', self.to_xml(:skip_instruct => true) )
    end

    def set_name
        self.name = self.name.strip.squeeze(" ").gsub(/ /, '_').downcase
    end

    def update_on_remote_managers!
        Manager.replicate_to_slaves('update', self.to_xml(:skip_instruct => true) )
    end

end
