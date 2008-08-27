class ConfigurationsController < ApplicationController
    viewer_access = [:aaa_log_archives, :aaa_log_file, :aaa_logs, :aaa_log_details, :acls, :author_avpairs, :changelog, :command_authorization_profiles,
                     :command_authorization_whitelist, :download_archived_log, :log_search_form, :network_object_groups,
                     :search_aaa_logs, :settings, :shell_command_object_groups, :show, :tacacs_daemons, :tacacs_daemon_changelog,
                     :tacacs_daemon_logs, :tacacs_daemon_control, :user_groups]
    admin_access = [:add_users, :create_acl, :create_author_avpair, :create_configured_user, :create_command_authorization_profile,
                    :create_command_authorization_whitelist_entry,:create_network_object_group, 
                    :create_shell_command_object_group, :create_user_group, :edit, :new_acl, :new_author_avpair,
                    :new_command_authorization_profile, :new_command_authorization_whitelist_entry,
                    :new_configured_user, :new_network_object_group, :new_shell_command_object_group, 
                    :new_user_group, :publish, :resequence_whitelist, :update]
    su_exclude = admin_access.dup.concat(viewer_access)

    before_filter :define_session_user
    before_filter :authorize_admin, :except => su_exclude
    before_filter :authorize_config_admin, :only => admin_access
    before_filter :authorize_config_viewer, :only => viewer_access
    before_filter :force_pw_change

    def aaa_log_archives
        @files = AaaLogArchive.paginate(:page => params[:page], :per_page => @local_manager.pagination_per_page,
                                        :order => 'archived_on desc', :conditions => "configuration_id = #{@configuration.id}")
        respond_to do |format|
            @nav = 'show_nav'
            format.html
        end
    end

    def aaa_log_file
        @tacacs_daemon = TacacsDaemon.find(params[:tacacs_daemon_id])
        @configuration = Configuration.find(params[:id])

        if (@tacacs_daemon.local?)
            @log = @tacacs_daemon.aaa_log
        else
            manager = @tacacs_daemon.manager
            log = manager.read_remote_log_file(@tacacs_daemon,'aaa')
            if (manager.errors.length != 0)
                @log = ''
                @tacacs_daemon.errors.add_to_base("Error collecting remote log.")
                manager.errors.each_full {|e| @tacacs_daemon.errors.add_to_base(e) }
            else
                @log = log
            end
        end

        respond_to do |format|
            @nav = 'tacacs_daemon_nav'
            format.html
            format.xml  { render :xml => "<log>#{@log}</log>" }
        end
    end

    def aaa_logs
         @log_count = @configuration.aaa_logs.count

        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = AaaLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                :conditions => "configuration_id = #{@configuration.id}", :order => :timestamp)
        respond_to do |format|
            @nav = 'show_nav'
            format.html
        end
    end

    def aaa_log_details
        @log = AaaLog.find(params[:aaa_log_id])
        respond_to do |format|
            @nav = 'show_nav'
            format.html
        end
    end

    def acls
        @acls = @configuration.acls
        respond_to do |format|
            @nav = 'acl_nav'
            format.html
            format.xml  { render :xml => @acls.to_xml }
        end
    end

    def add_users
        @added = {}
        if (@configuration.department_id)
            @users = User.paginate(:page => params[:page], :per_page => @local_manager.pagination_per_page,
                                   :conditions => "department_id = #{@configuration.department_id}", :order => :username)
        else
            @users = User.paginate(:page => params[:page], :per_page => @local_manager.pagination_per_page,
                                   :conditions => "department_id is null", :order => :username)
        end
        @added = {}
        @configuration.configured_users.each {|cu| @added[cu.user_id] = cu.id }
        respond_to do |format|
            @nav = 'show_nav'
            format.html
            format.xml  { render :xml => @configuration }
        end
    end

    def author_avpairs
        @author_avpairs = @configuration.author_avpairs
        respond_to do |format|
            @nav = 'author_avpair_nav'
            format.html
            format.xml  { render :xml => @author_avpairs.to_xml }
        end
    end

    def changelog
        @log_count = SystemLog.count_by_sql("SELECT COUNT(*) FROM system_logs WHERE configuration_id=#{@configuration.id}")
        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = SystemLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                   :conditions => "configuration_id=#{@configuration.id}", :order => :created_at)
        respond_to do |format|
            @nav = 'show_nav'
            format.html {render :template => 'managers/system_logs'}
        end
    end

    def command_authorization_profiles
        @command_authorization_profiles = @configuration.command_authorization_profiles
        respond_to do |format|
            @nav = 'command_authorization_profile_nav'
            format.html
            format.xml  { render :xml => @command_authorization_profiles.to_xml }
        end
    end

    def command_authorization_whitelist
        @command_authorization_whitelist_entries = @configuration.command_authorization_whitelist_entries
        respond_to do |format|
            @nav = 'command_authorization_whitelist_nav'
            format.html
            format.xml  { render :xml => @command_authorization_whitelist_entries.to_xml }
        end
    end

    def create
        @configuration = Configuration.new(params[:configuration])

        respond_to do |format|
            @nav = 'index_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to configurations_url }
                format.xml  { render :xml => @configuration.errors, :status => :not_acceptable }
            elsif @configuration.save
                @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :message => "Created configuration #{@configuration.name}.")
                format.html { redirect_to configuration_url(@configuration) }
                format.xml  { render :xml => @configuration, :status => :created, :location => @configuration }
            else
                format.html { render :action => "new" }
                format.xml  { render :xml => @configuration.errors, :status => :unprocessable_entity }
            end
        end
    end

    def create_acl
        @data = params[:data]

        respond_to do |format|
            @nav = 'acl_nav'
            if (@local_manager.slave?)
                @acl = Acl.new
                @acl.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "new_acl" }
                format.xml  { render :xml => @acl.errors, :status => :not_acceptable }
            else
                @acl = @configuration.acl_from_string(@data)
                if (@acl.errors.length == 0)
                    @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :acl_id => @acl.id, :message => "Created ACL #{@acl.name} within configuration #{@configuration.name}.")
                    format.html { redirect_to acl_url(@acl) }
                    format.xml  { render :xml => @acl, :status => :created, :location => @acl }
                else
                    format.html { render :action => "new_acl" }
                    format.xml  { render :xml => @acl.errors, :status => :unprocessable_entity }
                end
            end
        end
    end


    def create_author_avpair
        @data = params[:data]

        respond_to do |format|
            @nav = 'author_avpair_nav'
            if (@local_manager.slave?)
                @author_avpair = AuthorAvpair.new
                @author_avpair.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "new_author_avpair" }
                format.xml  { render :xml => @author_avpair.errors, :status => :not_acceptable }
            else
                @author_avpair = @configuration.author_avpair_from_string(@data)
                if (@author_avpair.errors.length == 0)
                    @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :author_avpair_id => @author_avpair.id, :message => "Created Author AVPair #{@author_avpair.name} within configuration #{@configuration.name}.")
                    format.html { redirect_to author_avpair_url(@author_avpair) }
                    format.xml  { render :xml => @author_avpair, :status => :created, :location => @author_avpair }
                else
                    format.html { render :action => "new_author_avpair" }
                    format.xml  { render :xml => @author_avpair.errors, :status => :unprocessable_entity }
                end
            end
        end
    end

    def create_command_authorization_profile
        @data = params[:data]

        respond_to do |format|
            @nav = 'command_authorization_profile_nav'
            if (@local_manager.slave?)
                @command_authorization_profile = CommandAuthorizationProfile.new
                @command_authorization_profile.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "new_command_authorization_profile" }
                format.xml  { render :xml => @command_authorization_profile.errors, :status => :not_acceptable }
            else
                @command_authorization_profile = @configuration.command_authorization_profile_from_string(@data)
                if (@command_authorization_profile.errors.length == 0)
                    @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :command_authorization_profile_id => @command_authorization_profile.id, :message => "Created Command Authorization Profile #{@command_authorization_profile.name} within configuration #{@configuration.name}.")
                    format.html { redirect_to command_authorization_profile_url(@command_authorization_profile) }
                    format.xml  { render :xml => @command_authorization_profile, :status => :created, :location => @command_authorization_profile }
                else
                    format.html { render :action => "new_command_authorization_profile" }
                    format.xml  { render :xml => @command_authorization_profile.errors, :status => :unprocessable_entity }
                end
            end
        end
    end

    def create_command_authorization_whitelist_entry
        @command_authorization_whitelist_entry = @configuration.command_authorization_whitelist_entries.build(params[:command_authorization_whitelist_entry])

        respond_to do |format|
            @nav = 'command_authorization_whitelist_nav'
            if (@local_manager.slave?)
                @command_authorization_whitelist_entry.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => :command_authorization_whitelist, :id => @configuration }
                format.xml  { render :xml => @command_authorization_whitelist_entry.errors, :status => :not_acceptable }
            elsif @command_authorization_whitelist_entry.save
                @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :message => "Added whitelist entry #{@command_authorization_whitelist_entry.sequence} (#{@command_authorization_whitelist_entry.description}).")
                format.html { redirect_to command_authorization_whitelist_configuration_url(@configuration) }
                format.xml  { render :xml => @command_authorization_whitelist_entry, :status => :created, :location => @command_authorization_whitelist_entry }
            else
                @configuration.reload
                format.html { render :action => :command_authorization_whitelist, :id => @configuration }
                format.xml  { render :xml => @command_authorization_whitelist_entry.errors, :status => :unprocessable_entity }
            end
        end
    end

    def create_configured_user
        @configured_user = @configuration.configured_users.build(params[:configured_user])
        @user = User.find(params[:configured_user][:user_id])

        respond_to do |format|
            @nav = "configurations/show_nav"
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { render new_configured_user_configuration_url(@configuration) }
                format.xml  { render :xml => "<errors><error>#{flash[:warning]}</error></errors>", :status => :not_acceptable }
            elsif (@user.department_id != @configuration.department_id)
                flash[:warning] = "User and configuration are not part of the same department."
                format.html { render new_configured_user_configuration_url(@configuration) }
                format.xml  { render :xml => "<errors><error>#{flash[:warning]}</error></errors>", :status => :not_acceptable }
            else
                @configured_user.user_id = @user.id
                @configured_user.is_active = true
                @configured_user.save
                @local_manager.log(:username => @session_user.username, :user_id => @user.id, :configured_user_id => @configured_user.id, :configuration_id => @configuration.id, :message => "Added user #{@user.username} to configuration #{@configuration.name}.")
                format.html {redirect_to add_users_configuration_url(@configuration)}
                format.xml  { head :ok }
            end
        end
    end

    def create_network_object_group
        @data = params[:data]

        respond_to do |format|
            @nav = 'network_object_group_nav'
            if (@local_manager.slave?)
                @network_object_group = NetworkObjectGroup.new
                @network_object_group.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "new_network_object_group" }
                format.xml  { render :xml => @network_object_group.errors, :status => :not_acceptable }
            else
                @network_object_group = @configuration.network_object_group_from_string(@data)
                if (@network_object_group.errors.length == 0)
                    @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :network_object_group_id => @network_object_group.id, :message => "Created Network Object Group #{@network_object_group.name} within configuration #{@configuration.name}.")
                    format.html { redirect_to network_object_group_url(@network_object_group) }
                    format.xml  { render :xml => @network_object_group, :status => :created, :location => @network_object_group }
                else
                    format.html { render :action => "new_network_object_group" }
                    format.xml  { render :xml => @network_object_group.errors, :status => :unprocessable_entity }
                end
            end
        end
    end

    def create_shell_command_object_group
        @data = params[:data]

        respond_to do |format|
            @nav = 'shell_command_object_group_nav'
            if (@local_manager.slave?)
                @shell_command_object_group = ShellCommandObjectGroup.new
                @shell_command_object_group.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "new_shell_command_object_group" }
                format.xml  { render :xml => @shell_command_object_group.errors, :status => :not_acceptable }
            else
                @shell_command_object_group = @configuration.shell_command_object_group_from_string(@data)
                if (@shell_command_object_group.errors.length == 0)
                    @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :shell_command_object_group_id => @shell_command_object_group.id, :message => "Created Shell Command Object Group #{@shell_command_object_group.name} within configuration #{@configuration.name}.")
                    format.html { redirect_to shell_command_object_group_url(@shell_command_object_group) }
                    format.xml  { render :xml => @shell_command_object_group, :status => :created, :location => @shell_command_object_group }
                else
                    format.html { render :action => "new_shell_command_object_group" }
                    format.xml  { render :xml => @shell_command_object_group.errors, :status => :unprocessable_entity }
                end
            end
        end
    end

    def create_user_group
        @user_group = @configuration.user_groups.build(params[:user_group])

        respond_to do |format|
            @nav = 'user_group_nav'
            if (@local_manager.slave?)
                @user_group.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "new_user_group" }
                format.xml  { render :xml => @user_group.errors, :status => :not_acceptable }
            elsif @user_group.save
                @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :user_group_id => @user_group.id, :message => "Created User Group #{@user_group.name} within configuration #{@configuration.name}.")
                format.html { redirect_to user_groups_configuration_url(@configuration) }
                format.xml  { render :xml => @user_group, :status => :created, :location => @user_group }
            else
                format.html { render :action => "new_user_group" }
                format.xml  { render :xml => @user_group.errors, :status => :unprocessable_entity }
            end
        end
    end

    def destroy
        @configuration = Configuration.find(params[:id])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @configuration.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @configuration.errors, :status => :not_acceptable }
            else
                @configuration.destroy
                @local_manager.log(:username => @session_user.username, :message => "Deleted configuration #{@configuration.name}.")
                format.html { redirect_to(configurations_url) }
                format.xml  { head :ok }
            end
        end
    end

    def download_archived_log
        arch = AaaLogArchive.find(params[:aaa_log_archive_id])
        if ( File.exists?(arch.archive_file) )
            send_file(arch.archive_file)
        else
            flash[:warning] = "Selected archive '#{File.basename(arch.archive_file)}' is empty."
            redirect_to aaa_log_archives_configuration_url(@configuration)
        end

    end

    def edit
        @nav = 'show_nav'
    end


    def index
        @configurations = Configuration.find(:all, :order => :name)

        respond_to do |format|
            @nav = 'index_nav'
            format.html # index.html.erb
            format.xml  { render :xml => @configurations }
        end
    end

    def log_search_form
        respond_to do |format|
            @nav = 'show_nav'
            format.html
        end
    end

    def network_object_groups
        @network_object_groups = @configuration.network_object_groups
        respond_to do |format|
            @nav = 'network_object_group_nav'
            format.html
            format.xml  { render :xml => @network_object_groups.to_xml }
        end
    end


    def new
        @configuration = Configuration.new()
        @configuration.key = (1..12).collect { (i = Kernel.rand(62); i += ((i < 10) ? 48 : ((i < 36) ? 55 : 61 ))).chr }.join
        @configuration.retain_aaa_logs_for = @local_manager.maximum_aaa_log_retainment
        @configuration.archive_aaa_logs_for = @local_manager.maximum_aaa_archive_retainment

        respond_to do |format|
            @nav = 'index_nav'
            format.html # new.html.erb
            format.xml  { render :xml => @configuration }
        end
    end

    def new_acl
         @acl = @configuration.acls.build
        @data = "access-list "

        respond_to do |format|
            @nav = 'acl_nav'
            format.html
        end
    end

    def new_author_avpair
        @author_avpair = @configuration.author_avpairs.build
        @data = "author-avpair-list "

        respond_to do |format|
            @nav = 'author_avpair_nav'
            format.html
        end
    end

    def new_command_authorization_profile
        @command_authorization_profile = @configuration.command_authorization_profiles.build
        @data = "command-authorization-profile "

        respond_to do |format|
            @nav = 'command_authorization_profile_nav'
            format.html
        end
    end

    def new_command_authorization_whitelist_entry
        @command_authorization_whitelist_entry = @configuration.command_authorization_whitelist_entries.build

        respond_to do |format|
            @nav = 'command_authorization_whitelist_nav'
            format.html
        end
    end

    def new_configured_user
        @configured_user = @configuration.configured_users.build
        @configured_user.user_id = params[:user_id]

        respond_to do |format|
            @nav = "configurations/show_nav"
            format.html
            format.xml  { head :ok }
        end
    end

    def new_network_object_group
        @network_object_group = @configuration.network_object_groups.build
        @data = "network-object-group "

        respond_to do |format|
            @nav = 'network_object_group_nav'
            format.html
        end
    end

    def new_shell_command_object_group
        @shell_command_object_group = @configuration.shell_command_object_groups.build
        @data = "shell-command-object-group "

        respond_to do |format|
            @nav = 'shell_command_object_group_nav'
            format.html
        end
    end

    def new_user_group
        @user_group = @configuration.user_groups.build

        respond_to do |format|
            @nav = 'user_group_nav'
            format.html
        end
    end

    def publish
        @configuration.publish
        respond_to do |format|
            flash[:notice] = "Published changes will take a few moments to propagate."
            @nav = 'show_nav'
            @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :message => "Published configuration #{@configuration.name}.")
            format.html { redirect_to( request.env["HTTP_REFERER"] ) }
            format.xml  { head :ok }
        end
    end

    def resequence_whitelist
        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @configuration.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "command_authorization_whitelist" }
                format.xml  { render :xml => @configuration.errors, :status => :not_acceptable }
            elsif (@configuration.resequence_whitelist!)
                @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :message => "Resequenced whitelist for configuration #{@configuration.name}.")
                format.html { redirect_to command_authorization_whitelist_configuration_url(@configuration) }
                format.xml  { head :ok }
            else
                format.html { render :action => "command_authorization_whitelist" }
                format.xml  { render :xml => @configuration.errors, :status => :unprocessable_entity }
            end
        end
    end

    def search_aaa_logs
        @search_opts = {}
        criteria = []
        criteria_vals = []

        if (!params[:search_criteria][:start_time].blank?)
            criteria.push("timestamp >= ?")
            criteria_vals.push(params[:search_criteria][:start_time])
            @search_opts['search_criteria[start_time]'] = params[:search_criteria][:start_time]
        end

        if (!params[:search_criteria][:end_time].blank?)
            criteria.push("timestamp <= ?")
            criteria_vals.push(params[:search_criteria][:end_time])
            @search_opts['search_criteria[end_time]'] = params[:search_criteria][:end_time]
        end

        if (!params[:search_criteria][:client].blank?)
            criteria.push("client regexp ?")
            criteria_vals.push(params[:search_criteria][:client])
            @search_opts['search_criteria[client]'] = params[:search_criteria][:client]
        end

        if (!params[:search_criteria][:client_name].blank?)
            criteria.push("client_name regexp ?")
            criteria_vals.push(params[:search_criteria][:client_name])
            @search_opts['search_criteria[client_name]'] = params[:search_criteria][:client_name]
        end

        if (!params[:search_criteria][:user].blank?)
            criteria.push("user regexp ?")
            criteria_vals.push(params[:search_criteria][:user])
            @search_opts['search_criteria[user]'] = params[:search_criteria][:user]
        end

        if (!params[:search_criteria][:message].blank?)
            criteria.push("message regexp ?")
            criteria_vals.push(params[:search_criteria][:message])
            @search_opts['search_criteria[message]'] = params[:search_criteria][:message]
        end

        respond_to do |format|
            @nav = 'show_nav'
            if (criteria.length != 0)
                criteria.push("configuration_id = ?")
                criteria_vals.push(@configuration.id)
                conditions = criteria.join(" and ")
                @log_count = AaaLog.count_by_sql( ["SELECT COUNT(*) FROM aaa_logs WHERE #{conditions}"].concat(criteria_vals) )

                if ( params.has_key?(:page) )
                    page = params[:page]
                elsif (@log_count > 0)
                    page = @log_count / @local_manager.pagination_per_page
                    page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
                end
                @logs = AaaLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                        :conditions => [conditions].concat(criteria_vals), :order => :timestamp)
                format.html { render :action => :aaa_logs}
            else
                format.html { redirect_to aaa_logs_configuration_url(@configuration) }
            end
        end
    end

    def settings
        respond_to do |format|
            @nav = 'show_nav'
            format.html
            format.xml  { render :xml => @configuration }
        end
    end

    def shell_command_object_groups
        @shell_command_object_groups = @configuration.shell_command_object_groups
        respond_to do |format|
            @nav = 'shell_command_object_group_nav'
            format.html
            format.xml  { render :xml => @shell_command_object_groups.to_xml }
        end
    end

    def show
        sql = "select users.id,users.username,users.real_name,users.department_id,users.disabled from users,configured_users " +
              "where configured_users.configuration_id = #{@configuration.id} and configured_users.user_id = users.id " +
              "order by users.username"
        @users = User.paginate_by_sql(sql, :page => params[:page], :per_page => @local_manager.pagination_per_page)
        @configured_users = {}
        @configuration.configured_users.each {|cu| @configured_users[cu.user_id] = cu}
        respond_to do |format|
            @nav = 'show_nav'
            format.html # show.html.erb
            format.xml  { render :xml => @configuration }
        end
    end

    def tacacs_daemons
        @tacacs_daemons = @configuration.tacacs_daemons
        @managers = Manager.find(:all, :order => :name)
        respond_to do |format|
            @nav = 'tacacs_daemon_nav'
            format.html
            format.xml  { render :xml => @tacacs_daemons.to_xml }
        end
    end


    def tacacs_daemon_changelog
        @tacacs_daemon = TacacsDaemon.find(params[:id])
        @configuration = @tacacs_daemon.configuration
        @log_count = SystemLog.count_by_sql("SELECT COUNT(*) FROM system_logs WHERE tacacs_daemon_id=#{@tacacs_daemon.id}")
        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = SystemLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                   :conditions => "tacacs_daemon_id=#{@tacacs_daemon.id}", :order => :created_at)
        respond_to do |format|
            @nav = 'tacacs_daemon_nav'
            format.html {render :template => 'managers/system_logs'}
        end
    end

    def tacacs_daemon_control
        respond_to do |format|
            @nav = 'tacacs_daemon_nav'
            if ( params.has_key?(:selected) )
                cmd = params[:command]
                cmd = 'read' if ( cmd != 'reload' && cmd != 'restart' && cmd != 'start' && cmd != 'stop' )
                op_on = []
                ids = params[:selected].keys
                tds = []
                excluded = []
                @configuration.tacacs_daemons.each do |td|
                    if ( ids.include?(td.id.to_s) )
                        tds.push(td)
                        op_on.push(td)
                    else
                        excluded.push(td)
                    end
                end

                if (cmd != 'read')
                    op_on.each do |td|
                        @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :tacacs_daemon_id => td.id, :message => "Issued command '#{cmd}' on daemon #{td.name}.")
                    end
                end

                start_stop = Manager.start_stop_tacacs_daemons(tds,cmd)
                @managers = start_stop[:managers]
                @tacacs_daemons = start_stop[:tacacs_daemons]
                @tacacs_daemons.concat(excluded)
                format.html {render :action => :tacacs_daemons}
                format.xml  { head :ok }
            else
                format.html {redirect_to tacacs_daemons_configuration_url(@configuration)}
                format.xml  { head :ok }
            end
        end
    end

    def tacacs_daemon_logs
        @tacacs_daemons = @configuration.tacacs_daemons
        respond_to do |format|
            @nav = 'tacacs_daemon_nav'
            format.html
            format.xml  { render :xml => @tacacs_daemons.to_xml }
        end
    end

    def update
        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @configuration.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "edit" }
                format.xml  { render :xml => @configuration.errors, :status => :not_acceptable }
            elsif @configuration.update_attributes(params[:configuration])
                @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :message => "Updated configuration #{@configuration.name}.")
                format.html { redirect_to settings_configuration_url(@configuration) }
                format.xml  { head :ok }
            else
                format.html { render :action => "edit" }
                format.xml  { render :xml => @configuration.errors, :status => :unprocessable_entity }
            end
        end
    end

    def user_groups
        @user_groups = @configuration.user_groups
        respond_to do |format|
            @nav = 'user_group_nav'
            format.html
            format.xml  { render :xml => @user_groups.to_xml }
        end
    end

