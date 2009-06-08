class Avpair < ActiveRecord::Base
    attr_protected :attr, :val, :author_avpair_entry_id

    belongs_to :author_avpair_entry

    validates_presence_of :author_avpair_entry_id
    validates_presence_of :attr
    validates_presence_of :val
    validates_length_of :avpair, :maximum => 255, :if => Proc.new { |x| !x.avpair.blank?}


    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_update :update_on_remote_managers!


    def Avpair.shell_avpairs
        ['acl', 'autocmd', 'callback-line', 'callback-rotary', 'idletime', 'nocallback-verify', 'noescape',
         'nohangup', 'priv-lvl', 'timeout']
    end

    def validate
        if (self.attr == "service")
            self.errors.add_to_base("Attribute 'service' may not be defined twice.")
            return(false)
        end
        return(true)
    end

    def avpair=(str)
        @avpair = str
        begin
            av_parts = TacacsPlus.validate_avpair(@avpair)
            self.attr = av_parts[:attribute]
            self.val = av_parts[:value]
            self.mandatory = av_parts[:mandatory]
        rescue Exception => error
            self.errors.add(:avpair, error)
        end
    end

    def avpair
        return(@avpair) if(!@avpair.blank?)
        return(self.attr + '=' + self.val) if (self.mandatory?)
        return(self.attr + '*' + self.val)
    end

private

    def destroy_on_remote_managers!
        Manager.replicate_to_slaves('destroy', self.to_xml(:skip_instruct => true, :only => :id) )
    end

    def create_on_remote_managers!
        Manager.replicate_to_slaves('create', self.to_xml(:skip_instruct => true, :except => [:attr, :val], :methods => :avpair) )
    end

    def update_on_remote_managers!
        Manager.replicate_to_slaves('update', self.to_xml(:skip_instruct => true, :except => [:attr, :val], :methods => :avpair) )
    end

end
