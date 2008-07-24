class AuthorAvpairEntriesController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize
    before_filter :force_pw_change

    def destroy
        respond_to do |format|
            @nav = 'author_avpairs/show_nav'
            if (@local_manager.slave?)
                @author_avpair.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render author_avpairs_configuration_url(@author_avpair.configuration) }
                format.xml  { render :xml => @author_avpair.errors, :status => :not_acceptable }
            elsif (@author_avpair_entry.destroy)
                @local_manager.log(:username => @session_user.username, :configuration_id => @author_avpair.configuration_id, :author_avpair_id => @author_avpair.id, :message => "Deleted entry #{@author_avpair_entry.sequence} of Author AVPair '#{@author_avpair.name}'.")
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
                        if (attr == 'custom')
                            avpair = val
                        else
                            avpair = attr + '=' + val
                        end
                        @author_avpair_entry.avpairs.create!(:avpair => avpair)
                    end
                end
                raise if (@author_avpair_entry.errors.length > 0)
                @local_manager.log(:username => @session_user.username, :configuration_id => @author_avpair.configuration_id, :author_avpair_id => @author_avpair.id, :message => "Updated entry #{@author_avpair_entry.sequence} of Author AVPair '#{@author_avpair.name}'.")
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
