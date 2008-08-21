class ManagersController < ApplicationController
    before_filter :define_session_user, :except => [:register, :resync, :read_log_file, :tacacs_daemon_control, :write_to_inbox]
    before_filter :authorize_admin, :except => [:register, :resync, :read_log_file, :tacacs_daemon_control, :write_to_inbox]
    before_filter :force_pw_change, :except => [:register, :resync, :read_log_file, :tacacs_daemon_control, :write_to_inbox]

    filter_parameter_logging :password


    def approve
        @manager = Manager.find(params[:id])

        respond_to do |format|
            @nav = "remote_nav"
            if (!@local_manager.master?)
                @manager.errors.add_to_base("This action is only allowed on master systems.")
                format.html { render :action => :show }
                format.xml  { render :xml => @manager.errors, :status => :not_acceptable }
            elsif (@manager.approve!)
                flash[:notice] = "#{@manager.name} has been approved."
                @local_manager.log(:username => @session_user.username, :manager_id=> @manager.id, :message => "Approved Manager #{@manager.name}")
                format.html { redirect_to manager_url(@manager) }
                format.xml  { head :ok }
            else
                format.html { render :action => :show }
                format.xml  { render :xml => @manager.errors, :status => :not_acceptable }
            end
        end
    end

    # used to start/stop/read backgroundrb
    def backgroundrb
        respond_to do |format|
            @nav = 'local_nav'
            cmd = params[:command]
            cmd = nil if ( cmd != 'start' && cmd != 'stop' && cmd != 'restart' )
            @status = Manager.backgroundrb_control(cmd)
            @manager = Manager.local
            format.html {render :action => :backgroundrb}
            format.xml  { render :xml => "<backgroundrb><status>#{@status[:status]}</status><message>#{@status[:message]}</message></backgroundrb>" }
        end
    end

    def changelog
        @manager = Manager.find(params[:id])
        @log_count = SystemLog.count_by_sql("SELECT COUNT(*) FROM system_logs WHERE manager_id=#{@manager.id}")
        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = SystemLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                   :conditions => "manager_id=#{@manager.id}", :order => :created_at)
        respond_to do |format|
            if (@manager.is_local)
                @nav = "local_nav"
            else
                @nav = "remote_nav"
            end
            format.html {render :template => 'managers/system_logs'}
        end
    end

    def destroy
        @manager = Manager.find(params[:id])
        respond_to do |format|
            @nav = "remote_nav"
            if (@manager.destroy)
                @local_manager.log(:username => @session_user.username, :message => "Deleted Manager #{@manager.name}")
                if (@manager.master?)
                    format.html { redirect_to( show_master_managers_url) }
                else
                    format.html { redirect_to( managers_url) }
                end
                format.xml  { head :ok }
            else
                format.html { render :action => :local }
                format.xml  { render :xml => @manager.errors, :status => :not_acceptable }
            end
        end
    end

    def disable
        @manager = Manager.find(params[:id])

        respond_to do |format|
            @nav = "remote_nav"
            msg = "#{@session_user.username} disabled messaging for Manager #{@manager.name}"
            if (@manager.disable!(msg))
                flash[:notice] = "#{@manager.name} has been disabled."
                @local_manager.log(:username => @session_user.username, :manager_id=> @manager.id, :message => msg)
                format.html { redirect_to manager_url(@manager) }
                format.xml  { head :ok }
            else
                format.html { render :action => :show }
                format.xml  { render :xml => @manager.errors, :status => :not_acceptable }
            end
        end
    end

    def download_archived_log
        arch = SystemLogArchive.find(params[:system_log_archive_id])
        if ( File.exists?(arch.archive_file) )
            send_file(arch.archive_file)
        else
            flash[:warning] = "Selected archive '#{File.basename(arch.archive_file)}' is empty."
            redirect_to system_log_archives_managers_url()
        end

    end

    def edit
        @manager = Manager.find(params[:id])
        if (@manager.is_local)
            @nav = "local_nav"
        else
            @nav = "remote_nav"
        end
    end

    def enable
        @manager = Manager.find(params[:id])

        respond_to do |format|
            @nav = "remote_nav"
            msg = "#{@session_user.username} enabled messaging for Manager #{@manager.name}"
            if (@manager.enable!)
                flash[:notice] = msg
                @local_manager.log(:username => @session_user.username, :manager_id=> @manager.id, :message => msg)
                format.html { redirect_to manager_url(@manager) }
                format.xml  { head :ok }
            else
                format.html { render :action => :show }
                format.xml  { render :xml => @manager.errors, :status => :not_acceptable }
            end
        end
    end

    def inbox
        @manager = Manager.find(params[:id])
        @msg_count = @manager.system_messages.count(:conditions => "queue = 'inbox'")
        @inbox = SystemMessage.paginate(:page => params[:page], :per_page => 10,
                                        :conditions => "manager_id = #{@manager.id} and queue = 'inbox'", :order => :id)

        respond_to do |format|
            @nav = "remote_nav"
            format.html # inbox.html.erb
            format.xml {render :xml => @manager.inbox.to_xml}
        end
    end

    def index
        @managers = Manager.non_local

        respond_to do |format|
            @nav = 'index_nav'
            format.html
            format.xml
        end
    end

    def local
        @manager = Manager.local
        respond_to do |format|
            if ( @manager.errors.length == 0 )
            @nav = 'local_nav'
            format.html
            format.xml {render :xml => @manager.to_xml(:except => :id)}
            end
        end
    end

    def local_logs
        @manager = @local_manager
        @log_count = SystemLog.count
        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = SystemLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                   :order => :created_at)
        @managers = {@manager.id => @manager}
        Manager.non_local.each {|m| @managers[m.id] = m}

        respond_to do |format|
            @nav = 'local_nav'
            format.html {render :template => 'managers/system_logs'}
        end
    end

    def log_search_form
        @manager = Manager.find(params[:id])
        respond_to do |format|
            if (@manager.is_local)
                @nav = 'local_nav'
            else
                @nav = "remote_nav"
            end
            format.html
        end
    end

    def master
        @manager = @local_manager
        @manager.base_url = managers_url()
        respond_to do |format|
            @nav = "local_nav"
            if (@manager.master!)
                @local_manager.log(:level => 'warn', :username => @session_user.username, :manager_id=> @manager.id, :message => "Changed system to master.")
                format.html {redirect_to local_managers_url}
                format.xml  { head :ok }
            else
                format.html {render :action => :local}
                format.xml  { render :xml => @manager.errors, :status => :not_acceptable }
            end
        end
    end

    def outbox
        @manager = Manager.find(params[:id])
        @msg_count = @manager.system_messages.count(:conditions => "queue = 'outbox'")
        @outbox = SystemMessage.paginate(:page => params[:page], :per_page => 10,
                                         :conditions => "manager_id = #{@manager.id} and queue = 'outbox'", :order => :id)

        respond_to do |format|
            @nav = "remote_nav"
            format.html
            format.xml {render :xml => @manager.outbox.to_xml}
        end
    end

    def process_inbox
        @manager = Manager.find(params[:id])
        if (@manager.queue_worker_inbox!)
            flash[:notice] = "This may take a few moments to process. Please wait."
        else
            flash[:warning] = "BackgrounDRb error. Request could not be completed."
        end

        respond_to do |format|
            @nav = "remote_nav"
            format.html { redirect_to inbox_manager_url(@manager) }
            format.xml  { head :ok }
        end
    end

    # used by remote manager to real tacacs daemon log files
    def read_log_file
        get_remote_addr()
        respond_to do |format|
            begin
                serial = params[:serial]
                pw = params[:password]
                if (serial && pw)
                    manager = Manager.find_by_serial(serial)
                    if ( manager && manager.authenticate(pw) )
                        tacacs_daemon = TacacsDaemon.find(params[:tacacs_daemon])
                        if (params[:log] == 'error')
                            log = tacacs_daemon.error_log
                        elsif (params[:log] == 'aaa')
                            log = tacacs_daemon.aaa_log
                        else
                            log = ''
                        end

                        if (tacacs_daemon.errors.length != 0)
                            format.xml  { render :xml => tacacs_daemon.errors.to_xml, :status => :not_acceptable }
                        else
                            format.xml  { render :xml => "<log>#{log}</log>" }
                        end
                    else
                        Manager.local.log(:level => 'warn', :message => "Authentication failed for #{serial} from #{@remote_addr}.")
                        manager = Manager.new if (!manager)
                        manager.errors.add_to_base("Authentication failed for Manager #{serial}.")
                        format.xml  { render :xml => manager.errors.to_xml, :status => :forbidden }
                    end
                else
                    format.xml  { render :xml => "<errors><error>XML document must contain a valid Manager serial and password.</error></errors>", :status => :not_acceptable }
                end

            rescue Exception => error
                format.xml  { render :xml => "<errors><error>Error processing input for Manager: #{error}</error></errors>", :status => :not_acceptable }
            end
        end
    end


    def register
        get_remote_addr()

        if ( params.has_key?(:manager) && params[:manager].has_key?(:base_url) )
            master = Manager.register( params[:manager][:base_url], @remote_addr )
        else
            master = Manager.new
            master.errors.add_to_base("'manager' was not part of the provided parameters")
        end

        respond_to do |format|
            if ( master.errors.length == 0 )
                format.xml  { render :xml => master.to_xml(:only => [:serial, :name, :is_approved, :is_local, :manager_type, :base_url, :password]),
                                     :status => :accepted}
            else
                Manager.local.log(:level => 'warn', :message => "Failed remote system registration from #{@remote_addr}")
                format.xml  { render :xml => master.errors, :status => :not_acceptable }
            end
        end
    end

    def request_registration
        respond_to do |format|
            @nav = "remote_nav"
            @manager = Manager.request_registration( params[:manager][:base_url].strip )
            if (@manager.errors.length == 0)
                @local_manager.log(:username => @session_user.username, :manager_id=> @manager.id, :message => "Registered with master system at #{@manager.base_url}")
                format.html { redirect_to manager_url(@manager) }
                format.xml  { head :ok }
            else
                format.html { render :action => "show_master" }
                format.xml  { render :xml => @manager.errors, :status => :unprocessable_entity }
            end
        end
    end

    def resync
        get_remote_addr()
        respond_to do |format|
            begin
                serial = params[:serial]
                pw = params[:password]
                if (serial && pw)
                    manager = Manager.find_by_serial(serial)
                    if ( manager && manager.authenticate(pw) )
                        manager.send_system_sync!
                        format.xml  { head :ok }
                    else
                        Manager.local.log(:level => 'warn', :message => "Authentication failed for #{serial} from #{@remote_addr}.")
                        manager = Manager.new if (!manager)
                        manager.errors.add_to_base("Authentication failed for Manager #{serial}.")
                        format.xml  { render :xml => manager.errors.to_xml, :status => :forbidden }
                    end
                else
                    format.xml  { render :xml => "<errors><error>XML document must contain a valid Manager serial and password.</error></errors>", :status => :not_acceptable }
                end

            rescue Exception => error
                format.xml  { render :xml => "<errors><error>Error processing input for Manager: #{error}</error></errors>", :status => :not_acceptable }
            end
        end
    end

    def search_logs
        @manager = Manager.find(params[:id])
        @search_opts = {}
        criteria = []
        criteria_vals = []

        if (!params[:search_criteria][:start_time].blank?)
            criteria.push("created_at >= ?")
            criteria_vals.push(params[:search_criteria][:start_time])
            @search_opts['search_criteria[start_time]'] = params[:search_criteria][:start_time]
        end

        if (!params[:search_criteria][:end_time].blank?)
            criteria.push("created_at <= ?")
            criteria_vals.push(params[:search_criteria][:end_time])
            @search_opts['search_criteria[end_time]'] = params[:search_criteria][:end_time]
        end

        if (!params[:search_criteria][:message].blank?)
            criteria.push("message regexp ?")
            criteria_vals.push(params[:search_criteria][:message])
            @search_opts['search_criteria[message]'] = params[:search_criteria][:message]
        end

        if (!params[:search_criteria][:username].blank?)
            criteria.push("username regexp ?")
            criteria_vals.push(params[:search_criteria][:username])
            @search_opts['search_criteria[username]'] = params[:search_criteria][:username]
        end

        respond_to do |format|
            if (@manager.is_local)
                @nav = 'local_nav'
                @managers = {@manager.id => @manager}
                Manager.non_local.each {|m| @managers[m.id] = m}
            else
                @nav = "remote_nav"
            end

            if (criteria.length != 0)
                if (!@manager.is_local)
                    criteria.push("owning_manager_id = ?")
                    criteria_vals.push(@manager.id)
                end
                conditions = criteria.join(" and ")
                @log_count = SystemLog.count_by_sql( ["SELECT COUNT(*) FROM system_logs WHERE #{conditions}"].concat(criteria_vals) )

                if ( params.has_key?(:page) )
                    page = params[:page]
                elsif (@log_count > 0)
                    page = @log_count / @local_manager.pagination_per_page
                    page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
                end
                @logs = SystemLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                           :conditions => [conditions].concat(criteria_vals), :order => :created_at)
                format.html { render :action => :system_logs}
            else
                if (@manager.is_local)
                    format.html { redirect_to local_logs_managers_url }
                else
                    format.html { redirect_to system_logs_manager_url(@manager) }
                end
            end
        end
    end


    def show
        @manager = Manager.find(params[:id])

        respond_to do |format|
            @nav = "remote_nav"
            format.html 
            format.xml  {render :xml => @manager.to_xml}
        end
    end

    def show_master
        @manager = Manager.find_by_manager_type('master')

        respond_to do |format|
            @nav = "remote_nav"
            format.html
            format.xml  {render :xml => @manager.to_xml}
        end
    end

    def slave
        @manager = @local_manager
        @manager.base_url = managers_url()
        respond_to do |format|
            @nav = "local_nav"
            if (@manager.slave!)
                @local_manager.log(:level => 'warn', :username => @session_user.username, :manager_id=> @manager.id, :message => "Changed system to slave.")
                format.html {redirect_to local_managers_url}
                format.xml  { head :ok }
            else
                format.html {render :action => :local}
                format.xml  { render :xml => @manager.errors, :status => :not_acceptable }
            end
        end
    end

    def stand_alone
        @manager = @local_manager
        @manager.base_url = nil
        respond_to do |format|
            @nav = "local_nav"
            if (@manager.stand_alone!)
                @local_manager.log(:level => 'warn', :username => @session_user.username, :manager_id=> @manager.id, :message => "Changed system to stand_alone.")
                format.html {redirect_to local_managers_url}
                format.xml  { head :ok }
            else
                format.html {render :action => :local}
                format.xml  { render :xml => @manager.errors, :status => :not_acceptable }
            end
        end
    end

    def system_export
        respond_to do |format|
            format.xml {render :xml => Manager.export(true)}
        end
    end

    def system_log_archives
        @manager = @local_manager
        @files = SystemLogArchive.paginate(:page => params[:page], :per_page => @local_manager.pagination_per_page,
                                           :order => 'archived_on desc')
        respond_to do |format|
            @nav = 'local_nav'
            format.html
        end
    end

    def system_logs
        @manager = Manager.find(params[:id])
        @log_count = @manager.logs.count
        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = SystemLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                   :conditions => "owning_manager_id = #{@manager.id}", :order => :created_at)
        respond_to do |format|
            @nav = 'remote_nav'
            format.html
        end
    end

    def system_sync
        @manager = Manager.find(params[:id])

        respond_to do |format|
            if @manager.send_system_sync!
                @nav = "remote_nav"
                flash[:notice] = "System synchronization requested."
                @local_manager.log(:level => 'warn', :username => @session_user.username, :manager_id=> @manager.id, :message => "Requested system synchronization for #{@manager.name}.")
                format.html { redirect_to outbox_manager_url(@manager)}
                format.xml  { head :ok }
            else
                format.html { render :action => "show" }
                format.xml  { render :xml => @manager.errors, :status => :unprocessable_entity }
            end
        end
    end

    # used by master system to start/stop/read tacacs_daemons
    def tacacs_daemon_control
        get_remote_addr()
        respond_to do |format|
            begin
                if ( params.has_key?(:serial) && params.has_key?(:password) )
                    manager = Manager.find_by_serial(params[:serial])
                    if ( manager && manager.authenticate(params[:password]) )
                        tds = TacacsDaemon.find(params[:ids].keys)
                        command = params[:command]
                        xml = "<tacacs-daemons type='array'>\n"
                        tds.each do |td|
                            if (command == 'start')
                                td.start
                                TacacsDaemon.update_all("desire_start = true", "id = #{td.id}") if (!td.desire_start)
                            elsif (command == 'stop')
                                td.stop
                                TacacsDaemon.update_all("desire_start = false", "id = #{td.id}") if (td.desire_start)
                            elsif (command == 'restart')
                                td.restart
                                TacacsDaemon.update_all("desire_start = true", "id = #{td.id}") if (!td.desire_start)
                            elsif (command == 'reload')
                                td.reload
                                TacacsDaemon.update_all("desire_start = true", "id = #{td.id}") if (!td.desire_start)
                            end

                            if (td.errors.length == 0)
                                xml << td.to_xml(:skip_instruct => true, :only => :id, :methods => [:status])
                            else
                                proc = Proc.new { |options| options[:builder].tag!('errors', td.errors.full_messages.join("\n") ) }
                                xml << td.to_xml(:skip_instruct => true, :only => :id, :methods => [:status], :procs => [proc])
                            end
                        end
                        xml << "</tacacs-daemons>\n"
                        format.xml {render :xml => xml}

                    else
                        Manager.local.log(:level => 'warn', :message => "Authentication failed for Manager (#{params[:serial]}) from #{@remote_addr}.")
                        format.xml  { render :xml => "<errors><error>Authentication failed for Manager #{params[:serial]}.</error></errors>", :status => :forbidden }
                    end
                else
                    format.xml  { render :xml => "<errors><error>Request must contain a valid Manager serial and password.</error></errors>", :status => :not_acceptable }
                end

            rescue Exception => error
                format.xml  { render :xml => "<errors><error>Error processing input for Manager: #{error}</error></errors>", :status => :not_acceptable }
            end
        end
    end

    def toggle_maintenance_mode
        respond_to do |format|
            @nav = 'local_nav'
            @local_manager.toggle_maintenance_mode!
            @local_manager.log(:username => @session_user.username, :message => "Toggled maintenance mode (current=#{@local_manager.in_maintenance_mode}).")
            CGI::Session::ActiveRecordStore::Session.delete_all("session_id != '#{session.session_id}'") if (@local_manager.in_maintenance_mode)
            format.html { redirect_to local_managers_url }
            format.xml  { head :ok }
        end
    end

    def unprocessable_messages
        @manager = Manager.find(params[:id])
        @msg_count = @manager.system_messages.count(:conditions => "queue = 'unprocessable'")
        @messages = SystemMessage.paginate(:page => params[:page], :per_page => 10,
                                           :conditions => "manager_id = #{@manager.id} and queue = 'unprocessable'", :order => :id)

        respond_to do |format|
            @nav = "remote_nav"
            format.html
            format.xml {render :xml => @manager.unprocessable_messages.to_xml}
        end
    end

    def update
        @manager = Manager.find(params[:id])
        # dont let serial be changed
        params[:manager].delete(:serial)

        respond_to do |format|
            if @manager.update_attributes(params[:manager])
                @local_manager.log(:username => @session_user.username, :manager_id=> @manager.id, :message => "Updated Manager #{@manager.name}")
                if (@manager.is_local)
                    @nav = "local_nav"
                    format.html { redirect_to local_managers_url} 
                else
                    @nav = "remote_nav"
                    format.html { redirect_to manager_url(@manager)} 
                end
                format.xml  { head :ok }
            else
                if (@manager.is_local)
                    @nav = "local_nav"
                else
                    @nav = "remote_nav"
                end
                format.html { render :action => "edit" }
                format.xml  { render :xml => @manager.errors, :status => :unprocessable_entity }
            end
        end
    end

    def write_outbox
        @manager = Manager.find(params[:id])
        if (@manager.queue_worker_outbox!)
            flash[:notice] = "This may take a few moments to process. Please wait."
        else
            flash[:warning] = "BackgrounDRb error. Request could not be completed."
        end

        respond_to do |format|
            @nav = "remote_nav"
            format.html { redirect_to outbox_manager_url(@manager) }
            format.xml  { head :ok }
        end
    end

    # used by remote manager to write into inbox on local system
    def write_to_inbox
        get_remote_addr()
        respond_to do |format|
            begin
                doc = REXML::Document.new(request.raw_post)
                creds = Manager.credentials_from_xml(doc)
                if (creds)
                    manager = Manager.find_by_serial(creds[0])
                    if ( manager && manager.authenticate(creds[1]) )
                        manager.add_to_inbox(doc)
                        if ( manager.errors.length == 0 )
                            format.xml  { head :ok }
                        else
                            Manager.local.log(:level => 'error', :manager_id=> manager.id, :message => "Inbox write failed for #{manager.name} from #{@remote_addr}: #{manager.errors.full_messages.join(',')}")
                            format.xml  { render :xml => manager.errors.to_xml, :status => :not_acceptable }
                        end
                    else
                        Manager.local.log(:level => 'warn', :message => "Authentication failed for #{creds[0]} from #{@remote_addr}.")
                        manager = Manager.new if (!manager)
                        manager.errors.add_to_base("Authentication failed for Manager #{creds[0]}.")
                        format.xml  { render :xml => manager.errors.to_xml, :status => :forbidden }
                    end
                else
                    format.xml  { render :xml => "<errors><error>XML document must contain a valid Manager serial and password.</error></errors>", :status => :not_acceptable }
                end

            rescue Exception => error
                format.xml  { render :xml => "<errors><error>Error processing input for Manager: #{error}</error></errors>", :status => :not_acceptable }
            end
        end

    end


end
