# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'omniauth/facebook2/version'

Gem::Specification.new do |spec|
  spec.name = 'omniauth-facebook2'
  spec.version = OmniAuth::Facebook2::VERSION
  spec.authors = ['Claudio Poli']
  spec.email = ['masterkain@gmail.com']

  spec.summary = 'OmniAuth strategy for Facebook OAuth2 authentication.'
  spec.description =
    'OAuth2 strategy for OmniAuth that authenticates users with Facebook ' \
    'and exposes profile metadata from the Graph API.'
  spec.homepage = 'https://github.com/icoretech/omniauth-facebook2'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.metadata['source_code_uri'] = 'https://github.com/icoretech/omniauth-facebook2'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/icoretech/omniauth-facebook2/issues'
  spec.metadata['changelog_uri'] = 'https://github.com/icoretech/omniauth-facebook2/releases'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir[
    'lib/**/*.rb',
    'README*',
    'LICENSE*',
    '*.gemspec'
  ]
  spec.require_paths = ['lib']

  spec.add_dependency 'cgi', '>= 0.3.6'
  spec.add_dependency 'omniauth-oauth2', '>= 1.8', '< 2.0'
end
