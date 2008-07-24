require File.dirname(__FILE__) + '/../test_helper'

class UserTest < ActiveSupport::TestCase
    fixtures :users

    def test_invalid_with_empty_attributes
        user = User.new
        assert !user.valid?
        assert user.errors.invalid?(:username)
    end

    def test_random_password
        assert_kind_of(String, User.random_password)
        assert_equal(Manager.local.password_minimum_length, User.random_password.length)
    end



    def test_account_status
        assert_equal('active', users(:admin).account_status )
        users(:admin).disabled = true
        assert_equal('disabled', users(:admin).account_status )
    end

    def test_admin_role
        user = User.create(:username => 'test')
        user.admin!
        assert user.admin?
    end

    def test_change_password
        user = users(:admin)
        user.set_password('Password1', 'Password1', false)

        # change pw
        assert user.change_password('NewPassword1', 'NewPassword1', 'Password1')
        # fail - current incorrect
        assert !user.change_password('NewPassword2', 'NewPassword2', 'Password1')
        # fail - pw already used
        assert !user.change_password('NewPassword1', 'NewPassword1', 'NewPassword1')


        # fail - enable not set
        assert !user.change_password('NewEnablePassword2', 'NewEnablePassword2', 'EnablePassword1', true)
        user.set_password('EnablePassword1', 'EnablePassword1', true)
        # change enable
        assert user.change_password('NewEnablePassword1', 'NewEnablePassword1', 'EnablePassword1', true)
        # fail - current incorrect
        assert !user.change_password('NewEnablePassword2', 'NewEnablePassword2', 'EnablePassword1', true)

    end



    def configuration_hash
        assert_kind_of(Hash, user(:admin).configuration_hash)
    end

    def test_enable_password_expired
        users(:admin).set_password('EnablePassword1', 'EnablePassword1', true)
        assert !users(:admin).enable_password_expired?
        users(:admin).enable_password_lifespan = 1
        assert users(:admin).enable_password_expired?
    end

    def test_login_password_expired
        users(:admin).set_password('Password1', 'Password1', false)
        assert !users(:admin).login_password_expired?
        users(:admin).login_password_lifespan = 1
        assert users(:admin).login_password_expired?
    end

    def test_set_password
        users(:admin).set_password('Password1', 'Password1', false)
        assert users(:admin).verify_password('Password1')
        users(:admin).set_password('EnablePassword1', 'EnablePassword1', true)
        assert users(:admin).verify_password('EnablePassword1', true)
    end

    def test_toggle
        user = users(:user4)
        user.set_password('Password1', 'Password1', false)
        user.set_password('EnablePassword1', 'EnablePassword1', true)
        assert user.allow_web_login
        assert !user.disabled
        assert user.login_password.expired?
        assert user.enable_password.expired?

        user.toggle_allow_web_login!
        user.toggle_disabled!
        user.toggle_password_expiry!
        user.toggle_enable_expiry!

        assert !user.allow_web_login
        assert user.disabled
        assert !user.login_password.expired?
        assert !user.enable_password.expired?

        user.toggle_allow_web_login!
        user.toggle_disabled!
        user.toggle_password_expiry!
        user.toggle_enable_expiry!

        assert user.allow_web_login
        assert !user.disabled
        assert user.login_password.expired?
        assert user.enable_password.expired?
    end

    def test_user_role
        user = User.create(:username => 'test', :role => 'admin')
        user.user!
        assert user.user?
    end

    def test_user_admin_role
        user = User.create(:username => 'test')
        user.user_admin!
        assert user.user_admin?
    end

    def test_verify_password
        users(:admin).set_password('Password1', 'Password1', false)
        users(:admin).set_password('EnablePassword1', 'EnablePassword1', true)
        assert users(:admin).verify_password('Password1')
        assert !users(:admin).verify_password('blah')
        assert users(:admin).verify_password('EnablePassword1', true)
        assert !users(:admin).verify_password('blah', true)
    end


end
