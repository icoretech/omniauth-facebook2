# frozen_string_literal: true

require 'omniauth-oauth2'
require 'openssl'
require 'rack/utils'
require 'uri'

module OmniAuth
  module Strategies
    # OmniAuth strategy for Facebook OAuth2.
    class Facebook2 < OmniAuth::Strategies::OAuth2
      class NoAuthorizationCodeError < StandardError; end

      DEFAULT_SCOPE = 'email'
      DEFAULT_FACEBOOK_API_VERSION = 'v25.0'
      DEFAULT_INFO_FIELDS = 'name,email'
      DEFAULT_TOKEN_URL = 'oauth/access_token'

      option :name, 'facebook2'
      option :scope, DEFAULT_SCOPE
      option :api_version, DEFAULT_FACEBOOK_API_VERSION
      option :authorize_options, %i[scope display auth_type config_id redirect_uri]
      option :secure_image_url, true
      option :appsecret_proof, true
      option :authorization_code_from_signed_request_in_cookie, nil

      option :client_options,
             site: "https://graph.facebook.com/#{DEFAULT_FACEBOOK_API_VERSION}",
             authorize_url: "https://www.facebook.com/#{DEFAULT_FACEBOOK_API_VERSION}/dialog/oauth",
             token_url: DEFAULT_TOKEN_URL,
             connection_opts: {
               headers: {
                 user_agent: 'icoretech-omniauth-facebook2 gem',
                 accept: 'application/json',
                 content_type: 'application/json'
               }
             }

      option :access_token_options,
             header_format: 'OAuth %s',
             param_name: 'access_token'

      uid { raw_info['id'] }

      info do
        prune(
          {
            'nickname' => raw_info['username'],
            'email' => raw_info['email'],
            'name' => raw_info['name'],
            'first_name' => raw_info['first_name'],
            'last_name' => raw_info['last_name'],
            'image' => image_url(uid),
            'description' => raw_info['bio'],
            'urls' => {
              'Facebook' => raw_info['link'],
              'Website' => raw_info['website']
            },
            'location' => raw_info.dig('location', 'name'),
            'verified' => raw_info['verified']
          }
        )
      end

      credentials do
        {
          'token' => access_token.token,
          'refresh_token' => access_token.refresh_token,
          'expires_at' => access_token.expires_at,
          'expires' => access_token.expires?,
          'scope' => token_scope
        }.compact
      end

      extra do
        data = {}
        data['raw_info'] = raw_info unless skip_info?
        prune(data)
      end

      def raw_info
        @raw_info ||= access_token.get('me', info_options).parsed || {}
      end

      def info_options
        params = {
          fields: options[:info_fields] || DEFAULT_INFO_FIELDS
        }
        params[:appsecret_proof] = appsecret_proof if options[:appsecret_proof]
        params[:locale] = options[:locale] if options[:locale]

        { params: params }
      end

      def callback_phase
        return fail_state_mismatch if missing_session_state?

        with_authorization_code! { super }
      rescue NoAuthorizationCodeError => e
        fail!(:no_authorization_code, e)
      rescue OmniAuth::Facebook2::SignedRequest::UnknownSignatureAlgorithmError => e
        fail!(:unknown_signature_algorithm, e)
      rescue NoMethodError => e
        raise unless oauth_state_nil_compare_error?(e)

        fail_state_mismatch
      end

      def client
        @client ||= ::OAuth2::Client.new(
          options.client_id,
          options.client_secret,
          deep_symbolize(normalized_client_options)
        )
      end

      def callback_url
        return '' if options.authorization_code_from_signed_request_in_cookie

        options[:callback_url] || super
      end

      def query_string
        return '' if request.params['code']

        super
      end

      def access_token_options
        options.access_token_options.to_h.transform_keys(&:to_sym)
      end

      def authorize_params
        super.tap do |params|
          options.authorize_options.each do |key|
            request_value = request.params[key.to_s]
            params[key] = request_value unless blank?(request_value)
          end

          params[:scope] ||= options[:scope] || DEFAULT_SCOPE
        end
      end

      protected

      def build_access_token
        super.tap do |token|
          token.options.merge!(access_token_options)
        end
      end

      private

      def signed_request_from_cookie
        @signed_request_from_cookie ||= begin
          signed_request = raw_signed_request_from_cookie
          signed_request && OmniAuth::Facebook2::SignedRequest.parse(signed_request, client.secret)
        end
      end

      def raw_signed_request_from_cookie
        request.cookies["fbsr_#{client.id}"]
      end

      def with_authorization_code!
        if request.params.key?('code') && !blank?(request.params['code'])
          yield
        elsif (code_from_signed_request = signed_request_from_cookie && signed_request_from_cookie['code'])
          request.params['code'] = code_from_signed_request
          options.authorization_code_from_signed_request_in_cookie = true
          original_provider_ignores_state = options.provider_ignores_state
          options.provider_ignores_state = true

          begin
            yield
          ensure
            request.params.delete('code')
            options.authorization_code_from_signed_request_in_cookie = false
            options.provider_ignores_state = original_provider_ignores_state
          end
        else
          raise NoAuthorizationCodeError,
                'must pass either a `code` (query param) or an `fbsr_<app_id>` signed request cookie'
        end
      end

      def prune(hash)
        return hash unless hash.is_a?(Hash)

        hash.delete_if do |_key, value|
          prune(value) if value.is_a?(Hash)
          value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
      end

      def image_url(user_id)
        uri_class = options[:secure_image_url] ? URI::HTTPS : URI::HTTP
        site_uri = URI.parse(client.site)
        url = uri_class.build(host: site_uri.host, path: "#{site_uri.path}/#{user_id}/picture")

        query = if options[:image_size].is_a?(String) || options[:image_size].is_a?(Symbol)
                  { type: options[:image_size] }
                elsif options[:image_size].is_a?(Hash)
                  options[:image_size]
                end
        url.query = Rack::Utils.build_query(query) if query

        url.to_s
      end

      def appsecret_proof
        @appsecret_proof ||= OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('SHA256'), client.secret, access_token.token)
      end

      def token_scope
        token_params = access_token.respond_to?(:params) ? access_token.params : {}
        token_params['scope'] || (access_token['scope'] if access_token.respond_to?(:[]))
      end

      def missing_session_state?
        present?(request.params['state']) && blank?(session['omniauth.state'])
      end

      def oauth_state_nil_compare_error?(error)
        error.message.include?("undefined method 'bytesize' for nil")
      end

      def fail_state_mismatch
        fail!(
          :csrf_detected,
          OmniAuth::Strategies::OAuth2::CallbackError.new(:csrf_detected, 'OAuth state was missing or mismatched')
        )
      end

      def normalized_client_options
        client_options = options.client_options.to_h.transform_keys(&:to_sym)
        version = options[:api_version]
        return client_options if blank?(version)

        current_site = client_options[:site]
        current_authorize_url = client_options[:authorize_url]
        current_token_url = client_options[:token_url]
        default_site = graph_site_for(DEFAULT_FACEBOOK_API_VERSION)
        default_authorize_url = authorize_url_for(DEFAULT_FACEBOOK_API_VERSION)

        client_options[:site] = graph_site_for(version) if default_endpoint?(current_site, default_site)
        if default_endpoint?(current_authorize_url, default_authorize_url)
          client_options[:authorize_url] = authorize_url_for(version)
        end
        client_options[:token_url] = DEFAULT_TOKEN_URL if blank?(current_token_url)

        client_options
      end

      def graph_site_for(version)
        "https://graph.facebook.com/#{version}"
      end

      def authorize_url_for(version)
        "https://www.facebook.com/#{version}/dialog/oauth"
      end

      def default_endpoint?(value, default_value)
        blank?(value) || value == default_value
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end

      def present?(value)
        !blank?(value)
      end
    end

    # Backward-compatible strategy name for existing `facebook` callback paths.
    class Facebook < Facebook2
      option :name, 'facebook'
    end
  end
end

OmniAuth.config.add_camelization 'facebook2', 'Facebook2'
OmniAuth.config.add_camelization 'facebook', 'Facebook'
