class AvpairsController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change

    def destroy
        respond_to do |format|
            @nav = 'author_avpairs/show_nav'
            if (@local_manager.slave?)
                @avpair.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render edit_author_avpair_entry_url(@author_avpair_entry) }
                format.xml  { render :xml => @avpair.errors, :status => :not_acceptable }
            elsif (@avpair.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @author_avpair.configuration_id, :author_avpair_id => @author_avpair.id, :message => "Deleted avpair (#{@avpair.avpair}) from entry #{@author_avpair_entry.sequence} of Author AVPair #{@author_avpair.name} within configuration #{@configuration.name}.")
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
            format.html {@nav = 'author_avpair_entries/dynamic_avpair_nav'}
        end
    end

    def update
        respond_to do |format|
            @nav = 'author_avpair_entries/dynamic_avpair_nav'
            if (@local_manager.slave?)
                @avpair.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "edit" }
                format.xml  { render :xml => @avpair.errors, :status => :not_acceptable }
            elsif @avpair.update_attributes(params[:avpair])
                @local_manager.log(:username => @session_user.username, :configuration_id => @author_avpair.configuration_id, :author_avpair_id => @author_avpair.id, :message => "Updated AVPair for entry #{@author_avpair_entry.sequence} of #{@author_avpair.name} within configuration #{@configuration.name}.")
                format.html { redirect_to edit_author_avpair_entry_url(@author_avpair_entry) }
                format.xml  { head :ok }
            else
                format.html { render :action => "edit" }
                format.xml  { render :xml => @avpair.errors, :status => :unprocessable_entity }
            end
        end
    end

private

    def authorize
        @avpair = Avpair.find(params[:id])
        @author_avpair_entry = @avpair.author_avpair_entry
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
