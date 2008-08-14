class User < ActiveRecord::Base
    attr_protected :role, :salt

    belongs_to :department
    has_one :user_last_login, :dependent => :destroy
    has_many :password_histories, :dependent => :destroy
    has_many :configured_users, :dependent => :destroy
    has_many :configurations, :through => :configured_users, :order => :name
    has_many :system_logs, :dependent => :nullify, :order => :id

    validates_inclusion_of :enable_password_lifespan, :in => (0..365)
    validates_inclusion_of :login_password_lifespan, :in => (0..365)
    validates_format_of :role, :with => /(admin|user\_admin|user)/, :message => "must be either 'admin', 'user admin', or 'user'"
    validates_presence_of :salt
    validates_presence_of :username
    validates_uniqueness_of :username, :if => Proc.new { |x| !x.username.blank?}
    validates_length_of :username, :maximum => 255, :if => Proc.new { |x| !x.username.blank?}


    before_validation_on_create :setup
    after_create :create_on_remote_managers!
    after_destroy :destroy_on_remote_managers!
    after_destroy :publish!
    after_update :update_on_remote_managers!


    def validate
        # admins should not be locked out of web interface
        if (self.admin? && !self.allow_web_login)
            self.allow_web_login = true
            self.errors.add(:allow_web_login, "may not be disabled for system administrators.")
            return(false)
        end

        if (self.password_history_length && self.password_history_length < 0)
            self.errors.add(:password_history_length, "must be blank or a non-negative integer.")
            return(false)
        end

        return(true)
    end


    # expects comma delimited string with fields:
    #username, real_name, email, department, salt, login_password, enable_password
    # return hash of errors by username
    def User.import(data)
        errors = {}
        username = nil
        departments = {}
        Department.find(:all).each {|x| departments[x.name] = x.id}
        begin
            User.transaction do
                data.each_line do |line|
                    username,login_password,enable_password,salt,real_name,email,department = line.split(",")
                    user = User.new
                    user.username = username.strip if (username)
                    user.real_name = real_name.strip if (real_name)
                    user.email = email.strip if (email)
                    user.salt = salt.strip if (salt)

                    if (department)
                        department.strip!
                        user.department_id = departments[department] if ( departments.has_key?(department) )
                    end

                    if (user.save)
                        raise "Login and/or enable password missing." if (!login_password || !enable_password)
                        if (!salt.blank?)
                            user.password_histories.create(:password_hash => login_password.strip) if (login_password)
                            user.password_histories.create(:password_hash => enable_password.strip, :is_enable => true) if (enable_password)
                        else
                            user.set_password(login_password.strip,login_password.strip,false)
                            user.set_password(enable_password.strip,enable_password.strip,true)
                        end
                    else
                        errors[username] = user.errors.full_messages
                        raise
                    end
                end
            end
        rescue
        end

        return(errors)
    end

    def User.random_password(size=nil)
        size = 8 if (!size)
        chars = [[], []]
        chars[0] << %w(q w e r t a s d f g z x c v b)
        chars[0] << %w(Q W E R T A S D F G Z X C V B)
        chars[0] << %w(2 3 4 5 6)
        chars[1] << %w(y u p h j k n m)
        chars[1] << %w(Y U P H J K L N M)
        chars[1] << %w(7 8 9)

        cap_char = rand(size)
        num_char = cap_char
        until (num_char != cap_char) do
            num_char = rand(size)
        end
        char_grp = cap_char & 1
        pw = ''
        ( 0..(size-1) ).each do |x|
            if (x == cap_char)
                pw << chars[char_grp][1][ rand( chars[char_grp][1].size ) ]
            elsif (x == num_char)
                pw << chars[char_grp][2][ rand( chars[char_grp][2].size ) ]
            else
                pw << chars[char_grp][0][ rand( chars[char_grp][0].size ) ]
            end

            if (char_grp == 0)
                char_grp = 1
            else
                char_grp = 0
            end
        end
        return(pw)
    end




    def account_status
        return('active') if (!self.disabled?)
        return('disabled')
    end

    def admin!
        self.role = 'admin'
        self.save
    end

    def admin?
        return(true) if self.role == 'admin'
        return(false)
    end

    def change_password(password, confirmation, current, is_enable=false)
        if ( (!is_enable && !self.login_password) || (is_enable && !self.enable_password) )
            self.errors.add_to_base("Password has not been set by an administrator, thus cannot be changed.")
        elsif ( verify_password(current, is_enable) )
            if (password != current && !old_pwd?(password))
                if (is_enable)
                    lifespan = self.enable_password_lifespan
                else
                    lifespan = self.login_password_lifespan
                end

                pwh = self.password_histories.create(:password => password, :password_confirmation => confirmation, 
                                                     :expires_on => Date.today + lifespan,
                                                     :is_enable => is_enable, :salt => self.salt )
                if (pwh.errors.length != 0)
                    pwh.errors.full_messages.each {|e| self.errors.add_to_base(e)}
                    return(false)
                end

                remove_old_histories(is_enable)
                self.publish!
                return(true)
            else
                self.errors.add_to_base("Password has been used before.")
            end
        else
            self.errors.add_to_base("Current password is incorrect.")
        end

        return(false)
    end

    def configuration_hash
        config = {}
        config[:disabled] = true if (self.disabled?)
        config[:enable_password] = self.enable_password.password_hash
        config[:enable_password_expires_on] = self.enable_password.expires_on.to_s if (self.enable_password_lifespan != 0)
        config[:enable_password_lifespan] =  self.enable_password_lifespan if (self.enable_password_lifespan != 0)
        config[:encryption] = 'sha1'
        config[:login_password] = self.login_password.password_hash
        config[:login_password_expires_on] = self.login_password.expires_on.to_s if (self.login_password_lifespan != 0)
        config[:login_password_lifespan] =  self.login_password_lifespan if (self.login_password_lifespan != 0)
        config[:salt] = self.salt
        return(config)
    end

    def enable_password_expired?
        cur = self.enable_password
        if (cur)
            return(true) if (self.enable_password_lifespan > 0 && cur.expired?)
        end
        return(false)
    end

    # return current enable from password history
    def enable_password
        self.password_histories.find(:first, :conditions => "is_enable = true", :order => "id desc")
    end

    def inactive(days=0)
        return(true)  if (days > 0 && !self.within_grace_period? && !self.logged_in_within(days) )
        return(false)
    end

    def last_login
        ll = self.user_last_login
        return(ll.last_login_at) if (ll)
        return(nil)
    end

    # only updates existing if time > current last_login
    def last_login=(time)
        ll = self.user_last_login
        if (ll)
            ll.update_attribute(:last_login_at, time) if (time > ll.last_login_at)
        else
            self.create_user_last_login(:last_login_at => time)
        end
    end

    def logged_in_within(days)
        ll = self.user_last_login
        return(true) if (ll && (ll.last_login_at <=> Date.today - days) == 1)
        return(false)
    end

    # return current password from password history
    def login_password
        self.password_histories.find(:first, :conditions => "is_enable = false", :order => "id desc")
    end

    def login_password_expired?
        cur = self.login_password
        if (cur)
            return(true) if (self.login_password_lifespan > 0 && cur.expired?)
        end
        return(false)
    end

    def publish!
        self.configurations.each {|c| c.publish}
    end

    def set_password(pw,confirmation,is_enable,expire=true)
        expires_on = Date.today
        if (is_enable)
            expires_on = Date.today + self.enable_password_lifespan if (!expire)
            cur = self.enable_password
        else
            expires_on = Date.today + self.login_password_lifespan if (!expire)
            cur = self.login_password
        end

        if (cur)
            cur.update_attributes(:password => pw, :password_confirmation => confirmation, :expires_on => expires_on, :salt => self.salt )
        else
            cur = self.password_histories.create(:password => pw, :password_confirmation => confirmation, :expires_on => expires_on,
                                                 :is_enable => is_enable, :salt => self.salt )
        end

        if (cur.errors.length != 0)
            cur.errors.each_full {|e| self.errors.add_to_base(e) }
            return(false)
        end
        return(true)
    end

    def toggle_allow_web_login!
        if (self.allow_web_login == true )
            self.allow_web_login = false
        else
            self.allow_web_login = true
        end
        self.save
    end

    def toggle_disable_aaa_log_import!
        if (self.disable_aaa_log_import == true )
            self.disable_aaa_log_import = false
        else
            self.disable_aaa_log_import = true
        end
        self.save
    end

    def toggle_disabled!
        if (self.disabled == true )
            self.disabled = false
        else
            self.disabled = true
        end
        self.save
        self.publish!
    end

    def toggle_enable_expiry!
        cur = self.enable_password
        if (cur)
            if (cur.expired?)
                cur.unexpire(self.enable_password_lifespan)
            else
                cur.expire!
            end
        else
            return(false)
        end

        self.publish!
        return(true)
    end

    def toggle_password_expiry!
        cur = self.login_password
        if (cur)
            if (cur.expired?)
                cur.unexpire(self.login_password_lifespan)
            else
                cur.expire!
            end
        else
            return(false)
        end

        self.publish!
        return(true)
    end

    def user!
        self.role = 'user'
        self.save
    end

    def user?
        return(true) if self.role == 'user'
        return(false)
    end

    def user_admin!
        self.role = 'user_admin'
        self.save
    end

    def user_admin?
        return(true) if self.role == 'user_admin'
        return(false)
    end

    def verify_password(pwd, is_enable=false)
        if (is_enable)
            cur = self.enable_password
        else
            cur = self.login_password
        end

        if (cur)
            return( cur.verify(pwd, self.salt) )
        end

        return(false)
    end

    def within_grace_period?
        return(true) if ( (self.created_at.to_date <=> Date.today - 3) == 1 )
        return(false)
    end


