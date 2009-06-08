class AuthorAvpairEntry < ActiveRecord::Base
    attr_protected :author_avpair_id

    belongs_to :acl
    belongs_to :author_avpair
    has_many :avpairs, :dependent => :destroy, :order => :id
    has_many :dynamic_avpairs, :dependent => :destroy
    has_one :network_av, :class_name => 'DynamicAvpair', :conditions => "obj_type = 'network_av'"
    has_one :shell_command_av, :class_name => 'DynamicAvpair', :conditions => "obj_type = 'shell_command_av'"

    validates_presence_of :author_avpair_id
    validates_presence_of :service
    validates_presence_of :sequence
    validates_uniqueness_of :sequence, :scope => :author_avpair_id

    before_validation :set_sequence
    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_update :update_on_remote_managers!

    def validate
        if (self.acl_id && self.acl.configuration_id != self.author_avpair.configuration_id)
            self.errors.add_to_base("ACL does not belong to the same Configuration as this Author AVPair")
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

    def set_sequence
        if (self.sequence.blank? || self.sequence < 0)
            last = self.author_avpair.author_avpair_entries.find(:first, :order => "sequence desc")
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
