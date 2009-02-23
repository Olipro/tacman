module ManagersHelper

    def maintenance_checkboxes
        if (!@local_manager.in_maintenance_mode)
            str = link_to(image_tag("radio_off.png", :border => 'none'), toggle_maintenance_mode_managers_url, :method => :post, :confirm => "Enable maintenance mode?") + " on &nbsp&nbsp"
            str << image_tag("radio_on.png", :border => 'none') + " off"
        else
            str = image_tag("radio_on.png", :border => 'none') + " on&nbsp&nbsp"
            str << link_to(image_tag("radio_off.png", :border => 'none'), toggle_maintenance_mode_managers_url, :method => :post, :confirm => "Disable maintenance mode?") + " off"
        end
    end

    def role_checkboxes
        if (@manager.stand_alone?)
            str = link_to(image_tag("radio_off.png", :border => 'none'), {:action => 'master'}, :confirm => "Confirm Manager Type Change", :method => :post)
            str << " master &nbsp&nbsp"
            str << link_to(image_tag("radio_off.png", :border => 'none'), {:action => 'slave'}, :confirm => "Confirm Manager Type Change", :method => :post)
            str << " slave &nbsp&nbsp&nbsp"
            str << image_tag("radio_on.png", :border => 'none')
            str << " stand alone"

        elsif (@manager.master?)
            str = image_tag("radio_on.png", :border => 'none')
            str << " master &nbsp&nbsp"
            str << link_to(image_tag("radio_off.png", :border => 'none'), {:action => 'slave'}, :confirm => "Confirm Manager Type Change", :method => :post)
            str << " slave &nbsp&nbsp&nbsp"
            str << link_to(image_tag("radio_off.png", :border => 'none'), {:action => 'stand_alone'}, :confirm => "Confirm Manager Type Change", :method => :post)
            str << " stand alone"
        elsif (@manager.slave?)
            str = link_to(image_tag("radio_off.png", :border => 'none'), {:action => 'master'}, :confirm => "Confirm Manager Type Change", :method => :post)
            str << " master &nbsp&nbsp"
            str << image_tag("radio_on.png", :border => 'none')
            str << " slave &nbsp&nbsp&nbsp"
            str << link_to(image_tag("radio_off.png", :border => 'none'), {:action => 'stand_alone'}, :confirm => "Confirm Manager Type Change", :method => :post)
            str << " stand alone"
        end
    end

    def role_display
        if (@manager.stand_alone?)
            return ("Stand Alone")
        elsif (@manager.master?)
            return("Master")
        elsif (@manager.slave?)
            return("Slave")
        end
    end

end
