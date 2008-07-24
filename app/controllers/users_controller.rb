class UsersController < ApplicationController
    filter_parameter_logging :password, :enable

    user_pages = [:authenticate, :change_password, :change_enable, :help, :home, :login, :logout,
                  :request_join, :update_change_password, :update_change_enable, :withdraw_join]
    user_admin_pages = [:aaa_logs, :changelog, :create, :destroy, :edit, :force_join, :force_withdraw,
                        :index, :new, :publish, :reset_enable, :reset_password, :show, :system_logs,
                        :toggle_allow_web_login, :toggle_disabled, :toggle_enable_expiry, :toggle_password_expiry,
                        :update, :update_reset_enable, :update_reset_password ]
    su_exclude = user_pages.concat(user_admin_pages)

    before_filter :define_session_user, :except => [:authenticate, :login, :logout]
    before_filter :force_pw_change, :except => [:authenticate, :change_password, :change_enable,
                                                :login, :logout, :update_change_password, :update_change_enable ]
    before_filter :authorize_user_admin, :only => user_admin_pages
    before_filter :authorize_admin, :except => su_exclude

    def aaa_logs
        @user = User.find(params[:id])
        @log_count = AaaLog.count_by_sql("SELECT COUNT(*) FROM aaa_logs WHERE user='#{@user.username}'")

        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = AaaLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                :conditions => "user = '#{@user.username}'", :order => :timestamp)
        respond_to do |format|
            @nav = 'show_nav'
            format.html { render :template => "configurations/aaa_logs"}
        end
    end

    # POST /users
    # POST /users.xml
    def authenticate
        get_remote_addr()
        pass = false
        user = User.find_by_username(params[:user][:username])
        pass = user.verify_password(params[:user][:password]) if (user)
        @local_manager = Manager.local

        respond_to do |format|
            if (pass)
                @session_user = user
                session[:user_id] = @session_user.id
                uri = session[:original_uri]
                @local_manager.log(:username => user.username, :message => "Login to #{@local_manager.name} from #{@remote_addr}")
                user.last_login = Time.now
                format.html do
                    if (uri)
                        redirect_to(uri)
                    else
                        redirect_to(home_users_url)
                    end
                end
                format.xml  { head :ok }
            else
                @local_manager.log(:username => params[:user][:username], :message => "Failed login attempted on #{@local_manager.name} from #{@remote_addr}")
                flash[:warning] = "Username or password incorrect. This attempt has been logged."
                format.html {redirect_to(login_users_url)  }
                format.xml {render :xml => "<errors><error>Username or password incorrect. This attempt has been logged.</error></errors>", :status => :forbidden}
            end
        end
    end


    def bulk_create
        respond_to do |format|
            @nav = 'index_nav'
            format.html # new.html.erb
        end
    end


    # GET /users/1/change_enable
    def change_enable
        @user = @session_user
        @nav = 'home_nav'
    end


    # GET /users/1/change_password
    def change_password
        @user = @session_user
        @nav = 'home_nav'
    end


    def changelog
        @user = User.find(params[:id])
        @log_count = SystemLog.count_by_sql("SELECT COUNT(*) FROM system_logs WHERE user_id=#{@user.id}")
        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = SystemLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                   :conditions => "user_id=#{@user.id}", :order => :created_at)
        respond_to do |format|
            @nav = 'show_nav'
            format.html {render :template => 'managers/system_logs'}
        end
    end


    # POST /users
    # POST /users.xml
    def create
        @user = User.new(params[:user])

        respond_to do |format|
            @nav = 'index_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to users_url }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            else
                begin
                    User.transaction do
                        @user.save
                        if ( params.has_key?(:no_expire) )
                            @user.set_password(params[:enable], params[:enable], true, false)
                            @user.set_password(params[:password], params[:password], false, false)
                        else
                            @user.set_password(params[:enable], params[:enable], true)
                            @user.set_password(params[:password], params[:password], false)
                        end
                        raise if (@user.errors.length > 0)

                        if ( params.has_key?(:notify) )
                            begin
                                TacmanMailer.deliver_new_account(@local_manager, @user, params[:password], params[:enable]) if (!@user.email.blank?)
                            rescue Exception => error
                                @local_manager.log(:user_id=> @user.id, :message => "Failed to notify #{@user.username} of account creation - #{error}")
                            end
                        end

                        @local_manager.log(:username => @session_user.username, :user_id=> @user.id, :message => "Created user '#{@user.username}'.")
                        format.html { redirect_to user_url(@user) }
                        format.xml  { render :xml => @user, :status => :created, :location => @user }
                    end
                rescue Exception => error
                    format.html { render :action => "new" }
                    format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
                end
            end
        end
    end


    # DELETE /users/1
    # DELETE /users/1.xml
    def destroy
        @user = User.find(params[:id])
        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif (@user.id == @session_user.id)
                flash[:warning] = "You may not delete your own account."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => @user.errors, :status => :not_acceptable }
            elsif (@user.admin? && @session_user.user_admin?)
                flash[:warning] = "You do not have permission to delete administrator accounts."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => @user.errors, :status => :not_acceptable }
            elsif (@user.destroy)
                @local_manager.log(:username => @session_user.username, :message => "Deleted user '#{@user.username}'.")
                format.html { redirect_to(users_url) }
                format.xml  { head :ok }
            else
                flash[:warning] = "error"
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => @user.errors, :status => :not_acceptable }
            end
        end
    end


    # GET /users/1/edit
    def edit
        @user = User.find(params[:id])
        @nav = 'show_nav'
    end


    def force_join
        @user = User.find(params[:id])
        configuration = Configuration.find(params[:configuration])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif (configuration)
                cu = @user.configured_users.build()
                cu.configuration_id = configuration.id
                cu.state = 'approved'
                cu.save
                @local_manager.log(:username => @session_user.username, :configuration_id => configuration.id, :user_id=> @user.id, :message => "Manually added user '#{@user.username}' to Configuration '#{configuration.name}'")
                flash[:notice] = "Membership created and approved."
                format.html { redirect_to user_url(@user) }
                format.xml  { head :ok }
            else
                @user.errors.add_to_base("Unknown Configuration #{configuration.id}.")
                format.html { render :action => :show }
                format.xml  { render :xml => @user.errors, :status => :not_acceptable }
            end
        end
    end


    def force_withdraw
        @user = User.find(params[:id])
        configuration = Configuration.find(params[:configuration])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif (configuration)
                cu = ConfiguredUser.find(:first, :conditions => "user_id = #{@user.id} and configuration_id = #{configuration.id}")
                if (cu)
                    cu.destroy
                    @local_manager.log(:username => @session_user.username, :configuration_id => configuration.id, :user_id=> @user.id, :message => "Withdrew user '#{@user.username}' from Configuration '#{configuration.name}'.")
                    flash[:notice] = "Membership has been withdrawn."
                end
                format.html { redirect_to user_url(@user) }
                format.xml  { head :ok }
            else
                @user.errors.add_to_base("Unknown Configuration #{configuration.id}.")
                format.html { render :action => :show }
                format.xml  { render :xml => @user.errors, :status => :not_acceptable }
            end
        end
    end

    def help
        @user = @session_user
        respond_to do |format|
            @nav = 'help_nav'
            format.html
        end
    end

    def home
        @user = @session_user
        @configurations = Configuration.find(:all, :order => :name)
        @memberships = {}
        @user.configured_users.each {|x| @memberships[x.configuration_id] = x}

        respond_to do |format|
            @nav = 'home_nav'
            format.html # home.html.erb
        end
    end


    def import
        @data = params[:data]
        respond_to do |format|
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            else
                @nav = 'index_nav'
                errors = User.import(@data)
                if (errors.length == 0)
                    @local_manager.log(:username=> @session_user.username, :message => "Bulk created new user accounts.")
                    format.html {redirect_to users_url}
                    format.xml{head :ok}
                else
                    @import_errors = errors
                    format.html {render :action => :bulk_create}
                    format.xml{render :xml => @import_errors.to_xml}
                end
            end
        end
    end


    # GET /users
    # GET /users.xml
    def index
        @users = User.paginate(:page => params[:page], :per_page => @local_manager.pagination_per_page,
                               :order => :username)
        respond_to do |format|
            @nav = 'index_nav'
            format.html # index.html.erb
            format.xml  { render :xml => @users }
        end
    end


    # GET /users
    # GET /users.xml
    def login
        session[:user_id] = nil
    end


    # GET /users
    # GET /users.xml
    def logout
        session[:user_id] = nil
        session[:original_uri] = nil
        flash[:notice] = 'Logged out'
        respond_to do |format|
            format.html { redirect_to login_users_url }
            format.xml  { head :ok }
        end
    end

    # GET /users/new
    # GET /users/new.xml
    def new
        @user = User.new(:login_password_lifespan => @local_manager.default_login_password_lifespan,
                         :enable_password_lifespan => @local_manager.default_enable_password_lifespan)

        respond_to do |format|
            @nav = 'index_nav'
            format.html # new.html.erb
            format.xml  { render :xml => @user }
        end
    end

    def publish
        @user = User.find(params[:id])
        @user.publish!
        respond_to do |format|
            @nav = 'show_nav'
            flash[:notice] = "Changes published but may take a few minutes to take effect."
            @local_manager.log(:username => @session_user.username, :user_id => @user.id, :message => "Published user '#{@user.username}'.")
            format.html { redirect_to user_url(@user) }
            format.xml  { head :ok }
        end
    end

    def request_join
        @user = User.find(params[:id])
        configuration = Configuration.find(params[:configuration])

        respond_to do |format|
            @nav = 'home_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to home_users_url }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif (configuration && !configuration.is_hidden)
                cu = @user.configured_users.build()
                cu.configuration_id = configuration.id
                cu.save
                @local_manager.log(:username => @session_user.username, :configuration_id => configuration.id, :user_id=> @session_user.id, :message => "Requested membership to Configuration '#{configuration.name}'.")
                flash[:notice] = "Membership requested and is currently pending approval."
                format.html { redirect_to home_users_url() }
                format.xml  { head :ok }
            else
                flash[:warning] = "Unknown Configuration #{configuration.id}."
                format.html { redirect_to home_users_url }
                format.xml  { render :xml => @user.errors, :status => :not_acceptable }
            end
        end
    end


    # GET /users/1/reset_enable
    def reset_enable
        @user = User.find(params[:id])
        @nav = 'show_nav'
    end


    # GET /users/1/reset_password
    def reset_password
        @user = User.find(params[:id])
        @nav = 'show_nav'
    end


    # PUT /users/1
    # PUT /users/1.xml
    def set_role_admin
        @user = User.find(params[:id])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif (@user.id == @session_user.id)
                @user.errors.add_to_base("Users may not change their own role.")
                format.html { render :action => :show }
                format.xml  { render :xml => @user.errors, :status => :not_acceptable }
            else
                @user.admin!
                @local_manager.log(:username => @session_user.username, :user_id=> @user.id, :message => "Set role to 'admin' for '#{@user.username}'.")
                format.html { redirect_to user_url(@user) }
                format.xml  { head :ok }
            end
        end
    end


    # PUT /users/1
    # PUT /users/1.xml
    def set_role_user
        @user = User.find(params[:id])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif (@user.id == @session_user.id)
                @user.errors.add_to_base("Users may not change their own role.")
                format.html { render :action => :show }
                format.xml  { render :xml => @user.errors, :status => :not_acceptable }
            else
                @user.user!
                @local_manager.log(:username => @session_user.username, :user_id=> @user.id, :message => "Set role to 'user' for '#{@user.username}'.")
                format.html { redirect_to user_url(@user) }
                format.xml  { head :ok }
            end
        end
    end


    # PUT /users/1
    # PUT /users/1.xml
    def set_role_user_admin
        @user = User.find(params[:id])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif (@user.id == @session_user.id)
                @user.errors.add_to_base("Users may not change their own role.")
                format.html { render :action => :show }
                format.xml  { render :xml => @user.errors, :status => :not_acceptable }
            else
                @user.user_admin!
                @local_manager.log(:username => @session_user.username, :user_id=> @user.id, :message => "Set role to 'user_admin' for '#{@user.username}'.")
                format.html { redirect_to user_url(@user) }
                format.xml  { head :ok }
            end
        end
    end


    # GET /users/1
    # GET /users/1.xml
    def show
        @user = User.find(params[:id])
        @configurations = Configuration.find(:all, :order => :name)
        @memberships = {}
        @user.configured_users.each {|x| @memberships[x.configuration_id] = x}

        respond_to do |format|
            @nav = 'show_nav'
            format.html # show.html.erb
            format.xml  { render :xml => @user }
        end
    end


    def system_logs
        @user = User.find(params[:id])
        @log_count = SystemLog.count_by_sql("SELECT COUNT(*) FROM system_logs WHERE username='#{@user.username}'")
        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = SystemLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                   :conditions => "username = '#{@user.username}'", :order => :created_at)
        respond_to do |format|
            @nav = 'show_nav'
            format.html {render :template => 'managers/system_logs'}
        end
    end


    # PUT /users/1
    # PUT /users/1.xml
    def toggle_allow_web_login
        @user = User.find(params[:id])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif (@user.admin? && @session_user.user_admin?)
                flash[:warning] = "You do not have permission to modify administrator accounts."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => @user.errors, :status => :not_acceptable }
            else
                @user.toggle_allow_web_login!
                @local_manager.log(:username => @session_user.username, :user_id=> @user.id, :message => "Toggled web login access (current=#{@user.allow_web_login}) for '#{@user.username}'.")
                format.html { redirect_to user_url(@user) }
                format.xml  { head :ok }
            end
        end
    end

    # PUT /users/1
    # PUT /users/1.xml
    def toggle_disabled
        @user = User.find(params[:id])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif (@user.admin? && @session_user.user_admin?)
                flash[:warning] = "You do not have permission to modify administrator accounts."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => @user.errors, :status => :not_acceptable }
            else
                @user.toggle_disabled!
                @local_manager.log(:username => @session_user.username, :user_id=> @user.id, :message => "Set account status = #{@user.account_status} for '#{@user.username}'.")
                format.html { redirect_to user_url(@user) }
                format.xml  { head :ok }
            end
        end
    end


    # PUT /users/1
    # PUT /users/1.xml
    def toggle_enable_expiry
        @user = User.find(params[:id])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            else
                @user.toggle_enable_expiry!
                @local_manager.log(:username => @session_user.username, :user_id=> @user.id, :message => "Toggled enable expiry (current=#{@user.enable_password_expired?}) for '#{@user.username}'.")
                format.html { redirect_to user_url(@user) }
                format.xml  { head :ok }
            end
        end
    end


    # PUT /users/1
    # PUT /users/1.xml
    def toggle_password_expiry
        @user = User.find(params[:id])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            else
                @user.toggle_password_expiry!
                @local_manager.log(:username => @session_user.username, :user_id=> @user.id, :message => "Toggled password expiry (current=#{@user.login_password_expired?}) for '#{@user.username}'.")
                format.html { redirect_to user_url(@user) }
                format.xml  { head :ok }
            end
        end
    end


    # PUT /users/1
    # PUT /users/1.xml
    def update
        @user = User.find(params[:id])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @nav = 'show_nav'
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif (@user.admin? && @session_user.user_admin?)
                flash[:warning] = "You do not have permission to modify administrator accounts."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => @user.errors, :status => :not_acceptable }
            elsif @user.update_attributes(params[:user])
                @local_manager.log(:username => @session_user.username, :user_id=> @user.id, :message => "Edited '#{@user.username}'.")
                format.html { redirect_to user_url(@user) }
                format.xml  { head :ok }
            else
                format.html { render :action => "edit" }
                format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
            end
        end
    end


    # PUT /users/1/update_change_enable
    # PUT /users/1.xml
    def update_change_enable
        @user = @session_user
        uri = session[:original_uri]

        respond_to do |format|
            @nav = 'home_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to home_users_url }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif @user.change_password(params[:new_password], params[:password_confirmation], params[:current_password], true)
                format.html do
                    if (uri)
                        redirect_to(uri)
                    else
                        redirect_to(home_users_url)
                    end
                end
                @local_manager.log(:username => @session_user.username, :user_id=> @session_user.id, :message => "User changed their enable password")
                format.xml  { head :ok }
            else
                format.html { render :action => "change_enable" }
                format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
            end
        end
    end


    # PUT /users/1/update_change_password
    # PUT /users/1.xml
    def update_change_password
        @user = @session_user
        uri = session[:original_uri]

        respond_to do |format|
            @nav = 'home_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to home_users_url }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif @user.change_password(params[:new_password], params[:password_confirmation], params[:current_password])
                format.html do
                    if (uri)
                        redirect_to(uri)
                    else
                        redirect_to(home_users_url)
                    end
                end
                @local_manager.log(:username => @session_user.username, :user_id=> @session_user.id, :message => "User changed their password")
                format.xml  { head :ok }
            else
                format.html { render :action => "change_password" }
                format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
            end
        end
    end


    # PUT /users/1/update_reset_enable
    # PUT /users/1.xml
    def update_reset_enable
        @user = User.find(params[:id])

        respond_to do |format|
            expire = true
            expire = false if ( params.has_key?(:no_expire) )

            @nav = 'show_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif @user.set_password(params[:enable], params[:enable_confirmation], true, expire)
                if ( params.has_key?(:notify) )
                    begin
                        TacmanMailer.deliver_password_reset(@local_manager, @user, params[:enable], 'enable') if (!@user.email.blank?)
                    rescue Exception => error
                        @local_manager.log(:user_id=> @user.id, :message => "Failed to notify #{@user.username} of enable password reset - #{error}")
                    end
                end

                @local_manager.log(:username => @session_user.username, :user_id=> @user.id, :message => "Reset enable password for '#{@user.username}'.")
                flash[:notice] = "Change won't be effective on TACACS+ daemons until it is published."
                format.html { redirect_to user_url(@user) }
                format.xml  { head :ok }
            else
                format.html { render :action => "reset_enable" }
                format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
            end
        end
    end


    # PUT /users/1/update_reset_password
    # PUT /users/1.xml
    def update_reset_password
        @user = User.find(params[:id])

        respond_to do |format|
            expire = true
            expire = false if ( params.has_key?(:no_expire) )

            @nav = 'show_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to user_url(@user) }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif @user.set_password(params[:password],params[:password_confirmation], false, expire)
                if ( params.has_key?(:notify) )
                    begin
                        TacmanMailer.deliver_password_reset(@local_manager, @user, params[:enable], 'login') if (!@user.email.blank?)
                    rescue Exception => error
                        @local_manager.log(:user_id=> @user.id, :message => "Failed to notify #{@user.username} of login password reset - #{error}")
                    end
                end

                @local_manager.log(:username => @session_user.username, :user_id=> @user.id, :message => "Reset password for '#{@user.username}'.")
                flash[:notice] = "Change won't be effective on TACACS+ daemons until it is published."
                format.html { redirect_to user_url(@user) }
                format.xml  { head :ok }
            else
                format.html { render :action => "reset_password" }
                format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
            end
        end
    end

    def withdraw_join
        @user = User.find(params[:id])
        configuration = Configuration.find(params[:configuration])

        respond_to do |format|
            @nav = 'home_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to home_users_url }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            elsif (configuration)
                cu = ConfiguredUser.find(:first, :conditions => "user_id = #{@user.id} and configuration_id = #{configuration.id}")
                if (cu && !cu.denied?)
                    cu.destroy
                    @local_manager.log(:username => @session_user.username, :configuration_id => configuration.id, :user_id=> @session_user.id, :message => "Withdrew membership request from Configuration '#{configuration.name}'.")
                    flash[:notice] = "Membership withdrawn."
                end
                format.html { redirect_to home_users_url() }
                format.xml  { head :ok }
            else
                @user.errors.add_to_base("Unknown Configuration #{configuration.id}.")
                format.html { render :action => :home }
                format.xml  { render :xml => @user.errors, :status => :not_acceptable }
            end
        end
    end

end
