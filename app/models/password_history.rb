class PasswordHistory < ActiveRecord::Base
    belongs_to :user


    attr_accessor :password, :password_confirmation, :salt


    validates_confirmation_of :password
    validates_presence_of :user_id
    validates_presence_of :password_hash
    validates_presence_of :expires_on


    before_validation :set_password
    before_validation_on_create :setup
    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_update :update_on_remote_managers!

    def validate
        pass = true
        if (@password)

            if (@salt.nil?)
                self.errors.add_to_base("A 'salt' string must be provided in order to properly encrypt the password.")
                pass = false
            end

            manager = Manager.local

            if (manager.password_require_mixed_case && @password !~ /(?=.*[a-z])(?=.*[A-Z])/)
                self.errors.add(:password, 'must contain a mix of upper and lower case characters.')
                pass = false
            end

            if (manager.password_require_alphanumeric && @password !~ /(?=.*[\x20-\x40\x5b-\x60\x7b-\x7e])(?=.*[a-zA-Z])/ )
                self.errors.add(:password, 'must contain letters, and numbers or special characters.')
                pass = false
            end

            if (@password.length < manager.password_minimum_length)
                if (self.is_enable)
                    self.errors.add_to_base("Enable password must be at least #{manager.password_minimum_length} characters.")
                else
                    self.errors.add_to_base("Login password must be at least #{manager.password_minimum_length} characters.")
                end
                pass = false
            end

            if (@password.length > 255)
                self.errors.add(:password, "must be 255 characters or less.")
                pass = false
            end
        end

        return(pass)
    end

    def PasswordHistory.encrypt(str,salt)
        return( Digest::SHA1.hexdigest(str + salt) )
    end

    def expire!
        self.update_attribute(:expires_on, Date.today)
    end

    def expired?
        return(true) if (Date.today >= self.expires_on)
        return(false)
    end

    def unexpire(days)
        self.update_attribute(:expires_on, Date.today + days)
    end

    def verify(pwd, salt)
        return(true) if (PasswordHistory.encrypt(pwd, salt) == self.password_hash)
        return(false)
    end

private

    def destroy_on_remote_managers!
        Manager.replicate_to_slaves('destroy', self.to_xml(:skip_instruct => true, :only => [:id]))
    end

    def create_on_remote_managers!
        Manager.replicate_to_slaves('create', self.to_xml(:skip_instruct => true) )
    end

    def update_on_remote_managers!
        Manager.replicate_to_slaves('update', self.to_xml(:skip_instruct => true) )
    end

    def set_password
        if (@password && @salt)
            self.password_hash = PasswordHistory.encrypt(@password, @salt)
        end
    end

    def setup
        self.expires_on = Date.today if (!self.expires_on)
    end

end
