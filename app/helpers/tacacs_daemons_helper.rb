module TacacsDaemonsHelper

    def migration_checkboxes(td)
            str = '<ul style="list-style:none;">'
        Manager.find(:all, :order => :name).each do |m|
            str << "<li>"
            if ( (td.manager_id && td.manager_id != m.id) || (!td.manager_id && !m.is_local) )
                str << link_to(image_tag("unchecked.png", :border => 'none'), {:action => 'do_migrate', :id => td.id, :manager_id => m.id}, :confirm => "Migrate?", :method => :post)
            else
                str << image_tag("checked.png", :border => 'none')
            end
            str << m.name + "</li>"
        end
        str << "</ol>"
    end

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
