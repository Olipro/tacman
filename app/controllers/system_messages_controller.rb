class SystemMessagesController < ApplicationController
    before_filter :define_session_user
    before_filter :authorize_admin
    before_filter :force_pw_change

    def destroy
        @system_message = SystemMessage.find(params[:id])
        respond_to do |format|
                @system_message.destroy
                format.html { redirect_to( request.env["HTTP_REFERER"] ) }
                format.xml  { head :ok }
        end
    end

end
