class AclsController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change

    def changelog
        @log_count = SystemLog.count_by_sql("SELECT COUNT(*) FROM system_logs WHERE acl_id=#{@acl.id}")
        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = SystemLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                   :conditions => "acl_id=#{@acl.id}", :order => :created_at)
        respond_to do |format|
            @nav = 'show_nav'
            format.html {render :template => 'managers/system_logs'}
        end
    end

    def create_entry
        @acl_entry = @acl.acl_entries.build(params[:acl_entry])
        @configuration = @acl.configuration

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @acl_entry.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @acl_entry.errors, :status => :not_acceptable }
            elsif @acl_entry.save
                @local_manager.log(:username => @session_user.username, :configuration_id => @acl.configuration_id, :acl_id => @acl.id, :message => "Added entry '#{@acl_entry.description}' to ACL #{@acl.name} within configuration #{@configuration.name}.")
                format.html { redirect_to acl_url(@acl) }
                format.xml  { render :xml => @acl_entry.to_xml }
            else
                @acl.reload
                format.html { render :action => "show" }
                format.xml  { render :xml => @acl.errors, :status => :unprocessable_entity }
            end
        end
    end

    def destroy
        @configuration = @acl.configuration

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @acl.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @acl.errors, :status => :not_acceptable }
            elsif (@acl.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :message => "Deleted ACL #{@acl.name} from configuration #{@configuration.name}.")
                format.html { redirect_to acls_configuration_url(@configuration) }
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

    def resequence
        @configuration = @acl.configuration

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @acl.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @acl.errors, :status => :not_acceptable }
            elsif (@acl.resequence!)
                @local_manager.log(:username => @session_user.username, :configuration_id => @acl.configuration_id, :acl_id => @acl.id, :message => "Resequenced ACL #{@acl.name} within configuration #{@configuration.name}.")
                format.html { redirect_to acl_url(@acl) }
                format.xml  { head :ok }
            else
                format.html { render :action => "show" }
                format.xml  { render :xml => @acl.errors, :status => :unprocessable_entity }
            end
        end
    end

    def show
        respond_to do |format|
            @nav = 'show_nav'
            format.html # show.html.erb
            format.xml  { render :xml => @acl }
        end
    end


    def update
        @configuration = @acl.configuration

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @acl.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "edit" }
                format.xml  { render :xml => @acl.errors, :status => :not_acceptable }
            elsif @acl.update_attributes(params[:acl])
                @local_manager.log(:username => @session_user.username, :configuration_id => @acl.configuration_id, :acl_id => @acl.id, :message => "Renamed ACL to #{@acl.name} within configuration #{@configuration.name}.")
                format.html { redirect_to acl_url(@acl) }
                format.xml  { head :ok }
            else
                format.html { render :action => "edit" }
                format.xml  { render :xml => @acl.errors, :status => :unprocessable_entity }
            end
        end
    end

private

    def authorize
        @acl = Acl.find(params[:id])
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


