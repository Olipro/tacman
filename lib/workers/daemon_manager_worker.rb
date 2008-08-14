class DaemonManagerWorker < BackgrounDRb::MetaWorker
    set_worker_name :daemon_manager_worker
    reload_on_schedule true

    def create(args = nil)
        @tacacs_daemons = TacacsDaemon.find(:all, :conditions => "manager_id is null")
        @local_manager = Manager.local
    end

    def do_tasks
        check_status
        gather_aaa_logs
    end

private
    def check_status
        @tacacs_daemons.each do |td|
            if (td.desire_start && !td.running? && !td.start)
                @local_manager.log(:level => 'error', :tacacs_daemon_id => td.id,
                                   :message => "DaemonManager#check_status - #{td.name} failed to start: #{errors}")
                td.update_attribute(:desire_start, false)
            end
        end
    end

    def gather_aaa_logs
         @tacacs_daemons.each do |td|
            td.gather_aaa_logs!
            if (td.errors.length > 0)
                errors = td.errors.full_messages.join(' ')
                @local_manager.log(:level => 'warn', :tacacs_daemon_id => td.id,
                                   :message => "DaemonManager#gather_aaa_logs - #{td.name}: #{errors}")
            end
         end
    end

end

