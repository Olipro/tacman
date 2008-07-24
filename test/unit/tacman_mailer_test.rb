require File.dirname(__FILE__) + '/../test_helper'

class TacmanMailerTest < ActionMailer::TestCase
  tests TacmanMailer
  def test_account_disabled
    @expected.subject = 'TacmanMailer#account_disabled'
    @expected.body    = read_fixture('account_disabled')
    @expected.date    = Time.now

    assert_equal @expected.encoded, TacmanMailer.create_account_disabled(@expected.date).encoded
  end

  def test_alerts
    @expected.subject = 'TacmanMailer#alerts'
    @expected.body    = read_fixture('alerts')
    @expected.date    = Time.now

    assert_equal @expected.encoded, TacmanMailer.create_alerts(@expected.date).encoded
  end

  def test_new_account
    @expected.subject = 'TacmanMailer#new_account'
    @expected.body    = read_fixture('new_account')
    @expected.date    = Time.now

    assert_equal @expected.encoded, TacmanMailer.create_new_account(@expected.date).encoded
  end

  def test_password_expired
    @expected.subject = 'TacmanMailer#password_expired'
    @expected.body    = read_fixture('password_expired')
    @expected.date    = Time.now

    assert_equal @expected.encoded, TacmanMailer.create_password_expired(@expected.date).encoded
  end

  def test_pppppassword_reset
    @expected.subject = 'TacmanMailer#pppppassword_reset'
    @expected.body    = read_fixture('pppppassword_reset')
    @expected.date    = Time.now

    assert_equal @expected.encoded, TacmanMailer.create_pppppassword_reset(@expected.date).encoded
  end

  def test_pending_password_expiry
    @expected.subject = 'TacmanMailer#pending_password_expiry'
    @expected.body    = read_fixture('pending_password_expiry')
    @expected.date    = Time.now

    assert_equal @expected.encoded, TacmanMailer.create_pending_password_expiry(@expected.date).encoded
  end

  def test_pending_membership_requests
    @expected.subject = 'TacmanMailer#pending_membership_requests'
    @expected.body    = read_fixture('pending_membership_requests')
    @expected.date    = Time.now

    assert_equal @expected.encoded, TacmanMailer.create_pending_membership_requests(@expected.date).encoded
  end

  def test_logs
    @expected.subject = 'TacmanMailer#logs'
    @expected.body    = read_fixture('logs')
    @expected.date    = Time.now

    assert_equal @expected.encoded, TacmanMailer.create_logs(@expected.date).encoded
  end

end
