module ConfigurationsHelper
    def acl_opts(configuration)
        ['',''].concat( configuration.acls.find(:all).collect {|x| [x.name, x.id]} )
    end

    def command_authorization_whitelist_description(configuration, include_delete=false)
        entries = configuration.command_authorization_whitelist_entries
        return("<ul style=\"list-style-type: none;\"><li>command-authorization-whitelist </li><li><i> &nbsp&nbsp empty set</i></li></ul>") if (entries.length == 0)

        str = "<ul style=\"list-style-type: none;\">\n"
        str << "<li>command-authorization-whitelist </li>\n"
        entries.each do |e|
            str << "<li> &nbsp&nbsp "
            str << link_to(image_tag('delete_button.png', :border => 'none'), command_authorization_whitelist_entry_url(e), :method => :delete) if (include_delete)
            str << " seq #{e.sequence} "
            if (e.shell_command_object_group_id)
                str << "shell-command-object-group #{e.shell_command_object_group.name} "
            else
                str << "command /#{e.command}/"
            end
            str << " access-list #{e.acl.name}" if (e.acl_id)
            str << "</li>\n"
        end
        str << "</ul>\n"
        return(str)
    end

    def configured_user_role_highlight(cu)
        if (cu.admin?)
            return("<i style=\"color: #7B2024\">#{cu.role}</i>")
        else
            return("<i>#{cu.role}</i>")
        end
    end

    def configured_user_settings_description(cu)
        str = ""
        str << "<b>Authorization AVPair:</b> &nbsp&nbsp #{cu.author_avpair.name}<br />" if (cu.author_avpair_id)
        str << "<b>Command Authorization Profile:</b> &nbsp&nbsp #{cu.command_authorization_profile.name}<br />" if (cu.command_authorization_profile_id)
        str << "<b>Login ACL:</b> &nbsp&nbsp #{cu.login_acl.name}<br />" if (cu.login_acl_id)
        str << "<b>Enable ACL:</b> &nbsp&nbsp #{cu.enable_acl.name}" if (cu.enable_acl_id)
        return(str)
    end
end
