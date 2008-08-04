class QueueWorker < BackgrounDRb::MetaWorker
    set_worker_name :queue_worker
    set_no_auto_load true


    def create(args = nil)
        # this method is called, when worker is loaded for the first time
    end

    def process_inbox(manager_id)
        m = Manager.find(manager_id)
        count = m.system_messages.count(:conditions => "queue = 'inbox'")
        if (count > 0 && !m.inbox_locked?)
            m.lock_inbox(1800) # 30 min lock
            m.process_inbox!
            m.unlock_inbox()
        end

        return(true)
    end

    def restart_tacacs_daemons(configuration_id)
        @configuration = Configuration.find(configuration_id)
        delay = @configuration.publish_lock.expires_at - Time.now
        add_timer(delay) {restart_tacacs_daemons} if (delay > 0)
    end

    def write_all_remote
        @local_manager = Manager.local
        Manager.non_local.each do |manager|
            thread_pool.defer(:do_write, manager)
        end

        return(true)
    end

    def write_remote(manager_id)
        m = Manager.find(manager_id)
        do_write(m)
        return(true)
    end

private

    def do_write(m)
        count = m.system_messages.count(:conditions => "queue = 'outbox'")
        if (count > 0 && m.is_enabled && !m.outbox_locked?)
            m.lock_outbox(1800) # 30 min lock
            add_timer(30) {m.write_remote_inbox!} # wait a bit before actually writing as to catch as many messages as possible
            m.unlock_outbox()
        end

        return(true)
    end

    def restart_tacacs_daemons
        @configuration.tacacs_daemons.find(:all, :conditions => 'manager_id = null').each {|td| td.restart}
    end

end

