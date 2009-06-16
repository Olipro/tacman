class TacacsDaemonsController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize_admin
    before_filter :force_pw_change

    def aaa_log
        @tacacs_daemon = TacacsDaemon.find(params[:id])
        respond_to do |format|
            format.html {@nav = 'show_nav'}
        end
    end

    def bulk_create
        respond_to do |format|
            @nav = 'index_nav'
            format.html
        end
    end

    def changelog
        @tacacs_daemon = TacacsDaemon.find(params[:id])
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
            @nav = 'show_nav'
            format.html {render :template => 'managers/system_logs'}
        end
    end

    def clear_error_log
        @tacacs_daemon = TacacsDaemon.find(params[:id])
        respond_to do |format|
            @nav = 'show_nav'

            if (@tacacs_daemon.clear_error_log!)
                format.html {redirect_to error_log_tacacs_daemon_url(@tacacs_daemon)}
            else
                format.html {render :action => 'error_log'}
            end
        end

    end

    def create
        @tacacs_daemon = TacacsDaemon.new(params[:tacacs_daemon])
        @tacacs_daemon.manager_id = params[:tacacs_daemon][:manager_id]

        respond_to do |format|
            @nav = 'index_nav'
            if (@local_manager.slave?)
                @tacacs_daemon.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "new" }
                format.xml  { render :xml => @tacacs_daemon.errors, :status => :not_acceptable }
            elsif @tacacs_daemon.save
                @local_manager.log(:username => @session_user.username, :tacacs_daemon_id => @tacacs_daemon.id, :message => "Created Tacacs Daemon #{@tacacs_daemon.name}.")
                format.html { redirect_to tacacs_daemon_url(@tacacs_daemon) }
                format.xml  { render :xml => @tacacs_daemon, :status => :created, :location => @tacacs_daemon }
            else
                format.html { render :action => "new" }
                format.xml  { render :xml => @tacacs_daemon.errors, :status => :unprocessable_entity }
            end
        end
    end


    def destroy
        @tacacs_daemon = TacacsDaemon.find(params[:id])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @tacacs_daemon.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @tacacs_daemon.errors, :status => :not_acceptable }
            else
                @tacacs_daemon.destroy
                @local_manager.log(:username => @session_user.username, :message => "Deleted Tacacs Daemon #{@tacacs_daemon.name}.")
                format.html { redirect_to(tacacs_daemons_url) }
                format.xml  { head :ok }
            end
        end
    end

    def do_migrate
        @tacacs_daemon = TacacsDaemon.find(params[:id])
        manager = Manager.find(params[:manager_id])
        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @tacacs_daemon.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "migrate" }
                format.xml  { render :xml => @tacacs_daemon.errors, :status => :not_acceptable }
            elsif (@tacacs_daemon.migrate(manager) )
                @local_manager.log(:username => @session_user.username, :tacacs_daemon_id => @tacacs_daemon.id,
                                   :message => "Migrated #{@tacacs_daemon.name} to #{manager.name}.")

                format.html { redirect_to tacacs_daemon_url(@tacacs_daemon) }
                format.xml  { head :ok }
            else
                format.html { render :action => "migrate" }
                format.xml  { render :xml => @tacacs_daemon.errors, :status => :unprocessable_entity }
            end
        end
    end

    def edit
        @tacacs_daemon = TacacsDaemon.find(params[:id])
        @nav = 'show_nav'
    end

    def error_log
        @tacacs_daemon = TacacsDaemon.find(params[:id])
        respond_to do |format|
            format.html {@nav = 'show_nav'}
        end
    end

    def graphs
        @tacacs_daemon = TacacsDaemon.find(params[:id])
        @tacacs_daemon.generate_graphs! if (@tacacs_daemon.local?)
        respond_to do |format|
            format.html {@nav = 'show_nav'}
        end
    end

    def import
        @data = params[:data]
        respond_to do |format|
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to bulk_create_tacacs_daemons_url }
                format.xml  { render :xml => '<errors><error>This action is prohibited on slave systems.</error></errors>', :status => :not_acceptable }
            else
                @nav = 'index_nav'
                errors = TacacsDaemon.import(@data)
                if (errors.length == 0)
                    @local_manager.log(:username=> @session_user.username, :message => "Bulk created new TACACS+ daemons.")
                    format.html {redirect_to tacacs_daemons_url}
                    format.xml{head :ok}
                else
                    @import_errors = errors
                    format.html {render :action => :bulk_create}
                    format.xml{render :xml => @import_errors.to_xml}
                end
            end
        end
    end

    def index
        @tacacs_daemons = TacacsDaemon.find(:all, :order => :name)
        @managers = Manager.find(:all, :order => :name)
        respond_to do |format|
            @nav = 'index_nav'
            format.html # index.html.erb
            format.xml  { render :xml => @tacacs_daemons.to_xml }
        end
    end

    def migrate
        @tacacs_daemon = TacacsDaemon.find(params[:id])
        @nav = 'show_nav'
    end

    def new
        @tacacs_daemon = TacacsDaemon.new()

        respond_to do |format|
            @nav = 'index_nav'
            format.html # new.html.erb
            format.xml  { render :xml => @tacacs_daemon }
        end
    end


    def show
        @tacacs_daemon = TacacsDaemon.find(params[:id])
        respond_to do |format|
            @nav = 'show_nav'
            format.html # show.html.erb
            format.xml  { render :xml => @tacacs_daemon }
        end
    end

    def start_stop_selected
        respond_to do |format|
            @nav = 'index_nav'
            if ( params.has_key?(:selected) )
                cmd = params[:command]
                cmd = 'read' if ( cmd != 'reload' && cmd != 'restart' && cmd != 'start' && cmd != 'stop' )
                op_on = []
                ids = params[:selected].keys
                tds = []
                excluded = []
                TacacsDaemon.find(:all, :order => :name).each do |td|
                    if ( ids.include?(td.id.to_s) )
                        tds.push(td)
                        op_on.push(td)
                    else
                        excluded.push(td)
                    end
                end

                if (cmd != 'read')
                    op_on.each do |td|
                        @local_manager.log(:username => @session_user.username, :configuration_id => td.configuration_id, :tacacs_daemon_id => td.id, :message => "Issued command '#{cmd}' on daemon #{td.name}.")
                    end
                end

                start_stop = Manager.start_stop_tacacs_daemons(tds,cmd)
                @managers = start_stop[:managers]
                @tacacs_daemons = start_stop[:tacacs_daemons]
                @tacacs_daemons.concat(excluded)
                format.html {render :action => :index}
                format.xml  { head :ok }
            else
                format.html {redirect_to tacacs_daemons_url}
                format.xml  { head :ok }
            end
        end
    end

    def update
        @tacacs_daemon = TacacsDaemon.find(params[:id])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @tacacs_daemon.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "edit" }
                format.xml  { render :xml => @tacacs_daemon.errors, :status => :not_acceptable }
            elsif @tacacs_daemon.update_attributes(params[:tacacs_daemon])
                @local_manager.log(:username => @session_user.username, :tacacs_daemon_id => @tacacs_daemon.id,
                                   :message => "Updated Tacacs Daemon #{@tacacs_daemon.name}.")

                format.html { redirect_to tacacs_daemon_url(@tacacs_daemon) }
                format.xml  { head :ok }
            else
                format.html { render :action => "edit" }
                format.xml  { render :xml => @tacacs_daemon.errors, :status => :unprocessable_entity }
            end
        end
    end

end
