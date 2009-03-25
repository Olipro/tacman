module AclsHelper
    def acl_description(acl, show_details=false)
        entries = acl.acl_entries
        return("<ul style=\"list-style-type: none;\"><li>access-list <i>#{acl.name}</i></li><li><i> &nbsp&nbsp empty set</i></li></ul>") if (entries.length == 0)

        str = "<ul style=\"list-style-type: none;\">\n"
        str << "<li>access-list <i>#{acl.name}</i></li>\n"
        entries.each do |e|
            str << "<li> &nbsp&nbsp "
            str << link_to(image_tag('delete_button.png', :border => 'none'), acl_entry_url(e), :method => :delete) if (show_details)
            str << " seq #{e.sequence}"if (show_details)
            str << " #{e.permission} "
            if (e.network_object_group_id)
                str << "network-object-group <i>#{link_to e.network_object_group.name, network_object_groups_configuration_url(@configuration) }</i> "
            else
                str << "ip #{e.ip} #{e.wildcard_mask}"
            end
            str << "&nbsp &nbsp &nbsp \"<i>#{e.comment}</i>\"" if (!e.comment.blank?)
            str << "</li>\n"
        end
        str << "</ul>\n"
        return(str)
    end
end
