require File.dirname(__FILE__) + '/../test_helper'

class UsersControllerTest < ActionController::TestCase

    def setup
        @controller = User.new
        @request = ActionController::TestRequest.new
        @response = ActionController::TestResponse.new
    end

    def test_authenticate
        User.find(1).set_password('Password1', 'Password1', false)
        User.find(2).set_password('Password1', 'Password1', false)
        User.find(3).set_password('Password1', 'Password1', false)

        put(:authenticate, {:user => {:username => 'admin', :password => 'Password1'} })
        assert_redirected_to :action => :home

        put(:authenticate, {:user => {:username => 'user_admin', :password => 'Password1'} })
        assert_redirected_to :action => :home

        put(:authenticate, {:user => {:username => 'user', :password => 'Password1'} })
        assert_redirected_to :action => :home

        put(:authenticate, {:user => {:username => 'admin', :password => 'Password2'} })
        assert_redirected_to :action => :login

        # xml
        @request.accept = 'text/xml'
        put(:authenticate, {:user => {:username => 'admin', :password => 'Password1'} })
        assert_response :success

        put(:authenticate, {:user => {:username => 'admin', :password => 'Password2'} })
        assert_response :forbidden
    end

    def test_change_enable
        get :change_enable, {}, {:user_id => users(:admin).id}
        assert_response :success

        get :change_enable, {}, {:user_id => users(:user_admin).id}
        assert_response :success

        get :change_enable, {}, {:user_id => users(:user).id}
        assert_response :success
    end

    def test_change_password
        get :change_password, {}, {:user_id => users(:admin).id}
        assert_response :success

        get :change_password, {}, {:user_id => users(:user_admin).id}
        assert_response :success

        get :change_password, {}, {:user_id => users(:user).id}
        assert_response :success
    end

    def test_create
        # slave system
        Manager.local.slave!
        post(:create, {:user => {:username => 'test'}, :password => 'Password1', :enable => 'EnablePassword1'}, {:user_id => users(:admin).id})
        assert_response :success
        assert_template 'new'

        Manager.local.master!
        # html
        post(:create, {:user => {:username => 'test'}, :password => 'Password1', :enable => 'EnablePassword1'}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        post(:create, {:user => {:username => 'test'}, :password => 'Password1', :enable => 'EnablePassword1'}, {:user_id => users(:admin).id})
        assert_response :success
        assert_template 'new'

        post(:create, {:user => {:username => 'test2'}, :password => 'Password1', :enable => 'EnablePassword1'}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        post(:create, {:user => {:username => 'test3'}, :password => 'Password1', :enable => 'EnablePassword1'}, {:user_id => users(:user).id})
        assert_response :redirect
        assert_redirected_to :action => :home


        # xml
        @request.accept = 'text/xml'

        post(:create, {:user => {:username => 'test4'}, :password => 'Password1', :enable => 'EnablePassword1'}, {:user_id => users(:admin).id})
        assert_response :created

        post(:create, {:user => {:username => 'test4'}, :password => 'Password1', :enable => 'EnablePassword1'}, {:user_id => users(:admin).id})
        assert_response :unprocessable_entity
    end


    def test_destroy
        # slave system
        Manager.local.slave!
        delete(:destroy, {:serial => users(:user2).serial}, {:user_id => users(:admin).id})
        assert_response :success
        assert_template 'show'

        Manager.local.master!
        # html
        delete(:destroy, {:serial => users(:user2).serial}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :index

        delete(:destroy, {:serial => users(:admin).serial}, {:user_id => users(:admin).id})
        assert_response :success
        assert_template 'show'

        delete(:destroy, {:serial => users(:user3).serial}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :index

        delete(:destroy, {:serial => users(:admin).serial}, {:user_id => users(:user_admin).id})
        assert_response :success
        assert_template 'show'

        delete(:destroy, {:serial => users(:user4).serial}, {:user_id => users(:user).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        delete(:destroy, {:serial => users(:user).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_edit
        get :edit, {:serial => users(:admin).serial}, {:user_id => users(:admin).id}
        assert_response :success

        get :edit, {:serial => users(:admin).serial}, {:user_id => users(:user_admin).id}
        assert_response :success

        get :edit, {:serial => users(:admin).serial}, {:user_id => users(:user).id}
        assert_response :redirect
        assert_redirected_to :action => :home

    end

    def test_force_join
        # slave system
        Manager.local.slave!
        post(:force_join, {:serial => users(:user3).serial, :configuration => configurations(:basic).serial}, {:user_id => users(:admin).id})
        assert_response :success
        assert_template 'show'

        Manager.local.master!
        post(:force_join, {:serial => users(:user3).serial, :configuration => configurations(:basic).serial}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        post(:force_join, {:serial => users(:user4).serial, :configuration => configurations(:basic).serial}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        post(:force_join, {:serial => users(:user).serial, :configuration => configurations(:basic).serial}, {:user_id => users(:user).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        post(:force_join, {:serial => users(:user).serial, :configuration => configurations(:basic).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_force_withdraw
        # slave system
        Manager.local.slave!
        post(:force_withdraw, {:serial => users(:user3).serial, :configuration => configurations(:basic).serial}, {:user_id => users(:admin).id})
        assert_response :success
        assert_template 'show'

        Manager.local.master!
        post(:force_withdraw, {:serial => users(:user3).serial, :configuration => configurations(:basic).serial}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        post(:force_withdraw, {:serial => users(:user4).serial, :configuration => configurations(:basic).serial}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        post(:force_withdraw, {:serial => users(:user).serial, :configuration => configurations(:basic).serial}, {:user_id => users(:user).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        post(:force_withdraw, {:serial => users(:user).serial, :configuration => configurations(:basic).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_home
        get :home, {}, {:user_id => users(:admin).id}
        assert_response :success
        assert_template 'home'

        get :home, {}, {:user_id => users(:user_admin).id}
        assert_response :success
        assert_template 'home'

        get :home, {}, {:user_id => users(:user).id}
        assert_response :success
        assert_template 'home'
    end

    def test_fail
    flunk # finish the rest of these
    end
end
__END__
    def test_index
        get :index, {}, {:user_id => users(:admin).id}
        assert_response :success

        get :index, {}, {:user_id => users(:user_admin).id}
        assert_response :success

        get :index, {}, {:user_id => users(:user).id}
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        get(:index, {}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_login
        get :login
        assert_response :success
    end

    def test_new
        get :new, {:serial => users(:admin).serial}, {:user_id => users(:admin).id}
        assert_response :success

        get :new, {:serial => users(:admin).serial}, {:user_id => users(:user_admin).id}
        assert_response :success

        get :new, {:serial => users(:admin).serial}, {:user_id => users(:user).id}
        assert_response :redirect
        assert_redirected_to :action => :home
    end

    def test_request_join
    flunk
    end

    def test_reset_enable
        get :reset_enable, {:serial => users(:user_admin).serial}, {:user_id => users(:admin).id}
        assert_response :success

        get :reset_enable, {:serial => users(:user3).serial}, {:user_id => users(:user_admin).id}
        assert_response :success

        get :reset_enable, {:serial => users(:user3).serial}, {:user_id => users(:user).id}
        assert_response :redirect
        assert_redirected_to :action => :home
    end

    def test_reset_password
        get :reset_password, {:serial => users(:user_admin).serial}, {:user_id => users(:admin).id}
        assert_response :success

        get :reset_password, {:serial => users(:user3).serial}, {:user_id => users(:user_admin).id}
        assert_response :success

        get :reset_password, {:serial => users(:user3).serial}, {:user_id => users(:user).id}
        assert_response :redirect
        assert_redirected_to :action => :home
    end

    def test_set_role_admin
        put(:set_role_admin, {:serial => users(:user3).serial}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        put(:set_role_admin, {:serial => users(:user4).serial}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        put(:set_role_admin, {:serial => users(:user).serial}, {:user_id => users(:user).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        put(:set_role_admin, {:serial => users(:user).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_set_role_user
        put(:set_role_user, {:serial => users(:user_admin).serial}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        put(:set_role_user, {:serial => users(:user_admin).serial}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        put(:set_role_user, {:serial => users(:user_admin).serial}, {:user_id => users(:user).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        put(:set_role_user, {:serial => users(:user_admin).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_set_role_user_admin
        put(:set_role_user_admin, {:serial => users(:user2).serial}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        put(:set_role_user_admin, {:serial => users(:user2).serial}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        put(:set_role_user_admin, {:serial => users(:user2).serial}, {:user_id => users(:user).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        put(:set_role_user_admin, {:serial => users(:user).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_show
        get :show, {:serial => users(:admin).serial}, {:user_id => users(:admin).id}
        assert_response :success

        get :show, {:serial => users(:admin).serial}, {:user_id => users(:user_admin).id}
        assert_response :success

        get :show, {:serial => users(:admin).serial}, {:user_id => users(:user).id}
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        get(:show, {:serial => users(:admin).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_toggle_allow_web_login
        put(:toggle_allow_web_login, {:serial => users(:admin).serial}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        put(:toggle_allow_web_login, {:serial => users(:admin).serial}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        put(:toggle_allow_web_login, {:serial => users(:admin).serial}, {:user_id => users(:user).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        put(:toggle_allow_web_login, {:serial => users(:admin).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_toggle_disabled
        put(:toggle_disabled, {:serial => users(:admin).serial}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        put(:toggle_disabled, {:serial => users(:admin).serial}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        put(:toggle_disabled, {:serial => users(:admin).serial}, {:user_id => users(:user).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        put(:toggle_disabled, {:serial => users(:admin).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_toggle_enable_expiry
        put(:toggle_enable_expiry, {:serial => users(:admin).serial}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        put(:toggle_enable_expiry, {:serial => users(:admin).serial}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        put(:toggle_enable_expiry, {:serial => users(:admin).serial}, {:user_id => users(:user).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        put(:toggle_enable_expiry, {:serial => users(:admin).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_toggle_password_expiry
        put(:toggle_password_expiry, {:serial => users(:admin).serial}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        put(:toggle_password_expiry, {:serial => users(:admin).serial}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        put(:toggle_password_expiry, {:serial => users(:admin).serial}, {:user_id => users(:user).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        # xml
        @request.accept = 'text/xml'
        put(:toggle_password_expiry, {:serial => users(:admin).serial}, {:user_id => users(:admin).id})
        assert_response :success
    end

    def test_update
        put(:update, {:serial => users(:admin).serial, :user => {:username => 'new'}}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        put(:update, {:serial => users(:admin).serial, :user => {:username => 'new'}}, {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show

        put(:update, {:serial => users(:admin).serial, :user => {:username => 'new'}}, {:user_id => users(:user).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        put(:update, {:serial => users(:admin).serial, :user => {:username => ''}}, {:user_id => users(:admin).id})
        assert_response :ok
        assert_template 'edit'


        # xml
        @request.accept = 'text/xml'

        put(:update, {:serial => users(:admin).serial, :user => {:username => 'new'}}, {:user_id => users(:admin).id})
        assert_response :success

        put(:update, {:serial => users(:admin).serial, :user => {:username => ''}}, {:user_id => users(:admin).id})
        assert_response :unprocessable_entity
    end

    def test_update_change_enable
        User.find(1).set_password('EnablePassword1', 'Password1', true)
        User.find(2).set_password('EnablePassword1', 'Password1', true)
        User.find(3).set_password('EnablePassword1', 'Password1', true)

        put(:update_change_enable, {:enable => 'NewEnablePassword1', :enable_confirmation => 'NewEnablePassword1',
                                    :current_enable => 'EnablePassword1'}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        put(:update_change_enable, {:enable => 'NewEnablePassword1', :enable_confirmation => 'NewEnablePassword1',
                                    :current_enable => 'EnablePassword1'}, {:user_id => users(:admin).id})
        assert_response :ok
        assert_template 'change_enable'


        # xml
        @request.accept = 'text/xml'

        put(:update_change_enable, {:enable => 'NewEnablePassword2', :enable_confirmation => 'NewEnablePassword2',
                                    :current_enable => 'NewEnablePassword1'}, {:user_id => users(:admin).id})
        assert_response :success

        put(:update_change_enable, {:enable => 'NewEnablePassword2', :enable_confirmation => 'NewEnablePassword2',
                                    :current_enable => 'NewEnablePassword1'}, {:user_id => users(:admin).id})
        assert_response :unprocessable_entity
    end

    def test_update_change_password
        put(:update_change_password, {:password => 'NewPassword1', :password_confirmation => 'NewPassword1',
                                      :current_password => 'Password1'}, {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :home

        put(:update_change_password, {:password => 'NewPassword1', :password_confirmation => 'NewPassword1',
                                      :current_password => 'Password1'}, {:user_id => users(:admin).id})
        assert_response :ok
        assert_template 'change_password'


        # xml
        @request.accept = 'text/xml'

        put(:update_change_password, {:password => 'NewPassword2', :password_confirmation => 'NewPassword2',
                                      :current_password => 'NewPassword1'}, {:user_id => users(:admin).id})
        assert_response :success

        put(:update_change_password, {:password => 'NewPassword2', :password_confirmation => 'NewPassword2',
                                      :current_password => 'NewPassword1'}, {:user_id => users(:admin).id})
        assert_response :unprocessable_entity
    end

    def test_update_reset_enable
        put(:update_reset_enable, {:serial => users(:user_admin).serial, :enable => 'NewPassword1', :enable_confirmation => 'NewPassword1'},
                                    {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show


        put(:update_reset_enable, {:serial => users(:user3).serial, :enable => 'NewPassword1', :enable_confirmation => 'NewPassword1'},
                                    {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show


        put(:update_reset_enable, {:serial => users(:user4).serial, :enable => 'NewPassword1', :enable_confirmation => 'NewPassword1'},
                                    {:user_id => users(:user).id})
        assert_response :redirect
        assert_redirected_to :action => :home


        put(:update_reset_enable, {:serial => users(:user_admin).serial, :enable => 'NewPassword1', :enable_confirmation => 'NewPassword2'},
                                    {:user_id => users(:admin).id})
        assert_response :ok
        assert_template 'reset_enable'


        # xml
        @request.accept = 'text/xml'

        put(:update_reset_enable, {:serial => users(:user_admin).serial, :enable => 'NewPassword1', :enable_confirmation => 'NewPassword1'},
                                    {:user_id => users(:admin).id})
        assert_response :success

        put(:update_reset_enable, {:serial => users(:user_admin).serial, :enable => 'NewPassword1', :enable_confirmation => 'NewPassword2'},
                                    {:user_id => users(:admin).id})
        assert_response :unprocessable_entity
    end

    def test_update_reset_password
        put(:update_reset_password, {:serial => users(:user_admin).serial, :password => 'NewPassword1', :password_confirmation => 'NewPassword1'},
                                    {:user_id => users(:admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show


        put(:update_reset_password, {:serial => users(:user3).serial, :password => 'NewPassword1', :password_confirmation => 'NewPassword1'},
                                    {:user_id => users(:user_admin).id})
        assert_response :redirect
        assert_redirected_to :action => :show


        put(:update_reset_password, {:serial => users(:user4).serial, :password => 'NewPassword1', :password_confirmation => 'NewPassword1'},
                                    {:user_id => users(:user).id})
        assert_response :redirect
        assert_redirected_to :action => :home


        put(:update_reset_password, {:serial => users(:user_admin).serial, :password => 'NewPassword1', :password_confirmation => 'NewPassword2'},
                                    {:user_id => users(:admin).id})
        assert_response :ok
        assert_template 'reset_password'


        # xml
        @request.accept = 'text/xml'

        put(:update_reset_password, {:serial => users(:user_admin).serial, :password => 'NewPassword1', :password_confirmation => 'NewPassword1'},
                                    {:user_id => users(:admin).id})
        assert_response :success

        put(:update_reset_password, {:serial => users(:user_admin).serial, :password => 'NewPassword1', :password_confirmation => 'NewPassword2'},
                                    {:user_id => users(:admin).id})
        assert_response :unprocessable_entity
    end

    def test_withdraw_join
    flunk
    end

end