private

    def authorize_config_admin()
        @configuration = Configuration.find(params[:id]) if (!@configuration)
        if (!@session_user.admin?)
            if ( !@configuration_roles.has_key?(@configuration.id) ) # deny if not my config
                flash[:warning] = "Authorization failed. This attempt has been logged."
                @local_manager.log(:level => 'warn', :user_id => @session_user.id, :configuration_id => @configuration.id, :username => @session_user.username, :message => "Unauthorized access attempted for configuration #{@configuration.name}.")
                respond_to do |format|
                    format.html {redirect_to home_users_url}
                    format.xml {render :xml => "<errors><error>Authorization failed. This attempt has been logged.</error></errors>", :status => :forbidden}
                end
            elsif (@configuration_roles[@configuration.id] != 'admin') # deny if i'm not an admin of this config
                flash[:warning] = "Authorization failed. This attempt has been logged."
                @local_manager.log(:level => 'warn', :user_id => @session_user.id, :configuration_id => @configuration.id, :username => @session_user.username, :message => "Unauthorized access attempted for configuration #{@configuration.name} by non administrator.")
                respond_to do |format|
                    format.html {redirect_to home_users_url}
                    format.xml {render :xml => "<errors><error>Authorization failed. This attempt has been logged.</error></errors>", :status => :forbidden}
                end
            end
        end
    end

    def authorize_config_viewer()
        @configuration = Configuration.find(params[:id]) if (!@configuration)
        if (!@session_user.admin?)
            if ( !@configuration_roles.has_key?(@configuration.id) ) # deny if not my config
                flash[:warning] = "Authorization failed. This attempt has been logged."
                @local_manager.log(:level => 'warn', :user_id => @session_user.id, :configuration_id => @configuration.id, :username => @session_user.username, :message => "Unauthorized access attempted for configuration #{@configuration.name}.")
                respond_to do |format|
                    format.html {redirect_to home_users_url}
                    format.xml {render :xml => "<errors><error>Authorization failed. This attempt has been logged.</error></errors>", :status => :forbidden}
                end
            elsif (@configuration_roles[@configuration.id] != 'admin' && @configuration_roles[@configuration.id] != 'viewer') # deny if i'm not an admin/viewer of thisconfig
                flash[:warning] = "Authorization failed. This attempt has been logged."
                @local_manager.log(:level => 'warn', :user_id => @session_user.id, :configuration_id => @configuration.id, :username => @session_user.username, :message => "Unauthorized access attempted for configuration #{@configuration.name} by non viewer.")
                respond_to do |format|
                    format.html {redirect_to home_users_url}
                    format.xml {render :xml => "<errors><error>Authorization failed. This attempt has been logged.</error></errors>", :status => :forbidden}
                end
            end
        end
    end

end

