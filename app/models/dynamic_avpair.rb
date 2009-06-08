class DynamicAvpair < ActiveRecord::Base
    attr_protected :author_avpair_entry_id

    belongs_to :author_avpair_entry
    has_many :dynamic_avpair_values, :dependent => :destroy, :order => :id
    has_many :network_object_groups, :through => :dynamic_avpair_values, :order => :name
    has_many :shell_command_object_groups, :through => :dynamic_avpair_values, :order => :name

    validates_presence_of :author_avpair_entry_id
    validates_presence_of :obj_type
    validates_presence_of :delimiter

    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_update :update_on_remote_managers!


    def validate
        if(self.obj_type != 'network_av' && self.obj_type != 'shell_command_av')
            self.errors.add_to_base("obj_type must be either network_av or shell_command_av.")
            return(false)
        end

        if(self.attr.blank?)
            self.errors.add_to_base("Attribute can't be blank.")
            return(false)
        end

        if (self.attr !~ /=$/ && self.attr !~ /\*$/)
            self.errors.add_to_base("Attribute must end with either a '=' or '*'.")
            return(false)
        end

        return(true)
    end

    def configuration_hash
        config = {:attribute => self.attr, :delimiter => self.delimiter}
        vals = []
        self.dynamic_avpair_values.each do |v|
            if (self.obj_type == 'network_av')
                vals.push(v.network_object_group.name)
            else
                vals.push(v.shell_command_object_group.name)
            end
        end
        config[:value] = vals
        return(config)
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
