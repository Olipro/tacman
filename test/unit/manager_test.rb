require File.dirname(__FILE__) + '/../test_helper'

class ManagerTest < ActiveSupport::TestCase
    fixtures :managers

    def test_invalid_with_empty_attributes
        manager = Manager.new
        assert !manager.valid?
        assert manager.errors.invalid?(:base_url)
        assert manager.errors.invalid?(:name)
        assert manager.errors.invalid?(:password)
    end

    def test_invalid_if_name_not_unique
        manager = Manager.new(:name => 'remote1', :password => 'password',
                              :base_url => "http://localhost:3009", :manager_type => 'slave')
        manager.serial = Manager.serial
        assert !manager.valid?
        assert manager.errors.invalid?(:name)
        manager.name = 'new'
        assert manager.valid?
    end

    def test_invalid_if_url_not_unique
        manager = Manager.new(:name => 'new', :password => 'password',
                              :base_url => "http://localhost:3001/managers", :manager_type => 'slave')
        manager.serial = Manager.serial
        assert !manager.valid?
        assert manager.errors.invalid?(:base_url)
        manager.base_url = "http://localhost:8080/managers"
        assert manager.valid?
    end

    def test_manager_type_invalid
        managers(:local).manager_type = 'a'
        assert !managers(:local).valid?
        managers(:local).manager_type = 'master'
        assert managers(:local).valid?
        managers(:local).manager_type = 'slave'
        assert managers(:local).valid?
        managers(:local).manager_type = 'stand_alone'
        assert managers(:local).valid?
    end

    def test_system_log_retention_invalid
        managers(:local).system_log_retention = -1
        assert !managers(:local).valid?
        managers(:local).system_log_retention = 0
        assert managers(:local).valid?
    end

    def test_default_enable_lifespan_invalid
        managers(:local).default_enable_lifespan = -1
        assert !managers(:local).valid?
        managers(:local).default_enable_lifespan = 366
        assert !managers(:local).valid?
        managers(:local).default_enable_lifespan = 0
        assert managers(:local).valid?
    end

    def test_default_password_lifespan_invalid
        managers(:local).default_password_lifespan = -1
        assert !managers(:local).valid?
        managers(:local).default_password_lifespan = 366
        assert !managers(:local).valid?
        managers(:local).default_password_lifespan = 0
        assert managers(:local).valid?
    end

    def test_password_minimum_length_invalid
        managers(:local).password_minimum_length = 7
        assert !managers(:local).valid?
        managers(:local).password_minimum_length = 256
        assert !managers(:local).valid?
        managers(:local).password_minimum_length = 8
        assert managers(:local).valid?
    end

    def test_can_create_remote_manager
        remote1 = Manager.new(:name => 'remote1', :password => 'a', :base_url => 'a', :manager_type => 'slave')
        managers(:local).stand_alone!
        assert !remote1.save

        remote1 = Manager.new(:name => 'remote1', :password => 'a', :base_url => 'a', :manager_type => 'slave')
        managers(:local).slave!
        assert !remote1.save

        remote1 = Manager.new(:name => 'remote1', :password => 'a', :base_url => 'a', :manager_type => 'master')
        assert remote1.save

        remote1 = Manager.new(:name => 'remote1', :password => 'a', :base_url => 'a', :manager_type => 'master')
        managers(:local).master!
        assert !remote1.save

        remote2 = Manager.new(:name => 'remote2', :password => 'b', :base_url => 'b', :manager_type => 'slave')
        assert remote2.save
    end

    def test_cant_destroy_local
        assert !managers(:local).destroy
    end

    def test_add_to_all_outbox
        msg = "<users></users>"
        assert_nil Manager.add_to_all_outbox('sync', msg)
        assert_kind_of(Hash, Manager.add_to_all_outbox('blah', msg) )
    end

    def test_credentials_from_xml
        doc = REXML::Document.new("<manager><serial>1234</serial><password>abcd</password></manager>")
        cred = Manager.credentials_from_xml(doc)
        assert_kind_of(Array, cred)
        assert_equal('1234', cred[0])
        assert_equal('abcd', cred[1])
        doc = REXML::Document.new("<manager><serial>1234</serial></manager>")
        assert_nil(Manager.credentials_from_xml(doc))
    end

    def test_destroy_non_local
        Manager.destroy_non_local!
        assert_equal(1, Manager.count)
    end

    def test_local
        assert_equal(managers(:local).id, Manager.local.id)
    end

    def test_non_local
        assert_equal(2, Manager.non_local.length)
    end

    def test_register
        managers(:local).master!
        ret = Manager.register("http://localhost:3003")
        assert_kind_of(Manager, ret)
        l = Manager.register("http://localhost:3003")
        assert_equal(2, l.errors.length)
    end

    def test_request_registration
        # figure out way to test this
    end

    def test_serial
        assert_not_nil(Manager.serial)
    end






    def test_add_to_inbox
        doc = REXML::Document.new("<manager><system-messages><system-message> <verb>save</verb><content><users></users></content></system-message></system-messages></manager>")
        assert managers(:remote1).add_to_inbox(doc)
        doc = REXML::Document.new("<manager><users></users></manager>")
        assert !managers(:remote1).add_to_inbox(doc)
    end

    def test_add_to_outbox
        msg = "<users></users>"
        assert !managers(:remote1).add_to_outbox('sync', msg)
        assert managers(:remote1).add_to_outbox('blah', msg)
    end

    def test_approved
        manager = Manager.new(:name => 'new', :password => 'password', :serial => Manager.serial)
        assert !manager.is_approved
        manager.approve!
        assert manager.is_approved
        assert manager.is_enabled
    end

    def test_authenticate
        assert !managers(:remote1).authenticate(managers(:remote1).password)

        managers(:remote1).approve!
        assert managers(:remote1).authenticate(managers(:remote1).password)

        assert !managers(:remote1).authenticate('pwd')
    end

    def test_disable
        managers(:remote1).approve!
        managers(:remote1).is_enabled = true
        assert managers(:remote1).is_enabled
        managers(:remote1).disable!('test')
        assert !managers(:remote1).is_enabled
        assert_equal('test',  managers(:remote1).disabled_message )
    end

    def test_enable
        managers(:remote1).approve!
        managers(:remote1).is_enabled = false
        assert !managers(:remote1).is_enabled
        managers(:remote1).enable!
        assert managers(:remote1).is_enabled
    end

    def test_inbox
        inbox = managers(:local).inbox
        assert_equal(1, inbox[0].id)
        assert_equal(2, inbox[1].id)
    end

    def test_manager_types
        assert managers(:local).master?
        assert managers(:remote1).slave?
        managers(:remote1).destroy
        managers(:remote2).destroy
        managers(:local).slave!
        assert managers(:local).slave?
        managers(:local).stand_alone!
        assert managers(:local).stand_alone?
    end

    def test_outbox
        outbox = managers(:local).outbox
        assert_equal(3, outbox[0].id)
        assert_equal(4, outbox[1].id)
    end

    def test_prepare_http_request
        assert_kind_of(Array, managers(:local).prepare_http_request('register') )
    end

    def test_process_inbox
    flunk
    end

    def test_unprocessable_messages
        unprocessable_messages = managers(:local).unprocessable_messages
        assert_equal(9, unprocessable_messages[0].id)
        unprocessable_messages = managers(:remote1).unprocessable_messages
        assert_equal(10, unprocessable_messages[0].id)
    end

    def test_write_remote_inbox!
        # need a way to test this
    end


end
