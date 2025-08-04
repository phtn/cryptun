defmodule Cryptun.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # PubSub for real-time updates
      {Phoenix.PubSub, name: Cryptun.PubSub},
      
      # Registry for tunnel routing
      {Registry, keys: :unique, name: Cryptun.TunnelRegistry},
      
      # Dynamic supervisor for tunnel processes
      {DynamicSupervisor, strategy: :one_for_one, name: Cryptun.TunnelSupervisor},
      
      # Client connection manager
      Cryptun.ClientManager,
      
      # Simple web dashboard
      {Plug.Cowboy, scheme: :http, plug: Cryptun.SimpleWeb, options: [port: 4000]},
      
      # HTTP Gateway server (on different port)
      {Plug.Cowboy, scheme: :http, plug: Cryptun.Gateway, options: [port: 4001]}
    ]

    opts = [strategy: :one_for_one, name: Cryptun.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
