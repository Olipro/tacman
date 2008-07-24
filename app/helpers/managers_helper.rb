module ManagersHelper

    def role_checkboxes
        if (@manager.stand_alone?)
            str = link_to(image_tag("unchecked.png", :border => 'none'), {:action => 'master'}, :confirm => "Confirm Manager Type Change", :method => :post)
            str << "master &nbsp&nbsp"
            str << link_to(image_tag("unchecked.png", :border => 'none'), {:action => 'slave'}, :confirm => "Confirm Manager Type Change", :method => :post)
            str << "slave &nbsp&nbsp&nbsp"
            str << image_tag("checked.png", :border => 'none')
            str << "stand alone"

        elsif (@manager.master?)
            str = image_tag("checked.png", :border => 'none')
            str << "master &nbsp&nbsp"
            str << link_to(image_tag("unchecked.png", :border => 'none'), {:action => 'slave'}, :confirm => "Confirm Manager Type Change", :method => :post)
            str << "slave &nbsp&nbsp&nbsp"
            str << link_to(image_tag("unchecked.png", :border => 'none'), {:action => 'stand_alone'}, :confirm => "Confirm Manager Type Change", :method => :post)
            str << "stand alone"
        elsif (@manager.slave?)
            str = link_to(image_tag("unchecked.png", :border => 'none'), {:action => 'master'}, :confirm => "Confirm Manager Type Change", :method => :post)
            str << "master &nbsp&nbsp"
            str << image_tag("checked.png", :border => 'none')
            str << "slave &nbsp&nbsp&nbsp"
            str << link_to(image_tag("unchecked.png", :border => 'none'), {:action => 'stand_alone'}, :confirm => "Confirm Manager Type Change", :method => :post)
            str << "stand alone"
        end
    end

end