private

    def old_pwd?(pwd)
        hsh = PasswordHistory.encrypt(pwd, self.salt)
        return(true) if ( self.password_histories.find_by_password_hash(hsh) )
        return(false)
    end

    def destroy_on_remote_managers!
        Manager.replicate_to_slaves('destroy', self.to_xml(:skip_instruct => true, :only => :id) )
    end

    def create_on_remote_managers!
        Manager.replicate_to_slaves('create', self.to_xml(:skip_instruct => true) )
    end

    def remove_old_histories(is_enable=false)
        if (self.password_history_length)
            count = self.password_history_length
        else
            count = Manager.local.password_history_length
        end

        if (is_enable)
            cur = self.enable_password
            histories = self.password_histories.find(:all,
                                                     :conditions => "is_enable = true and id != #{cur.id}",
                                                     :order => "id desc") if (cur)
        else
            cur = self.login_password
            histories = self.password_histories.find(:all,
                                                     :conditions => "is_enable = false and id != #{cur.id}",
                                                     :order => "id desc") if (cur)
        end

        if (histories && histories.length > (count) )
            histories.slice( (count)..(histories.length-1) ).each {|h| h.destroy}
        end
    end

    def setup
        self.login_password_lifespan = Manager.local.default_login_password_lifespan if (!self.login_password_lifespan)
        self.enable_password_lifespan = Manager.local.default_enable_password_lifespan if (!self.enable_password_lifespan)
        self.salt = (1..16).collect { (i = Kernel.rand(62); i += ((i < 10) ? 48 : ((i < 36) ? 55 : 61 ))).chr }.join if (self.salt.blank?)
    end

    def update_on_remote_managers!
        Manager.replicate_to_slaves('update', self.to_xml(:skip_instruct => true) )
    end

end
