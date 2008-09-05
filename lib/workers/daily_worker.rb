class DailyWorker < BackgrounDRb::MetaWorker
    set_worker_name :daily_worker
    reload_on_schedule true

    def create(args = nil)
        # this method is called, when worker is loaded for the first time
    end

    def daily_tasks
        @local_manager = Manager.local
        @configurations = Configuration.find(:all)

        if (@local_manager.master?)
            disable_inactive
            check_remote_queues
            check_local_queues
            mail_daily_logs
            mail_configuration_logs
            mail_password_expiry
        end

        tacacs_daemon_maintenance
        cleanup_unprocessable_queue
        cleanup_logs
    end


private

    def check_remote_queues
        Manager.non_local.each do |m|
            status = m.check_remote_queue_status
            if (status)
                status.each_pair do |name,queues|
                    @local_manager.log(:level => 'warn', :message => "Detected possible stuck inbox queue for #{name} on #{m.name}") if (queues[:inbox] == :stuck)
                    @local_manager.log(:level => 'warn', :message => "Detected possible stuck outbox queue for #{name} on #{m.name}") if (queues[:outbox] == :stuck)
                end
            else
                @local_manager.log(:manager_id => m.id, :message => "DailyWorker#check_remote_queues - queue status check failed for #{m.name}: #{m.errors.full_messages.join(' ')}")
            end
        end
    end

    def check_local_queues
        time = Time.now - 10800
        Manager.non_local.each do |m|
            out_msg = m.system_messages.find(:first, :conditions => "queue = 'outbox'", :order => :id)
            in_msg = m.system_messages.find(:first, :conditions => "queue = 'inbox'", :order => :id)
            @local_manager.log(:level => 'warn', :message => "Detected possible stuck outbox queue for #{m.name} on #{@local_manager.name}") if (out_msg && time > out_msg.created_at)
            @local_manager.log(:level => 'warn', :message => "Detected possible stuck inbox queue for #{m.name} on #{@local_manager.name}") if (in_msg && time > in_msg.created_at)
        end
    end

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
        return(false) if (@local_manager.disable_inactive_users_after == 0)

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

    def mail_configuration_logs
        return(false) if (!@local_manager.enable_mailer)

        yesterday = (Date.today - 1).strftime("%Y-%m-%d")
        @configurations.each do |configuration|
            start_time = yesterday + Time.now.strftime(" %H:%M:%S")
            mail_to = []
            configuration.configured_users.find(:all, :conditions => "role = 'admin'").each {|x| mail_to.push(x.user.email) if (!x.user.email.blank?)}
            next if (mail_to.length == 0)

            logs = configuration.system_logs.find(:all, :conditions => "created_at >= '#{start_time}'", :order => :created_at)
            if (logs.length > 0)
                begin
                    TacmanMailer.deliver_logs(@local_manager, mail_to, logs, "TacacsManager changelog - #{configuration.name}")
                rescue Exception => error
                    @local_manager.log(:level => 'error', :message => "Failed to deliver changelog - #{error}")
                    return(false)
                end
            end

            failed_users = {}
            devices = {}
            configuration.aaa_logs.find(:all, :conditions => "timestamp >= '#{start_time}' and message='Unknown user attempted authentication.'").each do |msg|
                if ( failed_users.has_key?(msg.user) )
                    if ( failed_users[msg.user].has_key?(msg.client) )
                        failed_users[msg.user][msg.client] += 1
                    else
                        failed_users[msg.user][msg.client] = 1
                    end
                else
                    failed_users[msg.user] = {msg.client => 1}
                end

                if ( devices.has_key?(msg.client) )
                    devices[msg.client] += 1
                else
                    devices[msg.client] = 1
                end
            end

            if (devices.keys.length > 0)
                begin
                    TacmanMailer.deliver_unknown_users_log(@local_manager, mail_to, failed_users, devices, "Unauthorized Login Attempts - #{configuration.name}")
                rescue Exception => error
                    @local_manager.log(:level => 'error', :message => "Failed to deliver unauthorized user logs - #{error}")
                    return(false)
                end
            end
        end
    end

    def mail_daily_logs
        return(false) if (!@local_manager.enable_mailer)

        yesterday = (Date.today - 1).strftime("%Y-%m-%d")
        start_time = yesterday + Time.now.strftime(" %H:%M:%S")

        mail_to = []
        User.find(:all, :conditions => "role = 'admin' and email is not null").each {|x| mail_to.push(x.email)}
        return(true) if (mail_to.length == 0)

        logs = SystemLog.find(:all, :conditions => "level != 'info' and created_at >= '#{start_time}'", :order => :created_at)
        if (logs.length > 0)
            begin
                TacmanMailer.deliver_logs(@local_manager, mail_to, logs)
            rescue Exception => error
                @local_manager.log(:level => 'error', :message => "Failed to deliver daily logs - #{error}")
                return(false)
            end
        end

        return(true)
    end

    def mail_password_expiry
        return(false) if (!@local_manager.enable_mailer)

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

