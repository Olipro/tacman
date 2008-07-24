require File.dirname(__FILE__) + '/../test_helper'

class PasswordHistoryTest < ActiveSupport::TestCase
    fixtures :managers, :password_histories

    def test_invalid_with_empty_attributes
        password_history = PasswordHistory.new(:user_id => 1)
        assert !password_history.valid?
        assert password_history.errors.invalid?(:password_hash)
        assert password_history.errors.invalid?(:salt)
    end

    def test_create
        password_history = PasswordHistory.create(:user_id => 1, :password => 'Password1')
        assert password_history.valid?
        assert password_history.is_current
    end

    def test_encrypt
        assert_kind_of(String, PasswordHistory.encrypt('str','salt') )
    end

    def test_expire
        assert password_histories(:admin).expire!
        assert_equal(Date.today, password_histories(:admin).expires_on)
    end

    def test_expired
        password_histories(:admin).expires_on = Date.today
        assert password_histories(:admin).expired?
    end

    def test_unexpire
        password_histories(:admin).unexpire(2)
        assert_equal(Date.today + 2, password_histories(:admin).expires_on)
    end

    def test_verify
        assert password_histories(:admin).verify('Password1')
    end

end
