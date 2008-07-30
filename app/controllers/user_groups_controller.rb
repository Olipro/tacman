class UserGroupsController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change

    def changelog
        @configuration = @user_group.configuration
        @log_count = SystemLog.count_by_sql("SELECT COUNT(*) FROM system_logs WHERE user_group_id=#{@user_group.id}")
        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = SystemLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                   :conditions => "user_group_id=#{@user_group.id}", :order => :created_at)
        respond_to do |format|
            @nav = 'configurations/user_group_nav'
            format.html {render :template => 'managers/system_logs'}
        end
    end

    def destroy
        @configuration = @user_group.configuration

        respond_to do |format|
            @nav = '/configurations/user_group_nav'
            if (@local_manager.slave?)
                @user_group.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "user_groups" }
                format.xml  { render :xml => @user_group.errors, :status => :not_acceptable }
            elsif (@user_group.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :message => "Deleted User Group '#{@user_group.name}'.")
                format.html { redirect_to user_groups_configuration_url(@configuration) }
                format.xml  { head :ok }
            else
                format.html { render :action => "user_groups" }
                format.xml  { head :ok }
            end
        end
    end


    def edit
        @configuration = @user_group.configuration
        respond_to do |format|
            format.html {@nav = '/configurations/user_group_nav'}
        end
    end


    def update
        @configuration = @user_group.configuration

        respond_to do |format|
            @nav = '/configurations/user_group_nav'
            if (@local_manager.slave?)
                @user_group.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "edit" }
                format.xml  { render :xml => @user_group.errors, :status => :not_acceptable }
            elsif @user_group.update_attributes(params[:user_group])
                @local_manager.log(:username => @session_user.username, :user_group_id => @user_group.id, :configuration_id => @configuration.id, :message => "Updated User Group '#{@user_group.name}'.")
                format.html { redirect_to user_groups_configuration_url(@configuration) }
                format.xml  { head :ok }
            else
                format.html { render :action => "edit" }
                format.xml  { render :xml => @user_group.errors, :status => :unprocessable_entity }
            end
        end
    end

private

    def authorize
        @user_group = UserGroup.find(params[:id])
        if (!@session_user.admin?)
            if ( !@configuration_roles.has_key?(@user_group.configuration_id) || @configuration_roles[@user_group.configuration_id] != 'admin' ) # deny if not owned by my config
                flash[:warning] = "Authorization failed. This attempt has been logged."
                @local_manager.log(:level => 'warn', :user_id => @session_user.id,
                                   :username => @session_user.username, :user_group_id => @user_group.id,
                                   :message => "Unauthorized access attempted to user-group #{@user_group.name}.")
                respond_to do |format|
                    format.html {redirect_to home_users_url}
                    format.xml {render :xml => "<errors><error>Authorization failed. This attempt has been logged.</error></errors>", :status => :forbidden}
                end
            end
        end
    end

end
