module ShellCommandObjectGroupsHelper
    def scog_description(shell_command_object_group, show_details=false)
        entries = shell_command_object_group.shell_command_object_group_entries
        return("<ul style=\"list-style-type: none;\"><li>shell-command-object-group #{shell_command_object_group.name}</li><li><i> &nbsp&nbsp empty set</i></li></ul>") if (entries.length == 0)

        str = "<ul style=\"list-style-type: none;\">\n"
        str << "<li>shell-command-object-group #{shell_command_object_group.name}</li>\n"
        entries.each do |e|
            str << "<li> &nbsp&nbsp "
            str << link_to(image_tag('delete_button.png', :border => 'none'), shell_command_object_group_entry_url(e), :method => :delete) if (show_details)
            str << " seq #{e.sequence}"if (show_details)
            str << " /#{e.command}/ </li>\n"
        end
        str << "</ul>\n"
        return(str)
    end
end
