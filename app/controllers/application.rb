# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  #protect_from_forgery  :secret => '373e3fb38f737f6462930e56f608ae88'


private

    def authorize_admin()
        if (!@session_user.admin?)
            flash[:warning] = "Authorization failed. This attempt has been logged."
            @local_manager.log(:username => @session_user.username, :level => 'warn',
                              :message => "Non Admin attempted access to #{request.request_uri} from #{@remote_addr}")
            respond_to do |format|
                format.html { redirect_to(home_users_url)  }
                format.xml do
                    @session_user.errors.add_to_base("Authorization failed. This attempt has been logged.")
                    render :xml => @session_user.errors, :status => :forbidden
                end
            end
        end
    end

    def authorize_user_admin()
        if (!@session_user.user_admin? && !@session_user.admin?)
            flash[:warning] = "Authorization failed. This attempt has been logged."
            @local_manager.log(:username => @session_user.username, :level => 'warn',
                               :message => "Non Admin attempted access to #{request.request_uri} from #{@remote_addr}")
            respond_to do |format|
                format.html { redirect_to(home_users_url)  }
                format.xml do
                    @session_user.errors.add_to_base("Authorization failed. This attempt has been logged.")
                    render :xml => @session_user.errors, :status => :forbidden
                end
            end
        end
    end

    def define_session_user()
        get_remote_addr()
        @session_user = User.find_by_id(session[:user_id])
        @local_manager = Manager.local
        if (@session_user)
            @configuration_roles = {}
            @session_user.configured_users.each {|cu| @configuration_roles[cu.configuration_id] = cu.role if (!cu.suspended?)}
        else
            session[:original_uri] = request.request_uri
            flash[:warning] = "Login required."
            respond_to do |format|
                format.html { redirect_to(login_users_url)  }
                format.xml do
                    @session_user.errors.add_to_base("Login required.")
                    render :xml => @session_user.errors, :status => :forbidden
                end
            end
        end
    end

    def force_pw_change()
        if (@session_user.login_password_expired?)
            flash[:warning] = "Login password change required."
            respond_to do |format|
                format.html { redirect_to(change_password_users_url)  }
            end
        elsif (@session_user.enable_password_expired?)
            flash[:warning] = "Enable password change required."
            respond_to do |format|
                format.html { redirect_to(change_enable_users_url)  }
            end
        end
    end

    def get_remote_addr()
        if ( !request.env['HTTP_X_FORWARDED_FOR'].blank? )
            @remote_addr = request.env['HTTP_X_FORWARDED_FOR']
        else
            @remote_addr = request.env['REMOTE_ADDR']
        end
    end

end


