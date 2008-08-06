class AaaLogWorker < BackgrounDRb::MetaWorker
    set_worker_name :aaa_log_worker
    reload_on_schedule true

    def create(args = nil)
        # this method is called, when worker is loaded for the first time
    end

    def gather_aaa_logs
         local_manager = Manager.local
         TacacsDaemon.find(:all, :conditions => "manager_id is null").each do |td|
            td.gather_aaa_logs!
            if (td.errors.length > 0)
                errors = td.errors.full_messages.join(' ')
                local_manager.log(:level => 'warn', :tacacs_daemon_id => td.id,
                                  :message => "DaemonManager#gather_aaa_logs - #{td.name}: #{errors}")
            end
         end
    end

end

