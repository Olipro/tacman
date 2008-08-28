class DailyWorker < BackgrounDRb::MetaWorker
    set_worker_name :daily_worker
    reload_on_schedule true

    def create(args = nil)
        # this method is called, when worker is loaded for the first time
    end

    def daily_tasks
        @local_manager = Manager.local
        @configurations = Configuration.find(:all)
        disable_inactive
        cleanup_logs
        mail_configuration_changelog
        mail_daily_logs
        mail_password_expiry
        tacacs_daemon_maintenance
        cleanup_unprocessable_queue
    end


private

    def cleanup_logs

        # archive system logs
        SystemLogArchive.archive if (!@local_manager.slave?)

        # cleanup db and old archive files
        SystemLogArchive.cleanup_logs!
        SystemLogArchive.cleanup_archives!
        SystemLogArchive.zip_old_archives!
        AaaLogArchive.zip_old_archives!

        # cleanup db and old aaa archive files
        @configurations.each do |configuration|
            configuration.cleanup_logs!
            configuration.cleanup_archives!
        end
    end

    def cleanup_unprocessable_queue
        # delete unprocessable messages older than 10 days
        date = (Date.today - 10).to_s
        datetime = date + ' 23:59:59'
        SystemMessage.delete_all("queue = 'unprocessable' and created_at <= '#{datetime}'")
    end

    def disable_inactive
        return(false) if (@local_manager.slave? || @local_manager.disable_inactive_users_after == 0)

        mail_to = []
        User.find(:all).each do |user|
            if (!user.admin? && !user.disabled && user.inactive(@local_manager.disable_inactive_users_after) )
                user.toggle_disabled!
                @local_manager.log(:user_id=> user.id, :message => "Auto-disabled user #{user.username} due to account inactivity for #{@local_manager.disable_inactive_users_after} days.")
                mail_to.push(user.email) if (!user.email.blank?)
            end
        end

        if (@local_manager.enable_mailer)
            begin
                TacmanMailer.deliver_account_disabled(@local_manager, mail_to) if (mail_to.length > 0)
            rescue Exception => error
                @local_manager.log(:level => 'error', :message => "Failed to deliver account auto-disable message - #{error}")
                return(false)
            end
        end

        return(true)
    end

    def mail_configuration_changelog
        return(false) if (@local_manager.slave? || !@local_manager.enable_mailer)

        if (@local_manager.enable_mailer)
            yesterday = (Date.today - 1).strftime("%Y-%m-%d")
            start_time = yesterday + " 00:00:00"
            end_time = yesterday + " 23:59:59"
            @configurations.each do |configuration|
                mail_to = []
                configuration.configured_users.find(:all, :conditions => "role = 'admin'").each {|x| mail_to.push(x.user.email) if (!x.user.email.blank?)}
                logs = configuration.system_logs.find(:all, :conditions => "created_at >= '#{start_time}' and created_at <= '#{end_time}'", :order => :created_at)

                if (logs.length > 0 && mail_to.length > 0)
                    begin
                        TacmanMailer.deliver_logs(@local_manager, mail_to, logs, "TacacsManager changelog - #{configuration.name}")
                    rescue Exception => error
                        @local_manager.log(:message => "Failed to deliver daily logs - #{error}")
                        return(false)
                    end
                end
            end
        end

        return(true)
    end

    def mail_daily_logs
        return(false) if (@local_manager.slave? || !@local_manager.enable_mailer)

        if (@local_manager.enable_mailer)
            yesterday = (Date.today - 1).strftime("%Y-%m-%d")
            start_time = yesterday + " 00:00:00"
            end_time = yesterday + " 23:59:59"
            mail_to = []
            User.find(:all, :conditions => "role = 'admin' and email is not null").each {|x| mail_to.push(x.email)}
            logs = SystemLog.find(:all, :conditions => "level != 'info' and created_at >= '#{start_time}' and created_at <= '#{end_time}'", :order => :created_at)
            if (logs.length > 0 && mail_to.length > 0)
                begin
                    TacmanMailer.deliver_logs(@local_manager, mail_to, logs)
                rescue Exception => error
                    @local_manager.log(:level => 'error', :message => "Failed to deliver daily logs - #{error}")
                    return(false)
                end
            end
        end

        return(true)
    end

    def mail_password_expiry
        return(false) if (@local_manager.slave? || !@local_manager.enable_mailer)

        day7 = Date.today + 7
        day3 = Date.today + 3
        today = Date.today
        pending7 = []
        pending3 = []
        expired = []
        User.find(:all, :conditions => "disabled = false").each do |user|
            next if (user.email.blank?)
            login = user.login_password
            enable = user.enable_password
            pending7.push(user) if (login.expires_on == day7 || enable.expires_on == day7)
            pending3.push(user) if (login.expires_on == day3 || enable.expires_on == day3)
            expired.push(user) if (login.expires_on == today || enable.expires_on == today)
        end

        mail_to = []
        pending7.each do |user|
            mail_to.push(user.email)
        end
        begin
            TacmanMailer.deliver_pending_password_expiry(@local_manager, mail_to, 7) if (mail_to.length > 0)
        rescue Exception => error
            @local_manager.log(:level => 'error', :message => "Failed to deliver password expiry notifications - #{error}")
        end

        mail_to = []
        pending3.each do |user|
            mail_to.push(user.email)
        end
        begin
            TacmanMailer.deliver_pending_password_expiry(@local_manager, mail_to, 3) if (mail_to.length > 0)
        rescue Exception => error
            @local_manager.log(:level => 'error', :message => "Failed to deliver password expiry notifications - #{error}")
        end

        mail_to = []
        expired.each do |user|
            mail_to.push(user.email)
        end
        begin
            TacmanMailer.deliver_password_expired(@local_manager, mail_to) if (mail_to.length > 0)
        rescue Exception => error
            @local_manager.log(:level => 'error', :message => "Failed to deliver password expiry notifications - #{error}")
        end

        return(true)
    end

    def tacacs_daemon_maintenance
        TacacsDaemon.find(:all, :conditions => 'manager_id = null').each do |td|
            # rotate error log file
            if (File.size(td.error_log_file) < 500000)
                bak = td.error_log_file + '.bak'
                begin
                    File.delete(bak) if ( File.exists?(bak) )
                    FileUtils.mv(td.error_log_file, bak)
                    FileUtils.touch(td.error_log_file)
                rescue Exception => err
                    @local_manager.log(:level => 'error', :message => "Error rotating error_log_file for #{td.name}:#{error}")
                end
            end
            td.restart
        end
    end

end

