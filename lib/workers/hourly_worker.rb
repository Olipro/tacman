class HourlyWorker < BackgrounDRb::MetaWorker
    set_worker_name :hourly_worker
    reload_on_schedule true

    def create(args = nil)
        # this method is called, when worker is loaded for the first time
    end

    def hourly_tasks
        @local_manager = Manager.local
        cleanup_sessions
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
            begin
                m.unlock_outbox() if (m.write_remote_inbox!)
            rescue Exception => error
                m.unlock_outbox()
                @local_manager.log(:level => 'error', :message => "Error with HourlyWorker#do_write for #{m.name}: #{error}")
            end
        end

        return(true)
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

