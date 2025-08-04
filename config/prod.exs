import Config

# Configure the endpoint for production
config :cryptun, Cryptun.Endpoint,
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json"

# Production configuration for Cryptun
config :cryptun,
  dashboard_port: String.to_integer(System.get_env("CRYPTUN_DASHBOARD_PORT") || "4000"),
  gateway_port: String.to_integer(System.get_env("CRYPTUN_GATEWAY_PORT") || "4001"),
  secret_key_base: System.get_env("SECRET_KEY_BASE") || :crypto.strong_rand_bytes(64) |> Base.encode64()

# Do not print debug messages in production
config :logger, level: :info

# Runtime configuration will be handled in releases.exs