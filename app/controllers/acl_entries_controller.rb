class AclEntriesController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change

    def destroy
        respond_to do |format|
            @nav = 'acls/show_nav'
            if (@local_manager.slave?)
                @acl_entry.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render acl_url(@acl) }
                format.xml  { render :xml => @acl_entry.errors, :status => :not_acceptable }
            elsif (@acl_entry.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @acl.configuration_id, :acl_id => @acl.id, :message => "Deleted entry #{@acl_entry.sequence} (#{@acl_entry.description}) of ACL #{@acl.name} within configuration #{@configuration.name}.")
                format.html { redirect_to acl_url(@acl) }
                format.xml  { head :ok }
            else
                format.html { render acls_configuration_url(@acl) }
                format.xml  { head :ok }
            end
        end
    end

private

    def authorize
        @acl_entry = AclEntry.find(params[:id])
        @acl = @acl_entry.acl
        @configuration = @acl.configuration
        if (!@session_user.admin?)
            if ( !@configuration_roles.has_key?(@acl.configuration_id) || @configuration_roles[@acl.configuration_id] != 'admin' ) # deny if not owned by my config
                flash[:warning] = "Authorization failed. This attempt has been logged."
                @local_manager.log(:level => 'warn', :user_id => @session_user.id,
                                   :username => @session_user.username, :acl_id => @acl.id,
                                   :message => "Unauthorized access attempted to access-list #{@acl.name}.")
                respond_to do |format|
                    format.html {redirect_to home_users_url}
                    format.xml {render :xml => "<errors><error>Authorization failed. This attempt has been logged.</error></errors>", :status => :forbidden}
                end
            end
        end
    end
end
