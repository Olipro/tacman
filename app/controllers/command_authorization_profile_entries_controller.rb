class CommandAuthorizationProfileEntriesController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change

    def destroy
        respond_to do |format|
            @nav = 'command_authorization_profiles/show_nav'
            if (@local_manager.slave?)
                @command_authorization_profile_entry.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render command_authorization_profile_url(@command_authorization_profile)  }
                format.xml  { render :xml => @command_authorization_profile_entry.errors, :status => :not_acceptable }
            elsif (@command_authorization_profile_entry.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @command_authorization_profile.configuration_id, :command_authorization_profile_id => @command_authorization_profile.id, :message => "Deleted entry '#{@command_authorization_profile_entry.description}' of Command Authorization Profile '#{@command_authorization_profile.name}'.")
                format.html { redirect_to command_authorization_profile_url(@command_authorization_profile) }
                format.xml  { head :ok }
            else
                format.html { render command_authorization_profiles_configuration_url(@command_authorization_profile.configuration) }
                format.xml  { head :ok }
            end
        end
    end

private

    def authorize
        @command_authorization_profile_entry = CommandAuthorizationProfileEntry.find(params[:id])
        @command_authorization_profile = @command_authorization_profile_entry.command_authorization_profile
        if (!@session_user.admin?)
            if ( !@configuration_roles.has_key?(@command_authorization_profile.configuration_id) || @configuration_roles[@command_authorization_profile.configuration_id] != 'admin' ) # deny if not owned by my config
                flash[:warning] = "Authorization failed. This attempt has been logged."
                @local_manager.log(:level => 'warn', :user_id => @session_user.id,
                                   :username => @session_user.username, :command_authorization_profile_id => @command_authorization_profile.id,
                                   :message => "Unauthorized access attempted to command-authorization-profile #{@command_authorization_profile.name}.")
                respond_to do |format|
                    format.html {redirect_to home_users_url}
                    format.xml {render :xml => "<errors><error>Authorization failed. This attempt has been logged.</error></errors>", :status => :forbidden}
                end
            end
        end
    end
end
