class AuthorAvpairEntriesController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change

    def create_dynamic_avpair
        @dynamic_avpair = @author_avpair_entry.dynamic_avpairs.build(params[:dynamic_avpair])
        object_groups = params[:object_groups]

        respond_to do |format|
            @nav = 'dynamic_avpair_nav'
            if (@local_manager.slave?)
                @dynamic_avpair.errors.add_to_base("This action is prohibited on slave systems.")
                format.html {
                    if (@dynamic_avpair.obj_type == 'network_av')
                        render :action => "new_network_av"
                    else
                        render :action => "new_shell_command_av"
                    end
                }
                format.xml  { render :xml => @dynamic_avpair.errors, :status => :not_acceptable }
            else
                begin
                    DynamicAvpair.transaction do
                        @dynamic_avpair.save!
                        @dynamic_avpair.errors.add_to_base("no values have been specified")
                        object_groups.keys.each do |x|
                            if (@dynamic_avpair.obj_type == 'network_av')
                                @dynamic_avpair.dynamic_avpair_values.create(:network_object_group_id => x)
                            else
                                @dynamic_avpair.dynamic_avpair_values.create(:shell_command_object_group_id => x)
                            end
                        end
                    end
                rescue
                    format.html {
                        if (@dynamic_avpair.obj_type == 'network_av')
                            @title = 'network-av'
                            render :template => 'author_avpair_entries/new_dynamic_avpair'
                        else
                            @title = 'shell-command-av'
                            render :template => 'author_avpair_entries/new_dynamic_avpair'
                        end
                    }
                    format.xml  { render :xml => @dynamic_avpair.errors, :status => :unprocessable_entity }
                end

                @local_manager.log(:username => @session_user.username, :configuration_id => @author_avpair.configuration_id, :author_avpair_id => @author_avpair.id, :message => "Defined #{@dynamic_avpair.obj_type} from entry #{@author_avpair_entry.sequence} of Author AVPair #{@author_avpair.name} within configuration #{@configuration.name}.")
                format.html { redirect_to edit_author_avpair_entry_url(@author_avpair_entry) }
                format.xml  { render :xml => @dynamic_avpair, :status => :created, :location => @dynamic_avpair }
            end
        end
    end

    def destroy
        respond_to do |format|
            @nav = 'author_avpairs/show_nav'
            if (@local_manager.slave?)
                @author_avpair.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render author_avpairs_configuration_url(@author_avpair.configuration) }
                format.xml  { render :xml => @author_avpair.errors, :status => :not_acceptable }
            elsif (@author_avpair_entry.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @author_avpair.configuration_id, :author_avpair_id => @author_avpair.id, :message => "Deleted entry #{@author_avpair_entry.sequence} of Author AVPair #{@author_avpair.name} within configuration #{@configuration.name}.")
                format.html { redirect_to author_avpair_url(@author_avpair) }
                format.xml  { head :ok }
            else
                format.html { render author_avpairs_configuration_url(@author_avpair.configuration) }
                format.xml  { head :ok }
            end
        end
    end

    def edit
        respond_to do |format|
            format.html {@nav = 'author_avpairs/show_nav'}
        end
    end

    def new_network_av
        @author_avpair_entry = AuthorAvpairEntry.find(params[:id])
        @dynamic_avpair = @author_avpair_entry.dynamic_avpairs.build(:obj_type => 'network_av')
        respond_to do |format|
            format.html {
                @nav = 'dynamic_avpair_nav'
                @title = "network-av"
                render :template => 'author_avpair_entries/new_dynamic_avpair'
            }
        end
    end

    def new_shell_command_av
        @author_avpair_entry = AuthorAvpairEntry.find(params[:id])
        @dynamic_avpair = @author_avpair_entry.dynamic_avpairs.build(:obj_type => 'shell_command_av')
        respond_to do |format|
            format.html {
                @nav = 'dynamic_avpair_nav'
                @title = "shell-command-av"
                render :template => 'author_avpair_entries/new_dynamic_avpair'
            }
        end
    end

    def update
        avpairs = params[:avpairs]

        respond_to do |format|
            @nav = 'author_avpairs/show_nav'
            if (@local_manager.slave?)
                @author_avpair.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "edit" }
                format.xml  { render :xml => @author_avpair.errors, :status => :not_acceptable }
            end

            begin
                AuthorAvpairEntry.transaction do
                    @author_avpair_entry.update_attributes(params[:author_avpair_entry])
                    avpairs.each_pair do |attr,val|
                        next if (val.blank?)
                        avpair = nil
                        if (attr =~ /^custom/)
                            avpair = val
                        else
                            avpair = attr + '=' + val
                        end
                        @author_avpair_entry.avpairs.create!(:avpair => avpair)
                    end
                end
                raise if (@author_avpair_entry.errors.length > 0)
                @local_manager.log(:username => @session_user.username, :configuration_id => @author_avpair.configuration_id, :author_avpair_id => @author_avpair.id, :message => "Updated entry #{@author_avpair_entry.sequence} of Author AVPair #{@author_avpair.name} within configuration #{@configuration.name}.")
                format.html { redirect_to author_avpair_url(@author_avpair) }
                format.xml  { render :xml => @author_avpair_entry.to_xml }

            rescue Exception => error
                @author_avpair_entry.errors.add_to_base(error)
                format.html { render :action => "edit" }
                format.xml  { render :xml => @author_avpair_entry.errors, :status => :unprocessable_entity }
            end
        end
    end

private

    def authorize
        @author_avpair_entry = AuthorAvpairEntry.find(params[:id])
        @author_avpair = @author_avpair_entry.author_avpair
        @configuration = @author_avpair.configuration
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
