import Config

# Runtime configuration for releases
if config_env() == :prod do
  # Get configuration from environment variables
  dashboard_port = String.to_integer(System.get_env("CRYPTUN_DASHBOARD_PORT") || "4000")
  gateway_port = String.to_integer(System.get_env("CRYPTUN_GATEWAY_PORT") || "4001")
  
  # Generate or get secret key base
  secret_key_base = 
    System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

  config :cryptun,
    dashboard_port: dashboard_port,
    gateway_port: gateway_port,
    secret_key_base: secret_key_base

  # Configure logger for production
  config :logger,
    level: :info,
    backends: [:console],
    compile_time_purge_matching: [
      [level_lower_than: :info]
    ]
end