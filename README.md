# OmniAuth Facebook2 Strategy

[![Test](https://github.com/icoretech/omniauth-facebook2/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/icoretech/omniauth-facebook2/actions/workflows/test.yml?query=branch%3Amain)
[![Gem Version](https://img.shields.io/gem/v/omniauth-facebook2.svg)](https://rubygems.org/gems/omniauth-facebook2)

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
           ENV.fetch('FACEBOOK_APP_SECRET')
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
- `display`
- `auth_type` (example: `rerequest`)
- `config_id` (Facebook Login for Business)
- `redirect_uri`
- `info_fields` (default: `name,email`)
- `locale`
- `image_size` (symbol/string like `:normal`, or hash `{ width:, height: }`)
- `secure_image_url` (default: `true`)
- `callback_url` / `callback_path`

## Auth Hash

Example payload from `request.env['omniauth.auth']` (captured from a real smoke run):

```json
{
  "uid": "10230653256947200",
  "info": {
    "email": "claudio@icorete.ch",
    "name": "Claudio Poli",
    "image": "https://graph.facebook.com/v25.0/10230653256947200/picture"
  },
  "credentials": {
    "token": "[REDACTED]",
    "expires_at": 1777885934,
    "expires": true
  },
  "extra": {
    "raw_info": {
      "name": "Claudio Poli",
      "email": "claudio@icorete.ch",
      "id": "10230653256947200"
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
- `omniauth-oauth2`: `>= 1.8`, `< 1.9`
- Rails integration lanes: `~> 7.1.0`, `~> 7.2.0`, `~> 8.0.0`, `~> 8.1.0`

## Endpoints

Default endpoints target Facebook Graph API `v25.0`:

- Authorize: `https://www.facebook.com/v25.0/dialog/oauth`
- Token: `https://graph.facebook.com/v25.0/oauth/access_token`
- User info: `https://graph.facebook.com/v25.0/me`

## Test Structure

- `test/omniauth_facebook2_test.rb`: strategy/unit behavior
- `test/rails_integration_test.rb`: full Rack/Rails request+callback flow
- `test/test_helper.rb`: shared test bootstrap

## Release

Tag releases as `vX.Y.Z`; GitHub Actions publishes the gem to RubyGems.

## License

MIT
