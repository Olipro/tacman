module NetworkObjectGroupsHelper

    def nog_description(network_object_group, show_details=false)
        entries = network_object_group.network_object_group_entries
        return("<ul style=\"list-style-type: none;\"><li>network-object-group <i>#{network_object_group.name}</i></li><li><i> &nbsp&nbsp empty set</i></li></ul>") if (entries.length == 0)

        str = "<ul style=\"list-style-type: none;\">\n"
        str << "<li>network-object-group <i>#{network_object_group.name}</i></li>\n"
        entries.each do |e|
            str << "<li> &nbsp&nbsp "
            str << link_to(image_tag('delete_button.png', :border => 'none'), network_object_group_entry_url(e), :method => :delete) if (show_details)
            str << " seq #{e.sequence}"if (show_details)
            str << " #{e.cidr} </li>\n"
        end
        str << "</ul>\n"
        return(str)
    end

end
