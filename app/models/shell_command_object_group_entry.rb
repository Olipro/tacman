class ShellCommandObjectGroupEntry < ActiveRecord::Base
    attr_protected :shell_command_object_group_id

    belongs_to :shell_command_object_group

    validates_presence_of :shell_command_object_group_id
    validates_presence_of :command
    validates_presence_of :sequence
    validates_uniqueness_of :sequence, :scope => :shell_command_object_group_id


    before_validation :set_sequence
    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_update :update_on_remote_managers!

private

    def destroy_on_remote_managers!
        Manager.replicate_to_slaves('destroy', self.to_xml(:skip_instruct => true, :only => :id) )
    end

    def create_on_remote_managers!
        Manager.replicate_to_slaves('create', self.to_xml(:skip_instruct => true) )
    end

    def set_sequence
        if (self.sequence.blank? || self.sequence < 0)
            last = self.shell_command_object_group.shell_command_object_group_entries.find(:first, :order => "sequence desc")
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
