module TacacsDaemonsHelper

    def status(tacacs_daemon)
        if (tacacs_daemon.running?)
            return('running')
        else
            return('stopped')
        end
    end

    def status_icon(tacacs_daemon)
        if (tacacs_daemon.status == 'running')
            image_tag("status_running.png", :border => 0)
        elsif (tacacs_daemon.status == 'stopped')
            image_tag("status_stopped.png", :border => 0)
        elsif (tacacs_daemon.status == 'error')
            image_tag("status_error.png", :border => 0)
        else
            image_tag("status_unknown.png", :border => 0)
        end
    end

end
