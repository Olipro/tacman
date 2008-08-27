class NetworkObjectGroupEntriesController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change


    def destroy
        respond_to do |format|
            @nav = 'network_object_groups/show_nav'
            if (@local_manager.slave?)
                @network_object_group_entry.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render network_object_group_url(@network_object_group) }
                format.xml  { render :xml => @network_object_group_entry.errors, :status => :not_acceptable }
            elsif (@network_object_group_entry.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @network_object_group.configuration_id, :network_object_group_id => @network_object_group.id, :message => "Deleted entry #{@network_object_group_entry.sequence} (#{@network_object_group_entry.cidr}) of Network Object Group #{@network_object_group.name} within configuration #{@configuration.name}.")
                format.html { redirect_to network_object_group_url(@network_object_group) }
                format.xml  { head :ok }
            else
                format.html { render network_object_groups_configuration_url(@network_object_group.configuration) }
                format.xml  { head :ok }
            end
        end
    end

private

    def authorize
        @network_object_group_entry = NetworkObjectGroupEntry.find(params[:id])
        @network_object_group = @network_object_group_entry.network_object_group
        @configuration = @network_object_group.configuration
        if (!@session_user.admin?)
            if ( !@configuration_roles.has_key?(@network_object_group.configuration_id) || @configuration_roles[@network_object_group.configuration_id] != 'admin' ) # deny if not owned by my config
                flash[:warning] = "Authorization failed. This attempt has been logged."
                @local_manager.log(:level => 'warn', :user_id => @session_user.id,
                                   :username => @session_user.username, :network_object_group_id => @network_object_group.id,
                                   :message => "Unauthorized access attempted to network-object-group #{@network_object_group.name}.")
                respond_to do |format|
                    format.html {redirect_to home_users_url}
                    format.xml {render :xml => "<errors><error>Authorization failed. This attempt has been logged.</error></errors>", :status => :forbidden}
                end
            end
        end
    end
end
