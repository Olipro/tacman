class AuthorAvpair < ActiveRecord::Base
    attr_protected :configuration_id

    belongs_to :configuration
    has_many :user_groups, :dependent => :nullify
    has_many :author_avpair_entries, :dependent => :destroy, :order => :sequence
    has_many :configured_users, :dependent => :nullify
    has_many :users, :through => :configured_users
    has_many :system_logs, :dependent => :nullify, :order => :id

    validates_presence_of :configuration_id
    validates_presence_of :name
    validates_uniqueness_of :name, :scope => :configuration_id

    before_destroy :no_delete_if_in_use
    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_update :update_on_remote_managers!


    def configuration_hash
        config = []
        self.author_avpair_entries.each do |entry|
            attrs = {:service => entry.service}
            if (entry.acl_id?)
                attrs[:acl] = entry.acl.name
            end

            if (entry.avpairs.count != 0)
                avpairs = []
                entry.avpairs.each {|x| avpairs.push(x.avpair)}
                attrs[:avpairs] = avpairs
            end
            config.push(attrs)
        end
        return(config)
    end

    def in_use?
        return(true) if (self.user_groups.count > 0 || self.configured_users.count > 0)
        return(false)
    end

    def resequence!
        begin
            seq = 10
            self.author_avpair_entries.each do |e|
                AuthorAvpairEntry.update_all("sequence = #{seq}", "id = #{e.id}")
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
            self.errors.add_to_base("Author AVPair is currently being used.")
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

    def update_on_remote_managers!
        Manager.replicate_to_slaves('update', self.to_xml(:skip_instruct => true) )
    end
end
