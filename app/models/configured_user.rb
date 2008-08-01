class ConfiguredUser < ActiveRecord::Base
    attr_protected :configuration_id, :user_id

    belongs_to :configuration
    belongs_to :user
    belongs_to :author_avpair
    belongs_to :command_authorization_profile
    belongs_to :user_group
    belongs_to :enable_acl, :class_name => 'Acl', :foreign_key => :enable_acl_id
    belongs_to :login_acl, :class_name => 'Acl', :foreign_key => :login_acl_id
    has_many :system_logs, :dependent => :nullify, :order => :id

    validates_presence_of :configuration_id
    validates_presence_of :user_id
    validates_uniqueness_of :user_id, :scope => :configuration_id
    validates_format_of :role, :with => /(admin|viewer|user)/, :message => "must be either 'admin', 'viewer', or 'user'."

    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_update :update_on_remote_managers!


    def activate!
        self.is_active = true
        self.save
    end

    def active?
        return(true) if (self.is_active)
        return(false)
    end

    def admin!
        self.role = 'admin'
        self.save
    end

    def admin?
        return(true) if self.role == 'admin'
        return(false)
    end

    def overrides_user_group?
        return(true) if (self.user_group_id && (self.author_avpair_id || self.command_authorization_profile_id || self.login_acl_id || self.enable_acl_id) )
        return(false)
    end

    def status
        return('active') if (self.is_active)
        return('suspended')
    end

    def suspend!
        self.is_active = false
        self.save
    end

    def suspended?
        return(true) if (!self.is_active)
        return(false)
    end

    def user!
        self.role = 'user'
        self.save
    end

    def user?
        return(true) if self.role == 'user'
        return(false)
    end

    def viewer!
        self.role = 'viewer'
        self.save
    end

    def viewer?
        return(true) if self.role == 'viewer'
        return(false)
    end


private

    def destroy_on_remote_managers!
        Manager.replicate_to_slaves('destroy', self.to_xml(:skip_instruct => true, :only => :id) )
    end

    def create_on_remote_managers!
        Manager.replicate_to_slaves('create', self.to_xml(:skip_instruct => true) )
    end

    def update_on_remote_managers!
        Manager.replicate_to_slaves('update', self.to_xml(:skip_instruct => true) )
    end

end
