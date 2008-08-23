class CommandAuthorizationWhitelistEntriesController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change

    def destroy
        respond_to do |format|
            if (@local_manager.slave?)
                @command_authorization_whitelist_entry.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render command_authorization_whitelist_configuration_url(@command_authorization_whitelist_entry.configuration) }
                format.xml  { render :xml => @command_authorization_whitelist_entry.errors, :status => :not_acceptable }
            elsif (@command_authorization_whitelist_entry.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :message => "Deleted entry #{@command_authorization_whitelist_entry.description} from Configuration #{@configuration.name}.")
                format.html { redirect_to command_authorization_whitelist_configuration_url(@command_authorization_whitelist_entry.configuration) }
                format.xml  { head :ok }
            else
                @nav = 'configurations/command_authorization_whitelist_nav'
                @configuration = @command_authorization_whitelist_entry.configuration
                format.html { render command_authorization_whitelist_configuration_url(@command_authorization_whitelist_entry.configuration) }
                format.xml  { head :ok }
            end
        end
    end

private

    def authorize
        @command_authorization_whitelist_entry = CommandAuthorizationWhitelistEntry.find(params[:id])
        @configuration = @command_authorization_whitelist_entry.configuration
        if (!@session_user.admin?)
            if ( !@configuration_roles.has_key?(@configuration.id) || @configuration_roles[@configuration.id] != 'admin' ) # deny if not owned by my config
                flash[:warning] = "Authorization failed. This attempt has been logged."
                @local_manager.log(:level => 'warn', :user_id => @session_user.id,
                                   :username => @session_user.username, :configuration_id => @configuration.id,
                                   :message => "Unauthorized access attempted to whitelist entry of configuration #{@configuration.name}.")
                respond_to do |format|
                    format.html {redirect_to command_authorization_whitelist_configuration_url(@configuration)}
                    format.xml {render :xml => "<errors><error>Authorization failed. This attempt has been logged.</error></errors>", :status => :forbidden}
                end
            end
        end
    end

end
