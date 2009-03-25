module UserGroupsHelper
    def user_group_description(user_group)
        str = "<ul style=\"list-style-type: none;\">\n"
        str << "<li>user-group <i>#{user_group.name}</i></li>\n"
        str << "<li>&nbsp&nbsp login access-list <i>#{link_to user_group.login_acl.name, acls_configuration_url(@configuration) }</i></li>\n" if (user_group.login_acl_id)
        str << "<li>&nbsp&nbsp enable access-list <i>#{link_to user_group.enable_acl.name, acls_configuration_url(@configuration) }</i></li>\n" if (user_group.enable_acl_id)
        str << "<li>&nbsp&nbsp author-avpair-list <i>#{link_to user_group.author_avpair.name, author_avpairs_configuration_url(@configuration) }</i></li>\n" if (user_group.author_avpair_id)
        str << "<li>&nbsp&nbsp command-authorization-profile <i>#{link_to user_group.command_authorization_profile.name, command_authorization_profiles_configuration_url(@configuration) }</i></li>\n" if (user_group.command_authorization_profile_id)
        str << "</ul>\n"
        return(str)
    end
end
