class ShellCommandObjectGroupEntriesController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change


    def destroy
        respond_to do |format|
            @nav = 'shell_command_object_groups/show_nav'
            if (@local_manager.slave?)
                @shell_command_object_group_entry.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render shell_command_object_group_url(@shell_command_object_group) }
                format.xml  { render :xml => @shell_command_object_group_entry.errors, :status => :not_acceptable }
            elsif (@shell_command_object_group_entry.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @shell_command_object_group.configuration_id, :shell_command_object_group_id => @shell_command_object_group.id, :message => "Deleted entry #{@shell_command_object_group_entry.sequence} /#{@shell_command_object_group_entry.command}/ of Shell Command Object Group #{@shell_command_object_group.name} within configuration #{@configuration.name}.")
                format.html { redirect_to shell_command_object_group_url(@shell_command_object_group) }
                format.xml  { head :ok }
            else
                format.html { render shell_command_object_group_url(@shell_command_object_group) }
                format.xml  { head :ok }
            end
        end
    end

    def edit
        respond_to do |format|
            format.html {@nav = 'shell_command_object_groups/show_nav'}
        end
    end

    def update
        respond_to do |format|
            @nav = 'shell_command_object_groups/show_nav'
            if (@local_manager.slave?)
                @shell_command_object_group.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "edit" }
                format.xml  { render :xml => @shell_command_object_group.errors, :status => :not_acceptable }
            elsif @shell_command_object_group_entry.update_attributes(params[:shell_command_object_group_entry])
                @local_manager.log(:username => @session_user.username, :configuration_id => @shell_command_object_group.configuration_id, :shell_command_object_group_id => @shell_command_object_group.id, :message => "Edited entry #{@shell_command_object_group_entry.sequence} of Shell Command Object Group #{@shell_command_object_group.name} within configuration #{@configuration.name}.")
                format.html { redirect_to shell_command_object_group_url(@shell_command_object_group) }
                format.xml  { head :ok }
            else
                format.html { render :action => "edit" }
                format.xml  { render :xml => @shell_command_object_group.errors, :status => :unprocessable_entity }
            end
        end
    end

private

    def authorize
        @shell_command_object_group_entry = ShellCommandObjectGroupEntry.find(params[:id])
        @shell_command_object_group = @shell_command_object_group_entry.shell_command_object_group
        @configuration = @shell_command_object_group.configuration
        if (!@session_user.admin?)
            if ( !@configuration_roles.has_key?(@shell_command_object_group.configuration_id) || @configuration_roles[@shell_command_object_group.configuration_id] != 'admin' ) # deny if not owned by my config
                flash[:warning] = "Authorization failed. This attempt has been logged."
                @local_manager.log(:level => 'warn', :user_id => @session_user.id,
                                   :username => @session_user.username, :shell_command_object_group_id => @shell_command_object_group.id,
                                   :message => "Unauthorized access attempted to shell-command-object-group #{@shell_command_object_group.name}.")
                respond_to do |format|
                    format.html {redirect_to home_users_url}
                    format.xml {render :xml => "<errors><error>Authorization failed. This attempt has been logged.</error></errors>", :status => :forbidden}
                end
            end
        end
    end
end
