class UserManagerWorker < BackgrounDRb::MetaWorker
    set_worker_name :user_manager_worker

    def create(args = nil)
        # this method is called, when worker is loaded for the first time
    end

    def cleanup_sessions
        # delete inactive sessions older than an hour
        time = (Time.now - 3600).strftime("%Y-%m-%d %H:%M:%S %Z")
        CGI::Session::ActiveRecordStore::Session.delete_all("updated_at < '#{time}'")
    end

    def configuration_changelog
        local_manager = Manager.local
        return(false) if (local_manager.slave? || !local_manager.enable_mailer)

        if (local_manager.enable_mailer)
            today = Date.today.strftime("%Y-%m-%d")
            start_time = today + " 00:00:00"
            end_time = today + " 23:59:59"
            mail_to = []
            Configuration.find(:all).each do |configuration|
                configuration.configured_users.find(:conditions => "role = 'admin'").each {|x| mail_to.push(x.user.email) if (!x.user.email.blank?)}
                logs = configuration.system_logs.find(:all, :conditions => "created_at >= #{start_time} and created_at <= #{end_time}", :order => :created_at)

                if (logs.length > 0)
                    begin
                        TacmanMailer.deliver_logs(local_manager, mail_to, logs, "TacacsManager changelog - #{configuration.name}")
                    rescue Exception => error
                        local_manager.log(:message => "Failed to deliver daily logs - #{error}")
                        return(false)
                    end
                end
            end
        end

        return(true)
    end

    def daily_logs
        local_manager = Manager.local
        return(false) if (local_manager.slave? || !local_manager.enable_mailer)

        if (local_manager.enable_mailer)
            today = Date.today.strftime("%Y-%m-%d")
            start_time = today + " 00:00:00"
            end_time = today + " 23:59:59"
            mail_to = []
            User.find(:all, :conditions => "role = 'admin' and email != null").each {|x| mail_to.push(x.email)}
            logs = SystemLog.find(:all, :conditions => "level != 'info' and created_at >= #{start_time} and created_at <= #{end_time}", :order => :created_at)
            if (logs.length > 0)
                begin
                    TacmanMailer.deliver_logs(local_manager, mail_to, logs)
                rescue Exception => error
                    local_manager.log(:level => 'error', :message => "Failed to deliver daily logs - #{error}")
                    return(false)
                end
            end
        end

        return(true)
    end

    def disable_inactive
        local_manager = Manager.local
        return(false) if (local_manager.slave? || local_manager.disable_inactive_users_after == 0)

        User.find(:all).each do |user|
            if (user.role != 'admin' && !user.disabled && user.inactive?)
                user.toggle_disabled!
                local_manager.log(:user_id=> user.id, :message => "Disabled user '#{user.username}' due to account inactivity for #{local_manager.disable_inactive_users_after} days.")
                begin
                    TacmanMailer.deliver_account_disabled(local_manager, user.email) if (!user.email.blank?)
                rescue Exception => error
                    local_manager.log(:level => 'error', :message => "Failed to deliver daily logs - #{error}")
                    return(false)
                end
            end
        end

        return(true)
    end

    def notify_password_expiry
        local_manager = Manager.local
        return(false) if (local_manager.slave? || !local_manager.enable_mailer)

        day7 = Date.today + 7
        day3 = Date.today + 3
        today = Date.today
        pending7 = []
        pending3 = []
        expired = []
        User.find(:all).each do |user|
            next if (user.email.blank?)
            login = user.login_password
            enable = user.enable_password
            if (login.expires_on == day7 || enable.expires_on == day7)
                pending7.push(user)
            elsif (login.expires_on == day3 || enable.expires_on == day3)
                 pending3.push(user)
            elsif (login.expires_on == today || enable.expires_on == today)
                expired.push(user)
            end
        end

        mail_to = []
        pending7.each do |user|
            mail_to.push(user.email)
        end
        begin
            TacmanMailer.deliver_pending_password_expiry(local_manager, mail_to, 7)
        rescue Exception => error
            local_manager.log(:level => 'error', :message => "Failed to deliver password expiry notifications - #{error}")
        end

        mail_to = []
        pending3.each do |user|
            mail_to.push(user.email)
        end
        begin
            TacmanMailer.deliver_pending_password_expiry(local_manager, mail_to, 3)
        rescue Exception => error
            local_manager.log(:level => 'error', :message => "Failed to deliver password expiry notifications - #{error}")
        end

        mail_to = []
        expired.each do |user|
            mail_to.push(user.email)
        end
        begin
            TacmanMailer.deliver_password_expired(local_manager, mail_to)
        rescue Exception => error
            local_manager.log(:level => 'error', :message => "Failed to deliver password expiry notifications - #{error}")
        end

        return(true)
    end

    def pending_membership_requests
        local_manager = Manager.local
        return(false) if (local_manager.slave? || !local_manager.enable_mailer)

        u_by_conf_id = {}
        admins_by_conf_id = {}
        Configured_user.find(:all, :conditions => "state = 'pending'").each do |cu|
            if ( u_by_conf_id.has_key?(cu.configuration_id) )
                u_by_conf_id[cu.configuration_id].push(cu.user)
            else
                u_by_conf_id[cu.configuration_id] = [cu.user]
            end

            if (cu.admin?)
                if ( admin_by_conf_id.has_key?(cu.configuration_id) )
                    admin_by_conf_id[cu.configuration_id].push(cu.user)
                else
                    admin_by_conf_id[cu.configuration_id] = [cu.user]
                end
            end
        end

        u_by_conf_id.each_pair do |conf_id, users|
            configuration = Configuration.find(conf_id)
            if ( admin_by_conf_id.has_key?(configuration.id) )
                mail_to = []
                admin_by_conf_id[configuration.id].each {|u| mail_to.push(u.email) if (!u.email.blank?)}

                begin
                    TacmanMailer.deliver_pending_membership_requests(local_manager, mail_to, users, configuration)
                rescue Exception => error
                    local_manager.log(:level => 'error', :message => "Failed to deliver password expiry notifications - #{error}")
                end
            end
        end

        return(true)
    end

end

