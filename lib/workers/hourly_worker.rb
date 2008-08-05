class HourlyWorker < BackgrounDRb::MetaWorker
    set_worker_name :hourly_worker
    reload_on_schedule true

    def create(args = nil)
        # this method is called, when worker is loaded for the first time
    end

    def hourly_tasks
        @local_manager = Manager.local
        cleanup_sessions
        gather_aaa_logs
        write_all_remote
        process_all_inbox
    end

private

    def cleanup_sessions
        # delete inactive sessions older than an hour
        time = (Time.now - 3600).strftime("%Y-%m-%d %H:%M:%S %Z")
        CGI::Session::ActiveRecordStore::Session.delete_all("updated_at < '#{time}'")
    end

    def do_write(m)
        count = m.system_messages.count(:conditions => "queue = 'outbox'")
        if (count > 0 && m.is_enabled && !m.outbox_locked?)
            m.lock_outbox(1800) # 30 min lock
            m.write_remote_inbox!
            m.unlock_outbox()
        end

        return(true)
    end

    def gather_aaa_logs
         TacacsDaemon.find(:all, :conditions => "manager_id is null").each do |td|
            td.gather_aaa_logs!
            if (td.errors.length > 0)
                errors = td.errors.full_messages.join(' ')
                @local_manager.log(:level => 'warn', :tacacs_daemon_id => td.id,
                                   :message => "DaemonManager#gather_aaa_logs - #{td.name}: #{errors}")
            end
         end
    end

    def process_all_inbox()
        Manager.find(:all).each do |m|
            if (!m.inbox_locked?)
                m.lock_inbox(1800) # 30 min lock
                m.process_inbox!
                m.unlock_inbox()
            end
        end
    end

    def write_all_remote
        Manager.non_local.each do |manager|
            thread_pool.defer(:do_write, manager)
        end

        return(true)
    end

end

