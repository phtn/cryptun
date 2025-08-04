defmodule Cryptun do
  @moduledoc """
  Cryptun - A secure tunneling service built with Elixir/OTP.
  
  Cryptun allows you to expose local services to the internet through secure tunnels,
  similar to ngrok. Each tunnel gets a unique subdomain and routes HTTP requests
  to your local development server.
  
  ## Architecture
  
  - **Tunnel GenServer**: Manages individual tunnel state and request forwarding
  - **ClientManager**: Handles client connections and tunnel lifecycle  
  - **Gateway**: HTTP server that routes public requests to tunnels
  - **Registry**: Maps subdomains to tunnel processes
  
  ## Usage
  
  Start a test client:
  
      {:ok, _pid} = Cryptun.TestClient.start_link(local_port: 3000)
      {:ok, tunnel_info} = Cryptun.TestClient.connect()
      
  The tunnel_info will contain the public URL you can use to access your local service.
  """
  
  @doc """
  Start a test client that simulates a local service.
  """
  def start_test_client(local_port \\ 3000) do
    Cryptun.TestClient.start_link(local_port: local_port)
  end
  
  @doc """
  Get information about all active tunnels.
  """
  def list_tunnels do
    Registry.select(Cryptun.TunnelRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
    |> Enum.map(fn tunnel_id ->
      case Cryptun.ClientManager.get_tunnel_info(tunnel_id) do
        {:ok, info} -> info
        {:error, _} -> %{tunnel_id: tunnel_id, status: :error}
      end
    end)
  end
  
  @doc """
  Get the count of active tunnels.
  """
  def tunnel_count do
    Registry.count(Cryptun.TunnelRegistry)
  end
end
