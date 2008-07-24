class NetworkObjectGroupEntry < ActiveRecord::Base
    attr_protected :network_object_group_id

    belongs_to :network_object_group

    validates_presence_of :network_object_group_id
    validates_presence_of :cidr
    validates_presence_of :sequence
    validates_uniqueness_of :sequence, :scope => :network_object_group_id

    before_validation :set_sequence
    before_create :set_cidr
    before_create :check_max_entries
    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_update :update_on_remote_managers!

    def validate
        if (!self.cidr.blank?)
            begin
                NetAddr::CIDR.create(self.cidr)
            rescue Exception => error
                errors.add_to_base(error)
                return(false)
            end
        end
        return(true)
    end

private

    def check_max_entries
        max = Manager.local.maximum_network_object_group_length
        count = NetworkObjectGroupEntry.count_by_sql "SELECT COUNT(*) FROM network_object_group_entries WHERE network_object_group_id=#{self.network_object_group_id}"
        if (max > 0 && (count >= max) )
            self.errors.add_to_base("Network Object Group exceeds maximum entry count of #{max}.")
            passed = false
        end
        return(true)
    end

    def destroy_on_remote_managers!
        Manager.replicate_to_slaves('destroy', self.to_xml(:skip_instruct => true, :only => :id) )
    end

    def create_on_remote_managers!
        Manager.replicate_to_slaves('create', self.to_xml(:skip_instruct => true) )
    end

    def set_cidr
        self.cidr = NetAddr::CIDR.create(self.cidr).desc
    end

    def set_sequence
        if (self.sequence.blank? || self.sequence < 0)
            last = self.network_object_group.network_object_group_entries.find(:first, :order => "sequence desc")
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