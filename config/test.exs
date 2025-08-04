import Config

# Configure the endpoint for testing
config :cryptun, Cryptun.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_that_is_long_enough_for_testing_purposes_only",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning