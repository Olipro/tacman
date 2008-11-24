class AaaReportsController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change

    def destroy
        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @aaa_report.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @aaa_report.errors, :status => :not_acceptable }
            elsif (@aaa_report.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :message => "Deleted report #{@aaa_report.name} from configuration #{@configuration.name}.")
                format.html { redirect_to aaa_reports_configuration_url(@configuration) }
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
        @aaa_report = AaaReport.find(params[:id])
        @aaa_report.set_start_time
        respond_to do |format|
            @nav = 'show_nav'
            format.html
            format.xml  { render :xml => @aaa_report }
        end
    end

    def summary
        @aaa_report = AaaReport.find(params[:id])
        respond_to do |format|
            @nav = 'show_nav'
            format.html
        end
    end

    def update
        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @aaa_report.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "edit" }
                format.xml  { render :xml => @aaa_report.errors, :status => :not_acceptable }
            elsif @aaa_report.update_attributes(params[:aaa_report])
                @local_manager.log(:username => @session_user.username, :configuration_id => @aaa_report.configuration_id, :message => "Updated report #{@aaa_report.name} within configuration #{@configuration.name}.")
                format.html { redirect_to aaa_report_url(@aaa_report) }
                format.xml  { head :ok }
            else
                format.html { render :action => "edit" }
                format.xml  { render :xml => @aaa_report.errors, :status => :unprocessable_entity }
            end
        end
    end

private

    def authorize
        @aaa_report = AaaReport.find(params[:id])
        @configuration = @aaa_report.configuration
        if (!@session_user.admin?)
            if ( !@configuration_roles.has_key?(@aaa_report.configuration_id) || @configuration_roles[@aaa_report.configuration_id] != 'admin' ) # deny if not owned by my config
                flash[:warning] = "Authorization failed. This attempt has been logged."
                @local_manager.log(:level => 'warn', :user_id => @session_user.id,
                                   :username => @session_user.username,
                                   :message => "Unauthorized access attempted to access-list #{@aaa_report.name}.")
                respond_to do |format|
                    format.html {redirect_to home_users_url}
                    format.xml {render :xml => "<errors><error>Authorization failed. This attempt has been logged.</error></errors>", :status => :forbidden}
                end
            end
        end
    end


end



