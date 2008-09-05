class TacmanMailer < ActionMailer::Base

    def account_disabled(local_manager, mail_to)
        bcc(mail_to)
        subject("Your TACACS+ account is disabled")
        body(:message => local_manager.mail_account_disabled)
        from(local_manager.mail_from)
    end

    def logs(local_manager, mail_to, logs, subject="TacacsManager logs")
        managers = {local_manager.id => local_manager}
        Manager.non_local.each {|m| managers[m.id] = m}
        bcc(mail_to)
        subject(subject)
        body(:logs => logs, :managers => managers)
        from(local_manager.mail_from)
    end

    def new_account(local_manager, user, login_pw, enable_pw)
        recipients(user.email)
        subject("Your TACACS+ account has been created")
        body(:user => user, :login_password => login_pw, :enable_password => enable_pw, :message => local_manager.mail_new_account)
        from(local_manager.mail_from)
    end

    def password_expired(local_manager, mail_to)
        bcc(mail_to)
        subject("Your TACACS+ passwords have expired")
        body(:message => local_manager.mail_password_expired)
        from(local_manager.mail_from)
    end

    def password_reset(local_manager, user, pw, pw_type)
        recipients(user.email)
        subject("Your TACACS+ #{pw_type} password has been reset")
        body(:user => user, :password => pw, :pw_type => pw_type, :message => local_manager.mail_password_reset)
        from(local_manager.mail_from)
    end

    def pending_password_expiry(local_manager, mail_to, days)
        bcc(mail_to)
        subject("Your TACACS+ passwords expire in #{days} days")
        body(:message => local_manager.mail_pending_password_expiry)
        from(local_manager.mail_from)
    end

    def unknown_users_log(local_manager, mail_to, failed_users, devices, subject)
        devices = {}
        full_list = ""
        failed_users.keys.sort.each do |user|
            failed_users[user].keys.sort.each do |client|
                full_list << "#{user}, #{client}, #{failed_users[user][client]}\n"
            end
        end

        device_list = ""
        devices.keys.sort.each do |client|
            device_list << "#{client}, #{devices[client]}\n"
        end

        managers = {local_manager.id => local_manager}
        bcc(mail_to)
        subject(subject)
        body(:full_list => full_list, :device_list => device_list )
        from(local_manager.mail_from)
    end

end
