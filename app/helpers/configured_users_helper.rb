module ConfiguredUsersHelper
    def configured_user_description(configured_user)
        str = "<ul style=\"list-style-type: none;\">\n"
        str << "<li>user '#{configured_user.user.username}'</li>\n"
        str << "<li>role '#{configured_user.role}'</li>\n"
        str << "<li>&nbsp&nbsp user-group '#{configured_user.user_group.name}'</li>\n" if (configured_user.user_group_id)
        str << "<li>&nbsp&nbsp login access-list '#{configured_user.login_acl.name}'</li>\n" if (configured_user.login_acl_id)
        str << "<li>&nbsp&nbsp enable access-list '#{configured_user.enable_acl.name}'</li>\n" if (configured_user.enable_acl_id)
        str << "<li>&nbsp&nbsp author-avpair-list '#{configured_user.author_avpair.name}'</li>\n" if (configured_user.author_avpair_id)
        str << "<li>&nbsp&nbsp command-authorization-profile '#{configured_user.command_authorization_profile.name}'</li>\n" if (configured_user.command_authorization_profile_id)
        str << "</ul>\n"
        return(str)
    end
end
