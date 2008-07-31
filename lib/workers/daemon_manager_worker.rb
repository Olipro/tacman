class DaemonManagerWorker < BackgrounDRb::MetaWorker
    set_worker_name :daemon_manager_worker

    def create(args = nil)
        # this method is called, when worker is loaded for the first time
    end

    def check_status
        local_manager = Manager.local
        configurations = {}
        Configuration.find(:all).each {|c| configurations[c.id] = c }

        TacacsDaemon.find(:all, :conditions => "is_monitored = true and manager_id = null").each do |tacacs_daemon|
            thread_pool.defer(tacacs_daemon) do |td|
                alive = TacacsPlus::Client.new(:server => td.ip, :port => td.port,
                                               :key => configurations[td.configuration_id].key).server_alive?

                if (alive)
                    td.up! if (td.is_down)
                else
                    td.down!
                    mail_to = []
                    subj = "#{td.name} is down!"
                    message = "TACACS+ Daemon #{td.name} (#{td.ip}:#{td.port}) failed to respond to monitoring."
                    local_manager.log(:level => 'warn', :tacacs_daemon_id => td.id, :message => message)

                    if (local_manager.enable_mailer)
                        configurations[td.configuration_id].configured_users.find(:all, :conditions => "role = 'admin'").each do |cu|
                            user = cu.user
                            if (!user.alerts_email.blank?)
                                mail_to.push(user.alerts_email)
                            elsif (!user.email.blank?)
                                mail_to.push(user.email)
                            end
                        end

                        if (mail_to.length > 0)
                            begin
                                TacmanMailer.deliver_alert(local_manager, mail_to, subj, message)
                            rescue Exception => error
                            end
                        end
                    end
                end
            end
        end
    end

    def gather_aaa_logs
         TacacsDaemon.find(:all, :conditions => "manager_id is null").each do |td|
            td.gather_aaa_logs!
            if (td.errors.length > 0)
                errors = td.errors.full_messages.join(' ')
                Manager.local.log(:level => 'warn', :tacacs_daemon_id => td.id,
                                :message => "DaemonManager#gather_aaa_logs - #{td.name}: #{errors}")
            end
         end
    end

end

