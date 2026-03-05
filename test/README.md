# Test Suite

## Layout

- `test/omniauth_facebook2_test.rb`: strategy/unit tests
- `test/rails_integration_test.rb`: Rack/Rails integration flow tests

## Run

```bash
bundle exec rake test_unit
RAILS_VERSION='~> 8.1.0' bundle exec rake test_rails_integration
```
