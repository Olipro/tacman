module CommandAuthorizationProfilesHelper
    def command_authorization_profile_description(command_authorization_profile, show_details=false)
        entries = command_authorization_profile.command_authorization_profile_entries
        return("<ul style=\"list-style-type: none;\"><li>command-authorization-profile <i>#{command_authorization_profile.name}</i></li><li><i> &nbsp&nbsp empty set</i></li></ul>") if (entries.length == 0)

        str = "<ul style=\"list-style-type: none;\">\n"
        str << "<li>command-authorization-profile <i>#{command_authorization_profile.name}</i></li>\n"
        entries.each do |e|
            str << "<li> &nbsp&nbsp "
            str << link_to(image_tag('delete_button.png', :border => 'none'), command_authorization_profile_entry_url(e), :method => :delete) if (show_details)
            str << " seq #{e.sequence} "if (show_details)
            if (e.shell_command_object_group_id)
                str << "shell-command-object-group <i>#{e.shell_command_object_group.name}</i> "
            else
                str << "command /#{e.command}/"
            end
            str << " access-list <i>#{e.acl.name}</i>" if (e.acl_id)
            str << "</li>\n"
        end
        str << "</ul>\n"
        return(str)
    end
end
