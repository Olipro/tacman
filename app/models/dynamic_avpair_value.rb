class DynamicAvpairValue < ActiveRecord::Base
    attr_protected :dynamic_avpair_id

    belongs_to :dynamic_avpair
    belongs_to :network_object_group
    belongs_to :shell_command_object_group

    validates_presence_of :dynamic_avpair_id

    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_update :update_on_remote_managers!

    def validate
        if(self.network_object_group_id.nil? && self.shell_command_object_group_id.nil?)
            self.errors.add_to_base("must provide either a network_object_group_id or shell_command_object_group_id")
            return(false)
        end

        return(true)
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
