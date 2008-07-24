class AclEntry < ActiveRecord::Base
    attr_protected :acl_id

    belongs_to :acl
    belongs_to :network_object_group

    validates_presence_of :acl_id
    validates_presence_of :network_object_group_id, :if => Proc.new { |x| x.ip.blank?}
    validates_presence_of :acl_id
    validates_presence_of :network_object_group_id, :if => Proc.new { |x| x.ip.blank?}
    validates_presence_of :ip, :if => Proc.new { |x| x.network_object_group_id.nil?}
    validates_format_of :permission, :with => /^(permit|deny)$/
    validates_presence_of :sequence
    validates_uniqueness_of :sequence, :scope => :acl_id

    before_validation :set_wildcard_mask_if_null
    before_validation :set_sequence
    before_create :check_max_entries
    before_create :set_ip
    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_update :update_on_remote_managers!


    def validate
        if (!self.ip.blank? && self.ip != 'any')
            begin
                NetAddr::CIDR.create(self.ip, :WildcardMask => [self.wildcard_mask, true])
            rescue Exception => error
                errors.add_to_base(error)
                return(false)
            end
        end

        if (self.network_object_group_id && self.network_object_group.configuration_id != self.acl.configuration_id)
            self.errors.add_to_base("Network Object Group does not belong to the same Configuration as this ACL")
            return(false)
        end

        return(true)
    end


    def description
        if (self.network_object_group_id)
            str = "network object group '#{self.network_object_group.name}' "
        else
            str = "ip #{self.ip} #{self.wildcard_mask}"
        end
        return(str)
    end


private

    def check_max_entries
        max = Manager.local.maximum_acl_length
        count = AclEntry.count_by_sql "SELECT COUNT(*) FROM acl_entries WHERE acl_id=#{self.acl_id}"
        if (max > 0 && (count >= max) )
            self.errors.add_to_base("ACL exceeds maximum entry count of #{max}.")
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

    def set_ip
        self.ip = NetAddr::CIDR.create(self.ip).ip if (!self.ip.blank? && self.ip != 'any')
    end

    def set_sequence
        if (self.sequence.blank? || self.sequence < 0)
            last = self.acl.acl_entries.find(:first, :order => "sequence desc")
            if (last)
                self.sequence = (last.sequence / 10) * 10 + 10
            else
                self.sequence = 10
            end
        end
    end

    def set_wildcard_mask_if_null
        self.wildcard_mask = '0.0.0.0' if (!self.ip.blank? && self.ip != 'any' && self.wildcard_mask.blank?)
    end

    def update_on_remote_managers!
        Manager.replicate_to_slaves('update', self.to_xml(:skip_instruct => true) )
    end

end
