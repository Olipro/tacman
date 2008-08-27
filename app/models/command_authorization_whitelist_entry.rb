class CommandAuthorizationWhitelistEntry < ActiveRecord::Base
    attr_protected :configuration_id

    belongs_to :configuration
    belongs_to :shell_command_object_group
    belongs_to :acl

    validates_presence_of :configuration_id
    validates_presence_of :shell_command_object_group_id, :if => Proc.new { |x| x.command.blank?}
    validates_presence_of :command, :if => Proc.new { |x| !x.shell_command_object_group_id}
    validates_presence_of :sequence
    validates_uniqueness_of :sequence, :scope => :configuration_id

    before_validation :set_sequence
    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_update :update_on_remote_managers!

    def validate
        if (self.acl_id && self.acl.configuration_id != self.configuration_id)
            self.errors.add_to_base("ACL does not belong to the same Configuration as this Whitelist")
            return(false)
        elsif (self.shell_command_object_group_id && self.shell_command_object_group.configuration_id != self.configuration_id)
            self.errors.add_to_base("Shell Command Object Group does not belong to the same Configuration as this Whitelist")
            return(false)
        end
        return(true)
    end


    def configuration_hash
        attrs = {}

        attrs[:acl] = self.acl.name if (self.acl_id)

        if (self.shell_command_object_group_id?)
            attrs[:shell_command_object_group] = self.shell_command_object_group.name
        else
            attrs[:command] = self.command
        end

        return(attrs)
    end

    def description
        if (self.shell_command_object_group_id)
            str = "shell-command-object-group #{self.shell_command_object_group.name}"
        else
            str = "command /#{self.command}/"
        end
        str << " access-list #{self.acl.name}" if (self.acl_id)
        return(str)
    end

private

    def destroy_on_remote_managers!
        Manager.replicate_to_slaves('destroy', self.to_xml(:skip_instruct => true, :only => :id) )
    end

    def create_on_remote_managers!
        Manager.replicate_to_slaves('create', self.to_xml(:skip_instruct => true) )
    end

    def set_sequence
        if (self.sequence.blank? || self.sequence < 0)
            last = self.configuration.command_authorization_whitelist_entries.find(:first, :order => "sequence desc")
            if (last)
                self.sequence = (last.sequence / 10) * 10 + 10
            else
                self.sequence = 10
            end
        end
    end

    def update_on_remote_managers!
        Manager.replicate_to_slaves('update', self.to_xml(:skip_instruct => true) )
    end

end
