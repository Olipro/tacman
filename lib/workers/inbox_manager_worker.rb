class InboxManagerWorker < BackgrounDRb::MetaWorker
    set_worker_name :inbox_manager_worker

    def create(args = nil)
        # this method is called, when worker is loaded for the first time
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

    def process_inbox(manager_id)
        m = Manager.find(manager_id)
        if (!m.inbox_locked?)
            m.lock_inbox(1800) # 30 min lock
            m.process_inbox!
            m.unlock_inbox()
        end
    end

end

