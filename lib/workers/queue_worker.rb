class QueueWorker < BackgrounDRb::MetaWorker
    set_worker_name :queue_worker
    set_no_auto_load true


    def create(args = nil)
        # this method is called, when worker is loaded for the first time
    end

    def process_inbox(manager_id)
        begin
            m = Manager.find(manager_id)
            count = m.system_messages.count(:conditions => "queue = 'inbox'")
            if (count > 0 && !m.inbox_locked?)
                m.lock_inbox(900) # 15 min lock
                m.process_inbox!
                m.unlock_inbox()
            end
        rescue
        end

        exit
    end

    def publish_configuration(configuration_id)
        begin
            configuration = Configuration.find(configuration_id)
            delay = configuration.publish_lock.expires_at - Time.now
            if (delay > 0)
                add_timer(delay) do
                    begin
                        reload_tacacs_daemon(configuration)
                    rescue
                    end
                    exit
                end
            else
                reload_tacacs_daemon(configuration)
                exit
            end
        rescue
            exit
        end
    end

    def write_remote(manager_id)
        m = Manager.find(manager_id)
        count = m.system_messages.count(:conditions => "queue = 'outbox'")
        if (count > 0 && m.is_enabled && !m.outbox_locked?)
            m.lock_outbox(900) # 15 min lock
            add_timer(30) do
                begin
                    m.write_remote_inbox!
                    m.unlock_outbox()
                rescue
                    m.unlock_outbox()
                end
                exit
            end
        else
            exit
        end
    end

private

    def reload_tacacs_daemon(configuration)
        configuration.tacacs_daemons.find(:all, :conditions => 'manager_id is null').each do |td|
            td.write_config_file
            td.reload_server
        end
    end

end

