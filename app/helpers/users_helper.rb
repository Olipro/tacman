module UsersHelper

    def enable_status(user)
        cur = user.enable_password
        if (!cur)
            return('<i>not set</i>')
        elsif (user.enable_password_expired?)
            return('<i>expired</i>')
        elsif (user.enable_password_lifespan == 0)
            return('never expires')
        else
            return("expires on #{cur.expires_on}")
        end
    end

    def enable_expiry_checkboxes(user)
        if (!user.enable_password || user.enable_password_lifespan == 0)
            return( enable_status(user) )
        elsif (user.enable_password.expired?)
            str = image_tag('checked.png', :border => 'none') + "now &nbsp&nbsp&nbsp"
            str << link_to(image_tag('unchecked.png', :border => 'none'), toggle_enable_expiry_user_url(user), :method => :put ) + "#{@user.enable_password.expires_on + @user.enable_password_lifespan}"
        else
            extended = Date.today + user.enable_password_lifespan
            str = link_to(image_tag('unchecked.png', :border => 'none'), toggle_enable_expiry_user_url(user), :method => :put ) + "now &nbsp&nbsp&nbsp"
            str << image_tag('checked.png', :border => 'none') + "#{user.enable_password.expires_on} &nbsp&nbsp&nbsp"
            str << link_to(image_tag('unchecked.png', :border => 'none'), extend_enable_expiry_user_url(user), :method => :put ) + "#{extended}" if (user.enable_password.expires_on < extended)
        end
        return(str)
    end

    def user_aaa_log_import_checkbox(user)
        if (user.disable_aaa_log_import)
            link_to(image_tag('checked.png', :border => 'none'), toggle_disable_aaa_log_import_user_url(user), :method => :put )
        else
            link_to(image_tag('unchecked.png', :border => 'none'), toggle_disable_aaa_log_import_user_url(user), :method => :put )
        end
    end

    def password_expiry_checkboxes(user)
        if (!user.login_password || user.login_password_lifespan == 0)
            return( password_status(user) )
        elsif (user.login_password.expired?)
            str = image_tag('checked.png', :border => 'none') + "now &nbsp&nbsp&nbsp"
            str << link_to(image_tag('unchecked.png', :border => 'none'), toggle_password_expiry_user_url(user), :method => :put ) + "#{@user.login_password.expires_on + @user.login_password_lifespan}"
        else
            extended = Date.today + user.login_password_lifespan
            str = link_to(image_tag('unchecked.png', :border => 'none'), toggle_password_expiry_user_url(user), :method => :put ) + "now &nbsp&nbsp&nbsp"
            str << image_tag('checked.png', :border => 'none') + "#{user.login_password.expires_on} &nbsp&nbsp&nbsp"
            str << link_to(image_tag('unchecked.png', :border => 'none'), extend_password_expiry_user_url(user), :method => :put ) + "#{extended}" if (user.login_password.expires_on < extended)
        end
        return(str)
    end

    def password_status(user)
        cur = user.login_password
        if (!cur)
            return('<i>not set</i>')
        elsif (user.login_password_expired?)
            return('<i>expired</i>')
        elsif (user.login_password_lifespan == 0)
            return('never expires')
        else
            return("expires on #{cur.expires_on}")
        end
    end

    def user_active_checkbox(user)
        if (user.disabled?)
            link_to(image_tag('unchecked.png', :border => 'none'), toggle_disabled_user_url(user), :method => :put )
        else
            link_to(image_tag('checked.png', :border => 'none'), toggle_disabled_user_url(user), :method => :put )
        end
    end

    def user_role_checkboxes(user)
        str = ""
        if (user.admin?)
            str << link_to(image_tag('checked.png', :border => 'none'), set_role_admin_user_url(user), :confirm => "Confirm", :method => :put)
        else
            str << link_to(image_tag('unchecked.png', :border => 'none'), set_role_admin_user_url(user), :confirm => "Confirm", :method => :put)
        end

        str << 'admin &nbsp &nbsp'

        if (user.user_admin?)
            str << link_to(image_tag('checked.png', :border => 'none'), set_role_user_admin_user_url(user), :confirm => "Confirm", :method => :put)
        else
            str << link_to(image_tag('unchecked.png', :border => 'none'), set_role_user_admin_user_url(user), :confirm => "Confirm", :method => :put)
        end

        str << 'user_admin &nbsp &nbsp'

        if (user.user?)
            str << link_to(image_tag('checked.png', :border => 'none'), set_role_user_user_url(user), :confirm => "Confirm", :method => :put)
        else
            str << link_to(image_tag('unchecked.png', :border => 'none'), set_role_user_user_url(user), :confirm => "Confirm", :method => :put)
        end

        str << 'user'

        return(str)
    end

    def user_role_highlight(user)
        if (user.admin?)
            return("<b><i style=\"color: #7B2024\">#{user.role}</i></b>")
        elsif (user.user_admin?)
            return("<i style=\"color: #7B2024\">#{user.role}</i>")
        else
            return("<i>#{user.role}</i>")
        end
    end

    def user_web_login_checkbox(user)
        if (user.allow_web_login)
            link_to(image_tag('checked.png', :border => 'none'), toggle_allow_web_login_user_url(user), :method => :put )
        else
            link_to(image_tag('unchecked.png', :border => 'none'), toggle_allow_web_login_user_url(user), :method => :put )
        end
    end

end
