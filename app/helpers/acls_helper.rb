module AclsHelper
    def acl_description(acl, show_details=false)
        entries = acl.acl_entries
        return("<ul style=\"list-style-type: none;\"><li>access-list #{acl.name}</li><li><i> &nbsp&nbsp empty set</i></li></ul>") if (entries.length == 0)

        str = "<ul style=\"list-style-type: none;\">\n"
        str << "<li>access-list #{acl.name}</li>\n"
        entries.each do |e|
            str << "<li> &nbsp&nbsp "
            str << link_to(image_tag('delete_button.png', :border => 'none'), acl_entry_url(e), :method => :delete) if (show_details)
            str << " seq #{e.sequence}"if (show_details)
            str << " #{e.permission} "
            if (e.network_object_group_id)
                str << "network-object-group #{e.network_object_group.name} "
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
