class ConfiguredUsersController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change

    def activate
        @user = @configured_user.user
        @configuration = @configured_user.configuration

        respond_to do |format|
            @nav = "configurations/show_nav"
            if (@local_manager.slave?)
                @configured_user.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render configuration_url(@configured_user.configuration)  }
                format.xml  { render :xml => @configured_user.errors, :status => :not_acceptable }
            else
                @configured_user.activate!
                @local_manager.log(:username => @session_user.username, :configured_user_id => @configured_user.id, :configuration_id => @configuration.id, :message => "Activated user #{@user.username} within configuration #{@configuration.name}.")
                flash[:notice] = "User has been activated."
                format.html { redirect_to configuration_url(@configuration)}
                format.xml  { head :ok }
            end
        end
    end


    def destroy
        @user = @configured_user.user
        @configuration = @configured_user.configuration

        respond_to do |format|
            @nav = "configurations/show_nav"
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to( request.env["HTTP_REFERER"] ) }
                format.xml  { render :xml => @@configured_user.errors, :status => :not_acceptable }
            else
                @configured_user.destroy
                @local_manager.log(:username => @session_user.username, :user_id => @user.id, :configured_user_id => @configured_user.id, :configuration_id => @configuration.id, :message => "Removed user #{@user.username} from configuration #{@configuration.name}.")
                format.html { redirect_to( request.env["HTTP_REFERER"] ) }
                format.xml  { head :ok }
            end
        end
    end


    def edit
        @configuration = @configured_user.configuration
        respond_to do |format|
            format.html {@nav = "configurations/show_nav"}
        end
    end


    def suspend
        @user = @configured_user.user
        @configuration = @configured_user.configuration

        respond_to do |format|
            @nav = "configurations/show_nav"
            if (@local_manager.slave?)
                @configured_user.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render configuration_url(@configured_user.configuration) }
                format.xml  { render :xml => @@configured_user.errors, :status => :not_acceptable }
            else
                @configured_user.suspend!
                @local_manager.log(:username => @session_user.username, :configured_user_id => @configured_user.id, :configuration_id => @configuration.id, :message => "Suspended user #{@user.username} within configuration #{@configuration.name}.")
                flash[:notice] = "User has been suspended."
                format.html { redirect_to configuration_url(@configuration)}
                format.xml  { head :ok }
            end
        end
    end


    def update
        @user = @configured_user.user
        @configuration = @configured_user.configuration

        respond_to do |format|
            @nav = "configurations/show_nav"
            if (@local_manager.slave?)
                @configured_user.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "edit" }
                format.xml  { render :xml => @configured_user.errors, :status => :not_acceptable }
            elsif @configured_user.update_attributes(params[:configured_user])
                @local_manager.log(:username => @session_user.username, :configured_user_id => @configured_user.id, :configuration_id => @configuration.id, :message => "Updated settings for user #{@user.username} within configuration #{@configuration.name}.")
                format.html { redirect_to( configuration_url(@configuration) ) }
                format.xml  { head :ok }
            else
                format.html { render :action => "edit" }
                format.xml  { render :xml => @configured_user.errors, :status => :unprocessable_entity }
            end
        end
    end

private

    def authorize
        @configured_user = ConfiguredUser.find(params[:id])
        if (!@session_user.admin?)
            if ( !@configuration_roles.has_key?(@configured_user.configuration_id) || @configuration_roles[@configured_user.configuration_id] != 'admin' ) # deny if not owned by my config
                flash[:warning] = "Authorization failed. This attempt has been logged."
                @local_manager.log(:level => 'warn', :user_id => @session_user.id,
                                   :username => @session_user.username, :configuration_id => @configured_user.configuration_id,
                                   :message => "Unauthorized access attempted to user of configuration #{@configured_user.configuration.name}.")
                respond_to do |format|
                    format.html {redirect_to home_users_url}
                    format.xml {render :xml => "<errors><error>Authorization failed. This attempt has been logged.</error></errors>", :status => :forbidden}
                end
            end
        end
    end

end

