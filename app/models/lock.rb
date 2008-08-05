class Lock < ActiveRecord::Base
    belongs_to :manager
    belongs_to :tacacs_daemon
    belongs_to :configuration

    validates_presence_of :lock_type
    validates_format_of :lock_type, :with => /(aaa|inbox|outbox|publish)/, :message => "must be either 'aaa', 'inbox', 'outbox', or 'publish'."


    def active?
        if (self.expires_at && Time.now < self.expires_at)
            return(true)
        elsif(self.expires_at)
            self.update_attribute(:expires_at, nil)
        end
        return(false)
    end

end
