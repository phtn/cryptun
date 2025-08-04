defmodule Cryptun.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Cryptun.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", Cryptun do
    pipe_through :browser

    live "/", DashboardLive
    live "/tunnels", TunnelListLive
  end
end