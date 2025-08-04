import Config

# Configure the endpoint
config :cryptun, Cryptun.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: Cryptun.ErrorHTML],
    layout: false
  ],
  pubsub_server: Cryptun.PubSub,
  live_view: [signing_salt: "cryptun_live_view_salt"],
  secret_key_base: "your_secret_key_base_here_in_production_use_a_real_one_that_is_at_least_64_characters_long"

# Configure Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config
import_config "#{config_env()}.exs"