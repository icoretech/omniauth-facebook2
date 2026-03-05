# frozen_string_literal: true

require_relative 'test_helper'

require 'json'
require 'openssl'
require 'uri'

class OmniauthFacebook2Test < Minitest::Test
  def build_strategy(klass = OmniAuth::Strategies::Facebook2)
    klass.new(nil, 'client-id', 'client-secret')
  end

  def test_uses_current_facebook_endpoints
    client_options = build_strategy.options.client_options

    assert_equal 'https://graph.facebook.com/v25.0', client_options.site
    assert_equal 'https://www.facebook.com/v25.0/dialog/oauth', client_options.authorize_url
    assert_equal 'oauth/access_token', client_options.token_url
  end

  def test_alias_strategy_keeps_legacy_provider_name
    legacy = build_strategy(OmniAuth::Strategies::Facebook)

    assert_equal 'facebook', legacy.options.name
  end

  def test_api_version_updates_default_endpoints
    previous_request_validation_phase = OmniAuth.config.request_validation_phase
    OmniAuth.config.request_validation_phase = nil

    app = ->(_env) { [404, { 'Content-Type' => 'text/plain' }, ['not found']] }
    strategy = OmniAuth::Strategies::Facebook2.new(
      app,
      'client-id',
      'client-secret',
      api_version: 'v26.0'
    )
    env = Rack::MockRequest.env_for('/auth/facebook2', method: 'POST')
    env['rack.session'] = {}

    status, headers, = strategy.call(env)

    assert_equal 302, status

    location = URI.parse(headers.fetch('Location'))

    assert_equal '/v26.0/dialog/oauth', location.path
    assert_equal 'https://graph.facebook.com/v26.0', strategy.client.site
  ensure
    OmniAuth.config.request_validation_phase = previous_request_validation_phase
  end

  def test_api_version_does_not_override_explicit_custom_endpoints
    previous_request_validation_phase = OmniAuth.config.request_validation_phase
    OmniAuth.config.request_validation_phase = nil

    app = ->(_env) { [404, { 'Content-Type' => 'text/plain' }, ['not found']] }
    strategy = OmniAuth::Strategies::Facebook2.new(
      app,
      'client-id',
      'client-secret',
      api_version: 'v26.0',
      client_options: {
        site: 'https://graph.facebook.com/custom',
        authorize_url: 'https://www.facebook.com/custom/dialog/oauth',
        token_url: 'oauth/access_token'
      }
    )
    env = Rack::MockRequest.env_for('/auth/facebook2', method: 'POST')
    env['rack.session'] = {}

    status, headers, = strategy.call(env)

    assert_equal 302, status

    location = URI.parse(headers.fetch('Location'))

    assert_equal '/custom/dialog/oauth', location.path
    assert_equal 'https://graph.facebook.com/custom', strategy.client.site
  ensure
    OmniAuth.config.request_validation_phase = previous_request_validation_phase
  end

  def test_authorize_params_support_request_overrides
    strategy = build_strategy
    request = Rack::Request.new(
      Rack::MockRequest.env_for(
        '/auth/facebook2?' \
        'scope=email,public_profile&display=popup&auth_type=rerequest&config_id=cfg123' \
        '&redirect_uri=https%3A%2F%2Fexample.test%2Fauth%2Ffacebook2%2Fcallback'
      )
    )

    strategy.define_singleton_method(:request) { request }
    strategy.define_singleton_method(:session) { {} }

    params = strategy.authorize_params

    assert_equal 'email,public_profile', params[:scope]
    assert_equal 'popup', params[:display]
    assert_equal 'rerequest', params[:auth_type]
    assert_equal 'cfg123', params[:config_id]
    assert_equal 'https://example.test/auth/facebook2/callback', params[:redirect_uri]
  end

  def test_authorize_params_include_default_scope
    strategy = build_strategy
    request = Rack::Request.new(Rack::MockRequest.env_for('/auth/facebook2'))

    strategy.define_singleton_method(:request) { request }
    strategy.define_singleton_method(:session) { {} }

    params = strategy.authorize_params

    assert_equal 'email', params[:scope]
  end

  def test_uid_info_credentials_and_extra_are_derived_from_raw_info
    strategy = build_strategy
    raw_info = {
      'id' => '12345678901234567',
      'name' => 'Sample User',
      'email' => 'sample.user@example.test'
    }

    token = FakeAccessToken.new(raw_info)
    strategy.define_singleton_method(:access_token) { token }

    assert_equal '12345678901234567', strategy.uid
    assert_equal 'Sample User', strategy.info['name']
    assert_equal 'sample.user@example.test', strategy.info['email']
    assert_equal 'https://graph.facebook.com/v25.0/12345678901234567/picture', strategy.info['image']

    assert_equal(
      {
        'token' => 'access-token',
        'refresh_token' => 'refresh-token',
        'expires_at' => 1_772_691_847,
        'expires' => true,
        'scope' => 'email,public_profile'
      },
      strategy.credentials
    )

    assert_equal raw_info, strategy.extra['raw_info']
  end

  def test_image_size_options_are_applied_to_image_url
    strategy = build_strategy
    strategy.options[:image_size] = :normal
    token = FakeAccessToken.new({ 'id' => '123', 'name' => 'Sample User' })
    strategy.define_singleton_method(:access_token) { token }

    assert_equal 'https://graph.facebook.com/v25.0/123/picture?type=normal', strategy.info['image']

    strategy.options[:image_size] = { width: 80, height: 80 }

    image_url = strategy.info['image']

    assert_includes image_url, 'width=80'
    assert_includes image_url, 'height=80'
  end

  def test_callback_url_prefers_explicit_callback_url
    strategy = build_strategy
    callback = 'https://example.test/auth/facebook2/callback'
    strategy.options[:callback_url] = callback

    assert_equal callback, strategy.callback_url
  end

  def test_callback_url_is_blank_when_using_signed_request_cookie
    strategy = build_strategy
    strategy.options.authorization_code_from_signed_request_in_cookie = true

    assert_equal '', strategy.callback_url
  end

  def test_query_string_is_ignored_during_callback_request
    strategy = build_strategy
    request = Rack::Request.new(Rack::MockRequest.env_for('/auth/facebook2/callback?code=abc&state=xyz'))
    strategy.define_singleton_method(:request) { request }

    assert_equal '', strategy.query_string
  end

  def test_raw_info_requests_me_with_expected_params
    strategy = build_strategy
    token = RecordingAccessToken.new('client-secret')
    strategy.define_singleton_method(:access_token) { token }

    payload = strategy.raw_info

    assert_equal '1234567890', payload['id']
    assert_equal 'me', token.last_get_path
    assert_equal 'name,email', token.last_get_options.dig(:params, :fields)
    assert_equal expected_appsecret_proof, token.last_get_options.dig(:params, :appsecret_proof)
  end

  def test_raw_info_supports_custom_fields_and_locale
    strategy = build_strategy
    strategy.options[:info_fields] = 'name,email,link'
    strategy.options[:locale] = 'it_IT'
    token = RecordingAccessToken.new('client-secret')
    strategy.define_singleton_method(:access_token) { token }

    strategy.raw_info

    assert_equal 'name,email,link', token.last_get_options.dig(:params, :fields)
    assert_equal 'it_IT', token.last_get_options.dig(:params, :locale)
  end

  def test_request_phase_redirects_to_facebook_with_expected_params
    previous_request_validation_phase = OmniAuth.config.request_validation_phase
    OmniAuth.config.request_validation_phase = nil

    app = ->(_env) { [404, { 'Content-Type' => 'text/plain' }, ['not found']] }
    strategy = OmniAuth::Strategies::Facebook2.new(app, 'client-id', 'client-secret')
    env = Rack::MockRequest.env_for('/auth/facebook2', method: 'POST')
    env['rack.session'] = {}

    status, headers, = strategy.call(env)

    assert_equal 302, status

    location = URI.parse(headers.fetch('Location'))
    params = URI.decode_www_form(location.query).to_h

    assert_equal 'www.facebook.com', location.host
    assert_equal '/v25.0/dialog/oauth', location.path
    assert_equal 'client-id', params.fetch('client_id')
    assert_equal 'email', params.fetch('scope')
  ensure
    OmniAuth.config.request_validation_phase = previous_request_validation_phase
  end

  def test_missing_state_cookie_fails_with_csrf_detected
    app = ->(_env) { [404, { 'Content-Type' => 'text/plain' }, ['not found']] }
    strategy = OmniAuth::Strategies::Facebook2.new(app, 'client-id', 'client-secret')
    env = Rack::MockRequest.env_for('/auth/facebook2/callback?code=abc&state=xyz')
    env['rack.session'] = {}

    status, headers, = strategy.call(env)

    assert_equal 302, status
    assert_includes headers.fetch('Location'), '/auth/failure'
    assert_includes headers.fetch('Location'), 'message=csrf_detected'
  end

  private

  def expected_appsecret_proof
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('SHA256'), 'client-secret', 'access-token')
  end

  class FakeAccessToken
    attr_reader :params, :token, :refresh_token, :expires_at

    def initialize(parsed_payload)
      @parsed_payload = parsed_payload
      @params = {
        'scope' => 'email,public_profile'
      }
      @token = 'access-token'
      @refresh_token = 'refresh-token'
      @expires_at = 1_772_691_847
    end

    def get(_path, _options = nil)
      Struct.new(:parsed).new(@parsed_payload)
    end

    def [](key)
      { 'scope' => params['scope'] }[key]
    end

    def expires?
      true
    end
  end

  class RecordingAccessToken
    attr_reader :params, :token, :refresh_token, :expires_at, :last_get_path, :last_get_options

    def initialize(_secret)
      @params = {
        'scope' => 'email,public_profile'
      }
      @token = 'access-token'
      @refresh_token = 'refresh-token'
      @expires_at = 1_772_691_847
      @last_get_path = nil
      @last_get_options = nil
    end

    def get(path, options = nil)
      @last_get_path = path
      @last_get_options = options
      Struct.new(:parsed).new(
        {
          'id' => '1234567890',
          'name' => 'Sample User',
          'email' => 'sample@example.test'
        }
      )
    end

    def [](key)
      { 'scope' => params['scope'] }[key]
    end

    def expires?
      true
    end
  end
end
