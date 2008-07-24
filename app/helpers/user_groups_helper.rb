module UserGroupsHelper
    def user_group_description(user_group)
        str = "<ul style=\"list-style-type: none;\">\n"
        str << "<li>user-group '#{user_group.name}'</li>\n"
        str << "<li>&nbsp&nbsp login access-list #{user_group.login_acl.name}</li>\n" if (user_group.login_acl_id)
        str << "<li>&nbsp&nbsp enable access-list #{user_group.enable_acl.name}</li>\n" if (user_group.enable_acl_id)
        str << "<li>&nbsp&nbsp author-avpair-list #{user_group.author_avpair.name}</li>\n" if (user_group.author_avpair_id)
        str << "<li>&nbsp&nbsp command-authorization-profile #{user_group.command_authorization_profile.name}</li>\n" if (user_group.command_authorization_profile_id)
        str << "</ul>\n"
        return(str)
    end
end
