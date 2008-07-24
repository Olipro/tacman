require File.dirname(__FILE__) + '/../test_helper'

class SystemMessageTest < ActiveSupport::TestCase
    fixtures :system_messages

    def test_invalid_with_empty_attributes
        system_message = SystemMessage.new
        assert !system_message.valid?
        assert system_message.errors.invalid?(:queue)
        assert system_message.errors.invalid?(:verb)
        assert system_message.errors.invalid?(:content)
        assert system_message.errors.invalid?(:manager_id)
    end

    def test_invalide_if_queue_not_known
        system_message = SystemMessage.new(:manager_id => 1, :queue => 'blah', :verb => 'sync', :content => "<data></data>")
        assert !system_message.valid?
        assert system_message.errors.invalid?(:queue)
        system_message.queue = 'inbox'
        assert system_message.valid?
        system_message.queue = 'outbox'
        assert system_message.valid?
        system_message.queue = 'unprocessable'
        assert system_message.valid?
    end

    def test_invalid_if_verb_not_known
        system_message = SystemMessage.new(:manager_id => 1, :queue => 'inbox', :verb => 'verb', :content => "<data></data>")
        assert !system_message.valid?
        assert system_message.errors.invalid?(:verb)
        system_message.verb = 'save'
        assert system_message.valid?
        system_message.verb = 'destroy'
        assert system_message.valid?
    end


    def test_build_from_xml
        flunk
    end


end
