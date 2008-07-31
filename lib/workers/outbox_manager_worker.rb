class OutboxManagerWorker < BackgrounDRb::MetaWorker
    set_worker_name :outbox_manager_worker

    def create(args = nil)
        # this method is called, when worker is loaded for the first time
    end

    def write_all_remote
        Manager.non_local.each do |manager|
            thread_pool.defer(manager) do |m|
                if (m.is_enabled && !m.outbox_locked?)
                    m.lock_outbox(1800) # 30 min lock
                    m.write_remote_inbox!
                    if (m.errors.length > 0)
                        m.errors.each_full {|e| Manager.local.log(:message => "#{m.name}#write_remote_inbox! - #{e}") }
                    end
                    m.unlock_outbox()
                end
            end
        end
    end

    def write_remote(manager_id)
        m = Manager.find(manager_id)
        if (m.is_enabled && !m.outbox_locked?)
            m.lock_outbox(1800) # 30 min lock
            m.write_remote_inbox!
            if (m.errors.length > 0)
                m.errors.each_full {|e| Manager.local.log(:message => "#{m.name}#write_remote_inbox! - #{e}") }
            end
            m.unlock_outbox()
        end
    end

end
