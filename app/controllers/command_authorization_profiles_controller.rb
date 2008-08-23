class  CommandAuthorizationProfilesController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change

    def changelog
        @log_count = SystemLog.count_by_sql("SELECT COUNT(*) FROM system_logs WHERE command_authorization_profile_id=#{@command_authorization_profile.id}")
        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = SystemLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                   :conditions => "command_authorization_profile_id=#{@command_authorization_profile.id}", :order => :created_at)
        respond_to do |format|
            @nav = 'show_nav'
            format.html {render :template => 'managers/system_logs'}
        end
    end

    def create_entry
        @configuration = @command_authorization_profile.configuration
        @command_authorization_profile_entry = @command_authorization_profile.command_authorization_profile_entries.build(params[:command_authorization_profile_entry])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @command_authorization_profile_entry.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @command_authorization_profile_entry.errors, :status => :not_acceptable }
            elsif @command_authorization_profile_entry.save
                @local_manager.log(:username => @session_user.username, :configuration_id => @command_authorization_profile.configuration_id, :command_authorization_profile_id => @command_authorization_profile.id, :message => "Created entry #{@command_authorization_profile_entry.description} of Command Authorization Profile #{@command_authorization_profile.name} within configuration #{@configuration.name}.")
                format.html { redirect_to command_authorization_profile_url(@command_authorization_profile) }
                format.xml  { render :xml => @command_authorization_profile_entry.to_xml }
            else
                @command_authorization_profile.reload
                format.html { render :action => "show" }
                format.xml  { render :xml => @command_authorization_profile.errors, :status => :unprocessable_entity }
            end
        end
    end

    def destroy
        @configuration = @command_authorization_profile.configuration

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @command_authorization_profile.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @command_authorization_profile.errors, :status => :not_acceptable }
            elsif (@command_authorization_profile.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :message => "Deleted Command Authorization Profile #{@command_authorization_profile.name} from configuration #{@configuration.name}.")
                format.html { redirect_to command_authorization_profiles_configuration_url(@configuration) }
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
        @configuration = @command_authorization_profile.configuration

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @command_authorization_profile.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @command_authorization_profile.errors, :status => :not_acceptable }
            elsif (@command_authorization_profile.resequence!)
                @local_manager.log(:username => @session_user.username, :configuration_id => @command_authorization_profile.configuration_id, :command_authorization_profile_id => @command_authorization_profile.id, :message => "Resequenced Command Authorization Profile #{@command_authorization_profile.name} within configuration #{@configuration.name}.")
                format.html { redirect_to command_authorization_profile_url(@command_authorization_profile) }
                format.xml  { head :ok }
            else
                format.html { render :action => "show" }
                format.xml  { render :xml => @command_authorization_profile.errors, :status => :unprocessable_entity }
            end
        end
    end

    def show

        respond_to do |format|
            @nav = 'show_nav'
            format.html # show.html.erb
            format.xml  { render :xml => @command_authorization_profile }
        end
    end


    def update
        @configuration = @command_authorization_profile.configuration
        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @command_authorization_profile.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "edit" }
                format.xml  { render :xml => @command_authorization_profile.errors, :status => :not_acceptable }
            elsif @command_authorization_profile.update_attributes(params[:command_authorization_profile])
                @local_manager.log(:username => @session_user.username, :configuration_id => @command_authorization_profile.configuration_id, :command_authorization_profile_id => @command_authorization_profile.id, :message => "Renamed Command Authorization Profile #{@command_authorization_profile.name} within configuration #{@configuration.name}.")
                format.html { redirect_to command_authorization_profile_url(@command_authorization_profile) }
                format.xml  { head :ok }
            else
                format.html { render :action => "edit" }
                format.xml  { render :xml => @command_authorization_profile.errors, :status => :unprocessable_entity }
            end
        end
    end

private

    def authorize
        @command_authorization_profile = CommandAuthorizationProfile.find(params[:id])
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
