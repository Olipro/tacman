# curl -H "Accept: text/xml" -H "Content-type: application/xml" 
# -d "<?xml version ='1.0' encoding 'UTF-8'?> <data></data>" http://localhost:3000/managers

require File.dirname(__FILE__) + '/../test_helper'

class ManagersControllerTest < ActionController::TestCase

    def setup
        @controller = RemoteSystemController.new
        @request = ActionController::TestRequest.new
        @response = ActionController::TestResponse.new
    end


    def test_approve
        get :approve, {:serial => managers(:remote1).serial}, {:user_id => users(:admin).id}
        assert_response :redirect
        assert_redirected_to({:action => :show, :serial => managers(:remote1).serial})
        assert_equal('remote_nav', assigns(:nav))

        get :approve, {:serial => managers(:remote1).serial}, {:user_id => users(:user_admin).id}
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        get :approve, {:serial => managers(:remote2).serial}, {:user_id => users(:admin).id}
        assert_response :success
    end


    def test_destroy
        # html
        delete(:destroy, {:serial => managers(:remote1).serial}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to({:action => :index})

        delete(:destroy, {:serial => managers(:local).serial}, {:user_id => users(:admin).id})
        assert_template 'local'

        delete(:destroy, {:serial => managers(:remote1).serial}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        delete(:destroy, {:serial => managers(:remote2).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_edit
        get :edit, {:serial => managers(:local).serial}, {:user_id => users(:admin).id}
        assert_response :success
        assert_equal('local_nav', assigns(:nav))

        get :edit, {:serial => managers(:remote2).serial}, {:user_id => users(:admin).id}
        assert_response :success
        assert_equal('remote_nav', assigns(:nav))

        get :edit, {:serial => managers(:remote2).serial}, {:user_id => users(:user_admin).id}
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        get :edit, {:serial => managers(:remote2).serial}, {:user_id => users(:admin).id}
        assert_response :success
    end

    def test_inbox
        get :inbox, {:serial => managers(:remote1).serial}, {:user_id => users(:admin).id}
        assert_response :success
        assert_equal('remote_nav', assigns(:nav))

        get :inbox, {:serial => managers(:remote1).serial}, {:user_id => users(:user_admin).id}
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        get :inbox, {:serial => managers(:remote1).serial}, {:user_id => users(:admin).id}
        assert_response :success      
    end

    def test_index
        get :index, {}, {:user_id => users(:admin).id}
        assert_response :success
        assert_equal('index_nav', assigns(:nav))

        get :index, {}, {:user_id => users(:user_admin).id}
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        get :index, {}, {:user_id => users(:admin).id}
        assert_response :success
    end

    def test_local
        get :local, {}, {:user_id => users(:admin).id}
        assert_response :success
        assert_equal('local_nav', assigns(:nav))

        get :local, {}, {:user_id => users(:user_admin).id}
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        get :local, {}, {:user_id => users(:admin).id}
        assert_response :success
    end

    def test_local_logs
        get :local_logs, {}, {:user_id => users(:admin).id}
        assert_response :success
        assert_equal('local_nav', assigns(:nav))

        get :local_logs, {}, {:user_id => users(:user_admin).id}
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        get :local_logs, {}, {:user_id => users(:admin).id}
        assert_response :success 
    end

    def test_master
        post(:master, {:serial => managers(:local).serial}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :local
        assert_equal('local_nav', assigns(:nav))

        post(:master, {:serial => managers(:local).serial}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        post(:master, {:serial => managers(:local).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_outbox
        get :outbox, {:serial => managers(:remote1).serial}, {:user_id => users(:admin).id}
        assert_response :success
        assert_equal('remote_nav', assigns(:nav))

        get :outbox, {:serial => managers(:remote1).serial}, {:user_id => users(:user_admin).id}
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        get :outbox, {:serial => managers(:remote1).serial}, {:user_id => users(:admin).id}
        assert_response :success      
    end

    def test_register
        Manager.local.master!
        post( :register, {:manager => {:base_url => "localhost:3003/managers"} } )
        assert_response :accepted

        post( :register, {:manager => {:name => 'test'} } )
        assert_response :not_acceptable
    end

    def test_request_registration
        #need a way to test this
    end

    def test_show
        get :show, {:serial => managers(:remote1).serial}, {:user_id => users(:admin).id}
        assert_response :success
        assert_equal('remote_nav', assigns(:nav))

        get :show, {:serial => managers(:remote1).serial}, {:user_id => users(:user_admin).id}
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        get :show, {:serial => managers(:remote1).serial}, {:user_id => users(:admin).id}
        assert_response :success      
    end

    def test_show_master
        get :show_master, {}, {:user_id => users(:admin).id}
        assert_response :success
        assert_equal('remote_nav', assigns(:nav))

        get :show_master, {}, {:user_id => users(:user_admin).id}
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        get :show_master, {}, {:user_id => users(:admin).id}
        assert_response :success
    end

    def test_slave
        post(:slave, {:serial => managers(:local).serial}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :local
        assert_equal('local_nav', assigns(:nav))

        post(:slave, {:serial => managers(:local).serial}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        post(:slave, {:serial => managers(:local).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_stand_alone
        post(:stand_alone, {:serial => managers(:local).serial}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :local
        assert_equal('local_nav', assigns(:nav))

        post(:stand_alone, {:serial => managers(:local).serial}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        post(:stand_alone, {:serial => managers(:local).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_unprocessable_messages
    flunk
    end

    def test_update
        put(:update, {:serial => managers(:local).serial, :manager => {:name => 'new'}}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :local
        assert_equal('local_nav', assigns(:nav))

       put(:update, {:serial => managers(:remote1).serial, :manager => {:name => 'new2'}}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show
        assert_equal('remote_nav', assigns(:nav))

        put(:update, {:serial => managers(:local).serial, :manager => {:name => 'new3'}}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :home


        # xml
        @request.accept = 'text/xml'
        put(:update, {:serial => managers(:local).serial, :manager => {:name => 'new'}}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_write_to_inbox
        doc = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><manager><password>#{managers(:remote1).password}</password>" +
              "<system-messages><system-message><verb>save</verb><content><users></users></content></system-message></system-messages></manager>"

        @request.body.puts(doc)
        post( :write_to_inbox )
        assert_response :not_acceptable

        doc = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><manager><serial>#{managers(:remote1).serial}</serial><password>#{managers(:remote1).password}</password>" +
              "<system-messages><system-message><verb>save</verb><content><users></users></content></system-message></system-messages></manager>"
        managers(:remote1).approve!
        @request.body.puts(doc)
        post( :write_to_inbox )
        puts @response.body
        assert_response :success
        
    end

    def test_write_to_inbox_auth_fail
        doc = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><manager><serial>#{managers(:remote1).serial}</serial><password>blahblah</password>" +
              "<messages><message verb=\"save\"><users></users></message></messages></manager>"
              
        managers(:remote1).approve!
        managers(:remote1).save
        @request.body.puts(doc)
        post( :write_to_inbox, {:serial => managers(:remote1).serial} )
        assert_response :forbidden
        
    end

end
