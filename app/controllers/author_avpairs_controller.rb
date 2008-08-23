class AuthorAvpairsController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change

    def changelog
        @log_count = SystemLog.count_by_sql("SELECT COUNT(*) FROM system_logs WHERE author_avpair_id=#{@author_avpair.id}")
        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = SystemLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                   :conditions => "author_avpair_id=#{@author_avpair.id}", :order => :created_at)
        respond_to do |format|
            @nav = 'show_nav'
            format.html {render :template => 'managers/system_logs'}
        end
    end

    def create_entry
        @configuration = @author_avpair.configuration
        @author_avpair_entry = @author_avpair.author_avpair_entries.build(params[:author_avpair_entry])
        avpairs = params[:avpairs]

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @author_avpair.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @author_avpair.errors, :status => :not_acceptable }
            end

            begin
                AuthorAvpairEntry.transaction do
                    @author_avpair_entry.save!
                    avpairs.each_pair do |attr,val|
                        next if (val.blank?)
                        avpair = nil
                        if (attr == 'custom')
                            avpair = val
                        else
                            avpair = attr + '=' + val
                        end
                        @author_avpair_entry.avpairs.create!(:avpair => avpair)
                    end
                end
                @local_manager.log(:username => @session_user.username, :configuration_id => @author_avpair.configuration_id, :author_avpair_id => @author_avpair.id, :message => "Created entry #{@author_avpair_entry.sequence} of Author AVPair #{@author_avpair.name} within configuration #{@configuration.name}.")
                format.html { redirect_to author_avpair_url(@author_avpair) }
                format.xml  { render :xml => @author_avpair_entry.to_xml }

            rescue Exception => error
                @author_avpair_entry.errors.add_to_base(error)
                @author_avpair.reload
                format.html { render :action => "show" }
                format.xml  { render :xml => @author_avpair_entry.errors, :status => :unprocessable_entity }
            end
        end
    end

    def destroy
        @configuration = @author_avpair.configuration

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @author_avpair.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @author_avpair.errors, :status => :not_acceptable }
            elsif (@author_avpair.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @configuration.id, :message => "Deleted Author AVPair #{@author_avpair.name} from configuration #{@configuration.name}.")
                format.html { redirect_to author_avpairs_configuration_url(@configuration) }
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
        @configuration = @author_avpair.configuration
        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @author_avpair.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "show" }
                format.xml  { render :xml => @author_avpair.errors, :status => :not_acceptable }
            elsif (@author_avpair.resequence!)
                @local_manager.log(:username => @session_user.username, :configuration_id => @author_avpair.configuration_id, :author_avpair_id => @author_avpair.id, :message => "Resequenced Network Object Group #{@author_avpair.name} within configuration #{@configuration.name}.")
                format.html { redirect_to author_avpair_url(@author_avpair) }
                format.xml  { head :ok }
            else
                format.html { render :action => "show" }
                format.xml  { render :xml => @author_avpair.errors, :status => :unprocessable_entity }
            end
        end
    end

    def show
        respond_to do |format|
            @nav = 'show_nav'
            format.html # show.html.erb
            format.xml  { render :xml => @author_avpair }
        end
    end


    def update
        @configuration = @author_avpair.configuration
        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                @author_avpair.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "edit" }
                format.xml  { render :xml => @author_avpair.errors, :status => :not_acceptable }
            elsif @author_avpair.update_attributes(params[:author_avpair])
                @local_manager.log(:username => @session_user.username, :configuration_id => @author_avpair.configuration_id, :author_avpair_id => @author_avpair.id, :message => "Renamed Author AVPair #{@author_avpair.name} within configuration #{@configuration.name}.")
                format.html { redirect_to author_avpair_url(@author_avpair) }
                format.xml  { head :ok }
            else
                format.html { render :action => "edit" }
                format.xml  { render :xml => @author_avpair.errors, :status => :unprocessable_entity }
            end
        end
    end

private

    def authorize
        @author_avpair = AuthorAvpair.find(params[:id])
        if (!@session_user.admin?)
            if ( !@configuration_roles.has_key?(@author_avpair.configuration_id) || @configuration_roles[@author_avpair.configuration_id] != 'admin' ) # deny if not owned by my config
                flash[:warning] = "Authorization failed. This attempt has been logged."
                @local_manager.log(:level => 'warn', :user_id => @session_user.id,
                                   :username => @session_user.username, :author_avpair_id => @author_avpair.id,
                                   :message => "Unauthorized access attempted to author-avpair-list #{@author_avpair.name}.")
                respond_to do |format|
                    format.html {redirect_to home_users_url}
                    format.xml {render :xml => "<errors><error>Authorization failed. This attempt has been logged.</error></errors>", :status => :forbidden}
                end
            end
        end
    end


end
