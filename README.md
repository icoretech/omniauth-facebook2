# OmniAuth Facebook Strategy

[![Test](https://github.com/icoretech/omniauth-facebook2/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/icoretech/omniauth-facebook2/actions/workflows/test.yml?query=branch%3Amain)
[![Gem Version](https://badge.fury.io/rb/omniauth-facebook2.svg)](https://badge.fury.io/rb/omniauth-facebook2)

`omniauth-facebook2` provides a Facebook OAuth2 strategy for OmniAuth.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'omniauth-facebook2'
```

Then run:

```bash
bundle install
```

## Usage

Configure OmniAuth in your Rack/Rails app:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook2,
           ENV.fetch('FACEBOOK_APP_ID'),
           ENV.fetch('FACEBOOK_APP_SECRET'),
           api_version: 'v26.0' # optional; default is v25.0
end
```

Compatibility alias is available, so existing callback paths can keep using `facebook`:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook,
           ENV.fetch('FACEBOOK_APP_ID'),
           ENV.fetch('FACEBOOK_APP_SECRET')
end
```

## Provider App Setup

- Meta for Developers: <https://developers.facebook.com/apps/>
- Facebook Login docs: <https://developers.facebook.com/docs/facebook-login/>
- Register callback URL (example): `https://your-app.example.com/auth/facebook/callback`

## Options

Supported request/provider options include:

- `scope` (default: `email`)
- `api_version` (default: `v25.0`)
- `display`
- `auth_type` (example: `rerequest`)
- `config_id` (Facebook Login for Business)
- `redirect_uri`
- `info_fields` (default: `name,email`)
- `locale`
- `image_size` (symbol/string like `:normal`, or hash `{ width:, height: }`)
- `secure_image_url` (default: `true`)
- `callback_url` / `callback_path`

If you need full endpoint control, `client_options` still works and takes precedence over `api_version`:

```ruby
provider :facebook2,
         ENV.fetch('FACEBOOK_APP_ID'),
         ENV.fetch('FACEBOOK_APP_SECRET'),
         client_options: {
           site: 'https://graph.facebook.com/v26.0',
           authorize_url: 'https://www.facebook.com/v26.0/dialog/oauth',
           token_url: 'oauth/access_token'
         }
```

## Auth Hash

Example payload from `request.env['omniauth.auth']` (captured from a real smoke run):

```json
{
  "uid": "12345678901234567",
  "info": {
    "email": "sample.user@example.test",
    "name": "Sample User",
    "image": "https://graph.facebook.com/v25.0/12345678901234567/picture"
  },
  "credentials": {
    "token": "[REDACTED]",
    "expires_at": 1777885934,
    "expires": true
  },
  "extra": {
    "raw_info": {
      "name": "Sample User",
      "email": "sample.user@example.test",
      "id": "12345678901234567"
    }
  }
}
```

## Development

```bash
bundle install
bundle exec rake
```

Run Rails integration tests with an explicit Rails version:

```bash
RAILS_VERSION='~> 8.1.0' bundle install
RAILS_VERSION='~> 8.1.0' bundle exec rake test_rails_integration
```

## Compatibility

- Ruby: `>= 3.2` (tested on `3.2`, `3.3`, `3.4`, `4.0`)
- `omniauth-oauth2`: `>= 1.8`, `< 2.0`
- Rails integration lanes: `~> 7.1.0`, `~> 7.2.0`, `~> 8.0.0`, `~> 8.1.0`

## Endpoints

Default endpoints target Facebook Graph API `v25.0` (or `vX.Y` set via `api_version`):

- Authorize: `https://www.facebook.com/vX.Y/dialog/oauth`
- Token: `https://graph.facebook.com/vX.Y/oauth/access_token`
- User info: `https://graph.facebook.com/vX.Y/me`

## Test Structure

- `test/omniauth_facebook2_test.rb`: strategy/unit behavior
- `test/rails_integration_test.rb`: full Rack/Rails request+callback flow
- `test/test_helper.rb`: shared test bootstrap

## Release

Tag releases as `vX.Y.Z`; GitHub Actions publishes the gem to RubyGems.

## License

MIT
