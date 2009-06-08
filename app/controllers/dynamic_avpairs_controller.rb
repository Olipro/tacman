class DynamicAvpairsController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change

    def destroy
        respond_to do |format|
            @nav = 'author_avpairs/show_nav'
            if (@local_manager.slave?)
                @dynamic_avpair.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render edit_author_avpair_entry_url(@author_avpair_entry) }
                format.xml  { render :xml => @dynamic_avpair.errors, :status => :not_acceptable }
            elsif (@dynamic_avpair.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @author_avpair.configuration_id, :author_avpair_id => @author_avpair.id, :message => "Deleted #{@dynamic_avpair.obj_type} from entry #{@author_avpair_entry.sequence} of Author AVPair #{@author_avpair.name} within configuration #{@configuration.name}.")
                format.html { redirect_to edit_author_avpair_entry_url(@author_avpair_entry) }
                format.xml  { head :ok }
            else
                format.html { render edit_author_avpair_entry_url(@author_avpair_entry) }
                format.xml  { head :ok }
            end
        end
    end

    def edit
        respond_to do |format|
            if (@dynamic_avpair.obj_type == 'network_av')
                @title = "network-av"
            else
                @title = "shell-command-av"
            end
            format.html {@nav = 'author_avpair_entries/dynamic_avpair_nav'}
        end
    end

    def update
        @dynamic_avpair = DynamicAvpair.find(params[:id])
        respond_to do |format|
            @nav = 'author_avpair_entries/dynamic_avpair_nav'
            if (@local_manager.slave?)
                @dynamic_avpair.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render edit_author_avpair_entry_url(@author_avpair_entry) }
                format.xml  { render :xml => @dynamic_avpair.errors, :status => :not_acceptable }
            end

            begin
                DynamicAvpair.transaction do
                    @dynamic_avpair.update_attributes(params[:dynamic_avpair])
                    values = params[:object_groups]

                    # values to destroy or leave alone
                    @dynamic_avpair.dynamic_avpair_values.each do |x|
                        if (values.has_key?(x.id)) # already exists, remove from values hash
                            values[x.id].delete
                        else # no longer wanted. destroy
                            x.destroy
                        end
                    end

                   # new values to create
                   values.keys.each do |x|
                        if (@dynamic_avpair.obj_type == 'network_av')
                            @dynamic_avpair.dynamic_avpair_values.create(:network_object_group_id => x)
                        else
                            @dynamic_avpair.dynamic_avpair_values.create(:shell_command_object_group_id => x)
                        end
                    end
                end
                raise if (@dynamic_avpair.errors.length > 0)
                @local_manager.log(:username => @session_user.username, :configuration_id => @author_avpair.configuration_id, :author_avpair_id => @author_avpair.id, :message => "Updated #{@dynamic_avpair.obj_type} from entry #{@author_avpair_entry.sequence} of Author AVPair #{@author_avpair.name} within configuration #{@configuration.name}.")
                format.html { redirect_to edit_author_avpair_entry_url(@author_avpair_entry) }
                format.xml  { render :xml => @dynamic_avpair.to_xml }

            rescue Exception => error
                @dynamic_avpair.errors.add_to_base(error)
                format.html { render :action => "edit" }
                format.xml  { render :xml => @dynamic_avpair.errors, :status => :unprocessable_entity }
            end
        end
    end

private

    def authorize
        @dynamic_avpair = DynamicAvpair.find(params[:id])
        @author_avpair_entry = @dynamic_avpair.author_avpair_entry
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
