class TacmanMailer < ActionMailer::Base

    def account_disabled(local_manager, mail_to)
        bcc(mail_to)
        subject("Your TacacsManager account is disabled")
        body(:message => local_manager.mail_account_disabled)
        from(local_manager.mail_from)
    end

    def alert(local_manager, mail_to, subj, message)
        bcc(mail_to)
        subject(subj)
        body(:message => message)
        from(local_manager.mail_from)
    end

    def logs(local_manager, mail_to, logs, subject="TacacsManager logs")
        bcc(mail_to)
        subject(subject)
        body(:logs => logs)
        from(local_manager.mail_from)
    end

    def new_account(local_manager, user, login_pw, enable_pw)
        recipients(user.email)
        subject("Your TacacsManager account has been created")
        body(:user => user, :login_password => login_pw, :enable_password => enable_pw, :message => local_manager.mail_new_account)
        from(local_manager.mail_from)
    end

    def password_expired(local_manager, mail_to)
        bcc(mail_to)
        subject("Your TacacsManager passwords have expired")
        body(:message => local_manager.mail_password_expired)
        from(local_manager.mail_from)
    end

    def password_reset(local_manager, user, pw, pw_type)
        recipients(user.email)
        subject("Your TacacsManager #{pw_type} password has been reset")
        body(:user => user, :password => pw, :pw_type => pw_type, :message => local_manager.mail_password_reset)
        from(local_manager.mail_from)
    end

    def pending_password_expiry(local_manager, mail_to, days)
        bcc(mail_to)
        subject("Your TacacsManager passwords expire in #{days} days")
        body(:message => local_manager.mail_pending_password_expiry)
        from(local_manager.mail_from)
    end

    def pending_membership_requests(local_manager, mail_to, users, configuration)
        bcc(mail_to)
        subject("Pending TacacsManager membership requests")
        body(:users => users, :configuration => configuration)
        from(local_manager.mail_from)
    end

end
