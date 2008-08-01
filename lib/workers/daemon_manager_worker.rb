class DaemonManagerWorker < BackgrounDRb::MetaWorker
    set_worker_name :daemon_manager_worker

    def create(args = nil)
        # this method is called, when worker is loaded for the first time
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

