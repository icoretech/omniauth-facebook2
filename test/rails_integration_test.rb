# frozen_string_literal: true

require_relative 'test_helper'

require 'action_controller/railtie'
require 'json'
require 'logger'
require 'rack/test'
require 'rails'
require 'uri'
require 'webmock/minitest'

class RailsIntegrationSessionsController < ActionController::Base
  def create
    auth = request.env.fetch('omniauth.auth')
    render json: {
      uid: auth['uid'],
      name: auth.dig('info', 'name'),
      email: auth.dig('info', 'email')
    }
  end

  def failure
    render json: { error: params[:message] }, status: :unauthorized
  end
end

class RailsIntegrationApp < Rails::Application
  config.root = File.expand_path('..', __dir__)
  config.eager_load = false
  config.secret_key_base = 'facebook2-rails-integration-test-secret-key'
  config.active_support.cache_format_version = 7.1 if config.active_support.respond_to?(:cache_format_version=)

  if config.active_support.respond_to?(:to_time_preserves_timezone=) &&
     Rails.gem_version < Gem::Version.new('8.1.0')
    config.active_support.to_time_preserves_timezone = :zone
  end

  config.hosts.clear
  config.hosts << 'example.org'
  config.logger = Logger.new(nil)

  config.middleware.use OmniAuth::Builder do
    provider :facebook2, 'client-id', 'client-secret'
  end

  routes.append do
    match '/auth/:provider/callback', to: 'rails_integration_sessions#create', via: %i[get post]
    get '/auth/failure', to: 'rails_integration_sessions#failure'
  end
end

RailsIntegrationApp.initialize! unless RailsIntegrationApp.initialized?

class RailsIntegrationTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    super
    @previous_test_mode = OmniAuth.config.test_mode
    @previous_allowed_request_methods = OmniAuth.config.allowed_request_methods
    @previous_request_validation_phase = OmniAuth.config.request_validation_phase

    OmniAuth.config.test_mode = false
    OmniAuth.config.allowed_request_methods = [:post]
    OmniAuth.config.request_validation_phase = nil
  end

  def teardown
    OmniAuth.config.test_mode = @previous_test_mode
    OmniAuth.config.allowed_request_methods = @previous_allowed_request_methods
    OmniAuth.config.request_validation_phase = @previous_request_validation_phase
    WebMock.reset!
    super
  end

  def app
    RailsIntegrationApp
  end

  def test_rails_request_and_callback_flow_returns_expected_auth_payload
    stub_facebook_token_exchange
    stub_facebook_me

    post '/auth/facebook2'

    assert_equal 302, last_response.status

    authorize_uri = URI.parse(last_response['Location'])

    assert_equal 'www.facebook.com', authorize_uri.host
    assert_equal '/v25.0/dialog/oauth', authorize_uri.path

    state = URI.decode_www_form(authorize_uri.query).to_h.fetch('state')

    get '/auth/facebook2/callback', { code: 'oauth-test-code', state: state }

    assert_equal 200, last_response.status

    payload = JSON.parse(last_response.body)

    assert_equal '10230653256947200', payload['uid']
    assert_equal 'Claudio Poli', payload['name']
    assert_equal 'claudio@icorete.ch', payload['email']

    assert_requested :post, 'https://graph.facebook.com/v25.0/oauth/access_token', times: 1
    assert_requested :get, %r{\Ahttps://graph\.facebook\.com/v25\.0/me\?}, times: 1
  end

  def test_rails_callback_without_state_cookie_returns_csrf_detected
    get '/auth/facebook2/callback', { code: 'oauth-test-code', state: 'abc123' }

    assert_equal 302, last_response.status

    failure_uri = URI.parse(last_response['Location'])
    failure_params = URI.decode_www_form(failure_uri.query.to_s).to_h

    assert_equal '/auth/failure', failure_uri.path
    assert_equal 'csrf_detected', failure_params['message']
  end

  private

  def stub_facebook_token_exchange
    stub_request(:post, 'https://graph.facebook.com/v25.0/oauth/access_token').to_return(
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: {
        access_token: 'access-token',
        token_type: 'Bearer',
        expires_in: 3600,
        scope: 'email,public_profile'
      }.to_json
    )
  end

  def stub_facebook_me
    stub_request(:get, 'https://graph.facebook.com/v25.0/me')
      .with(query: hash_including('fields' => 'name,email'))
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          id: '10230653256947200',
          name: 'Claudio Poli',
          email: 'claudio@icorete.ch'
        }.to_json
      )
  end
end
