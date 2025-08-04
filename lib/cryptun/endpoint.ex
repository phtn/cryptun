defmodule Cryptun.Endpoint do
  use Phoenix.Endpoint, otp_app: :cryptun

  @session_options [
    store: :cookie,
    key: "_cryptun_key",
    signing_salt: "cryptun_salt",
    same_site: "Lax"
  ]

  # Serve static files from priv/static
  plug Plug.Static,
    at: "/",
    from: :cryptun,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  # Parse request body
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  # LiveView socket
  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Cryptun.Router
end