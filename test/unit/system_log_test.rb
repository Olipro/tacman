require File.dirname(__FILE__) + '/../test_helper'

class SystemLogTest < ActiveSupport::TestCase
  fixtures :system_logs, :users

    def test_invalid_with_empty_attributes
        system_log = SystemLog.new
        assert !system_log.valid?
        assert system_log.errors.invalid?(:message)
        assert system_log.errors.invalid?(:manager_id)
    end

    def test_create
        system_log = SystemLog.new(:manager_id => 1, :username => users(:admin).username, :user_serial => users(:admin).serial, :message => 'test')
        assert system_log.valid?
    end

    def test_log_fields_header
        assert_equal(["Level", "Timestamp", "User-Serial", "Username", "Message"], SystemLog.log_fields_header)
    end

    def test_log_fields
        assert_equal(5, system_logs(:num1).log_fields.length)
    end

    def test_invalid_if_level_not_known
        system_log = SystemLog.new(:manager_id => 1, :level => 'blah', :message => 'a')
        assert !system_log.valid?
        assert system_log.errors.invalid?(:level)
        system_log.level = 'info'
        assert system_log.valid?
        system_log.level = 'warn'
        assert system_log.valid?
        system_log.level = 'error'
        assert system_log.valid?
    end

end
