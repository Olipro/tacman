require File.dirname(__FILE__) + '/../test_helper'

class ConfiguredUserTest < ActiveSupport::TestCase
    fixtures :configured_users

    def test_invalid_with_empty_attributes
        configured_user = ConfiguredUser.new
        assert !configured_user.valid?
        assert configured_user.errors.invalid?(:configuration_id)
        assert configured_user.errors.invalid?(:user_id)
    end

    def test_role
        configured_users(:admin_basic).role = 'blah'
        assert !configured_users(:admin_basic).valid?
        assert configured_users(:admin_basic).errors.invalid?(:role)
    end

    def test_state
        configured_users(:admin_basic).state = 'blah'
        assert !configured_users(:admin_basic).valid?
        assert configured_users(:admin_basic).errors.invalid?(:state)
    end

    def test_status
        assert_equal('disabled', configured_users(:admin_basic).status)
        configured_users(:admin_basic).is_enabled = true
        assert_equal('enabled', configured_users(:admin_basic).status)
    end

end
