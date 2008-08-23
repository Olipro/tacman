class NetworkObjectGroupsController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change

    def changelog
        @log_count = SystemLog.count_by_sql("SELECT COUNT(*) FROM system_logs WHERE network_object_group_id=#{@network_object_group.id}")
        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = SystemLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                   :conditions => "network_object_group_id=#{@network_object_group.id}", :order => :created_at)
        respond_to do |format|
            @nav = 'show_nav'
            format.html {render :template => 'managers/system_logs'}
        end
    end

    def create_entry
        @configuration = @network_object_group.configuration
        @network_object_group_entry = @network_object_group.network_object_group_entries.build(params[:network_object_group_entry])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @network_object_group_entry.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @network_object_group_entry.errors, :status => :not_acceptable }
            elsif @network_object_group_entry.save
                @local_manager.log(:username => @session_user.username, :configuration_id => @network_object_group.configuration_id, :network_object_group_id => @network_object_group.id, :message => "Created entry #{@network_object_group_entry.cidr} of Network Object Group #{@network_object_group.name} within configuration #{@configuration.name}.")
                format.html { redirect_to network_object_group_url(@network_object_group) }
                format.xml  { render :xml => @network_object_group_entry.to_xml }
            else
                @network_object_group.reload
                format.html { render :action => "show" }
                format.xml  { render :xml => @network_object_group.errors, :status => :unprocessable_entity }
            end
        end
    end

    def destroy
        @configuration = @network_object_group.configuration

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @network_object_group.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @network_object_group.errors, :status => :not_acceptable }
            elsif (@network_object_group.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :message => "Deleted Network Object Group #{@network_object_group.name} from configuration #{@configuration.name}.")
                format.html { redirect_to network_object_groups_configuration_url(@configuration) }
                format.xml  { head :ok }
            else
                format.html { render :action => "show" }
                format.xml  { head :ok }
            end
        end
    end


    def edit
        respond_to do |format|
            format.html {@nav = 'show_nav'}
        end
    end


    def show
        respond_to do |format|
            @nav = 'show_nav'
            format.html # show.html.erb
            format.xml  { render :xml => @network_object_group }
        end
    end

    def optimize
        @configuration = @network_object_group.configuration
        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @network_object_group.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @network_object_group.errors, :status => :not_acceptable }
            elsif (@network_object_group.optimize!)
                @local_manager.log(:username => @session_user.username, :configuration_id => @network_object_group.configuration_id, :network_object_group_id => @network_object_group.id, :message => "Optimized Network Object Group #{@network_object_group.name} within configuration #{@configuration.name}.")
                format.html { redirect_to network_object_group_url(@network_object_group) }
                format.xml  { head :ok }
            else
                format.html { render :action => "show" }
                format.xml  { render :xml => @network_object_group.errors, :status => :unprocessable_entity }
            end
        end
    end

    def resequence
        @configuration = @network_object_group.configuration
        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @network_object_group.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @network_object_group.errors, :status => :not_acceptable }
            elsif (@network_object_group.resequence!)
                @local_manager.log(:username => @session_user.username, :configuration_id => @network_object_group.configuration_id, :network_object_group_id => @network_object_group.id, :message => "Resequenced Network Object Group #{@network_object_group.name} within configuration #{@configuration.name}.")
                format.html { redirect_to network_object_group_url(@network_object_group) }
                format.xml  { head :ok }
            else
                format.html { render :action => "show" }
                format.xml  { render :xml => @network_object_group.errors, :status => :unprocessable_entity }
            end
        end
    end

    def update
        @configuration = @network_object_group.configuration

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @network_object_group.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "edit" }
                format.xml  { render :xml => @network_object_group.errors, :status => :not_acceptable }
            elsif @network_object_group.update_attributes(params[:network_object_group])
                @local_manager.log(:username => @session_user.username, :configuration_id => @network_object_group.configuration_id, :network_object_group_id => @network_object_group.id, :message => "Renamed Network Object Group #{@network_object_group.name} within configuration #{@configuration.name}.")
                format.html { redirect_to network_object_group_url(@network_object_group) }
                format.xml  { head :ok }
            else
                format.html { render :action => "edit" }
                format.xml  { render :xml => @network_object_group.errors, :status => :unprocessable_entity }
            end
        end
    end

private

    def authorize
        @network_object_group = NetworkObjectGroup.find(params[:id])
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
