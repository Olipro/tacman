class PublisherWorker < BackgrounDRb::MetaWorker
    set_worker_name :publisher_worker

    def create(args = nil)
        # this method is called, when worker is loaded for the first time
    end

    def restart_tacacs_daemons(configuration_id)
        c = Configuration.find(configuration_id)
        delay = c.publish_lock.expires_at - Time.now
        sleep(delay) if (delay > 0)
        c.tacacs_daemons.each {|td| td.restart if (td.local?) }
    end

end

