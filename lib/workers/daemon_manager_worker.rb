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
                                   :message => "DaemonManager#check_status - failed to auto-start downed TacacsDaemon #{td.name}.")
                TacacsDaemon.update_all("desire_start = false", "id = #{td.id}")
                td.errors.clear
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

