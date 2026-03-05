# frozen_string_literal: true

require 'base64'
require 'json'
require 'openssl'

module OmniAuth
  module Facebook2
    # Parser for Facebook signed request cookie payloads used by client-side login flow.
    class SignedRequest
      class UnknownSignatureAlgorithmError < NotImplementedError; end

      SUPPORTED_ALGORITHM = 'HMAC-SHA256'

      attr_reader :value, :secret

      def self.parse(value, secret)
        new(value, secret).payload
      end

      def initialize(value, secret)
        @value = value
        @secret = secret
      end

      def payload
        @payload ||= parse_signed_request
      end

      private

      def parse_signed_request
        signature, encoded_payload = value.to_s.split('.', 2)
        return if blank?(signature) || blank?(encoded_payload)

        decoded_signature = base64_decode_url(signature)
        decoded_payload = JSON.parse(base64_decode_url(encoded_payload))

        unless decoded_payload['algorithm'] == SUPPORTED_ALGORITHM
          raise UnknownSignatureAlgorithmError, "unknown algorithm: #{decoded_payload['algorithm']}"
        end

        decoded_payload if valid_signature?(decoded_signature, encoded_payload)
      end

      def valid_signature?(signature, payload, algorithm = OpenSSL::Digest.new('SHA256'))
        OpenSSL::HMAC.digest(algorithm, secret, payload) == signature
      end

      def base64_decode_url(value)
        value += '=' * ((4 - value.size.modulo(4)) % 4)
        Base64.decode64(value.tr('-_', '+/'))
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end
    end
  end
end
