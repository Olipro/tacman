class Acl < ActiveRecord::Base
    attr_protected :configuration_id

    belongs_to :configuration
    has_many :acl_entries, :dependent => :destroy, :order => :sequence
    has_many :command_authorization_profile_entries
    has_many :command_authorization_whitelist_entries
    has_many :author_avpair_entries
    has_many :user_group_enable_acls, :class_name => 'UserGroup', :foreign_key => :enable_acl_id
    has_many :user_group_login_acls, :class_name => 'UserGroup', :foreign_key => :login_acl_id
    has_many :user_enable_acls, :class_name => 'ConfiguredUser', :foreign_key => :enable_acl_id
    has_many :user_login_acls, :class_name => 'ConfiguredUser', :foreign_key => :login_acl_id
    has_many :system_logs, :dependent => :nullify, :order => :id

    validates_presence_of :configuration_id
    validates_presence_of :name
    validates_uniqueness_of :name, :scope => :configuration_id

    before_save :set_name
    before_destroy :no_delete_if_in_use
    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_update :update_on_remote_managers!


    def configuration_hash
        config = []
        self.acl_entries.each do |entry|
            attrs = {:permission => entry.permission}
            if (entry.ip?)
                attrs[:ip] = entry.ip
                attrs[:wildcard_mask] = entry.wildcard_mask if (!entry.wildcard_mask.blank?)
            else
                attrs[:network_object_group] = entry.network_object_group.name
            end
            config.push(attrs)
        end
        return(config)
    end

    def in_use?
        return(true) if (self.user_group_login_acls.count > 0 || self.user_group_enable_acls.count > 0 ||
                         self.user_login_acls.count > 0 || self.user_enable_acls.count > 0 ||
                         self.command_authorization_profile_entries.count > 0 || self.author_avpair_entries.count > 0 ||
                         self.command_authorization_whitelist_entries.count > 0)
        return(false)
    end

    def resequence!
        begin
            seq = 10
            self.acl_entries.each do |e|
                AclEntry.update_all("sequence = #{seq}", "id = #{e.id}")
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

private

    def no_delete_if_in_use
        if (self.in_use?)
            self.errors.add_to_base("ACL is currently being used.")
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
