# rake db:test:prepare
require File.dirname(__FILE__) + '/../test_helper'


class ConfigurationTest < ActiveSupport::TestCase
    fixtures :configurations

    def test_invalid_with_empty_attributes
        configuration = Configuration.new
        assert !configuration.valid?
        assert configuration.errors.invalid?(:key)
        assert configuration.errors.invalid?(:name)
        assert configuration.errors.invalid?(:serial)
    end

    def test_disabled_prompt_invalid
        configuration = Configuration.new2(:name => 'new', :disabled_prompt => 'a'*256)
        assert !configuration.valid?
        assert configuration.errors.invalid?(:disabled_prompt)
        configuration.disabled_prompt = 'a'
        assert configuration.valid?
    end

    def test_log_level_invalid
        configuration = Configuration.new2(:name => 'new', :log_level => 5)
        assert !configuration.valid?
        assert configuration.errors.invalid?(:log_level)
        configuration.log_level = 0
        assert configuration.valid?
    end

    def test_login_prompt_invalid
        configuration = Configuration.new2(:name => 'new', :login_prompt => 'a'*256)
        assert !configuration.valid?
        assert configuration.errors.invalid?(:login_prompt)
        configuration.login_prompt = 'a'
        assert configuration.valid?
    end

    def test_invalid_if_not_unique
        configuration = Configuration.new2(:name => 'basic')
        assert !configuration.valid?
        assert configuration.errors.invalid?(:name)
        configuration.name = 'new'
        assert configuration.valid?
    end

    def test_password_expired_prompt_invalid
        configuration = Configuration.new2(:name => 'new', :password_expired_prompt => 'a'*256)
        assert !configuration.valid?
        assert configuration.errors.invalid?(:password_expired_prompt)
        configuration.password_expired_prompt = 'a'
        assert configuration.valid?
    end

    def test_password_prompt_invalid
        configuration = Configuration.new2(:name => 'new', :password_prompt => 'a'*256)
        assert !configuration.valid?
        assert configuration.errors.invalid?(:password_prompt)
        configuration.password_prompt = 'a'
        assert configuration.valid?
    end

    def test_new2
        configuration = Configuration.new2(:name => 'new')
        assert_not_nil(configuration.serial)
        assert_not_nil(configuration.key)
    end

    def test_serial
        assert_kind_of(String, Configuration.serial)
    end


end
