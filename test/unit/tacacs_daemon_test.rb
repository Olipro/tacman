# rake db:test:prepare
require File.dirname(__FILE__) + '/../test_helper'

class TacacsDaemonTest < ActiveSupport::TestCase
    fixtures :tacacs_daemons

    def test_invalid_with_empty_attributes
        tacacs_daemon = TacacsDaemon.new
        assert !tacacs_daemon.valid?
        assert tacacs_daemon.errors.invalid?(:ip)
        assert tacacs_daemon.errors.invalid?(:manager_id)
        assert tacacs_daemon.errors.invalid?(:name)
        assert tacacs_daemon.errors.invalid?(:serial)
    end

    def test_invalid_if_not_unique
        tacacs_daemon = TacacsDaemon.new2(:name => 'localhost', :ip => '0.0.0.0', :manager_id => 1)
        assert !tacacs_daemon.valid?
        assert tacacs_daemon.errors.invalid?(:name)
        tacacs_daemon.name = 'new'
        assert tacacs_daemon.valid?
    end

    def test_port_invalid
        tacacs_daemon = TacacsDaemon.new2(:name => 'new', :ip => '0.0.0.0', :port => 0, :manager_id => 1)
        assert !tacacs_daemon.valid?
        assert tacacs_daemon.errors.invalid?(:port)
        tacacs_daemon.port = 49
        assert tacacs_daemon.valid?
    end

    def test_ip_invalid
        tacacs_daemon = TacacsDaemon.new2(:name => 'new', :ip => '127.0.0.1', :manager_id => 1)
        assert !tacacs_daemon.valid?
        assert tacacs_daemon.errors.invalid?(:ip)
        tacacs_daemon.ip = '127.0.0.2'
        assert tacacs_daemon.valid?
    end

    def test_new2
        tacacs_daemon = TacacsDaemon.new2(:name => 'new')
        assert_not_nil(tacacs_daemon.serial)
    end

    def test_serial
        assert_kind_of(String, TacacsDaemon.serial)
    end

end
