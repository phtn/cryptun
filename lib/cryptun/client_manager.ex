defmodule Cryptun.ClientManager do
  @moduledoc """
  GenServer that manages client WebSocket connections and tunnel lifecycle.
  """
  
  use GenServer
  require Logger
  
  ## Client API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  def create_tunnel(client_pid, api_key \\ nil) do
    GenServer.call(__MODULE__, {:create_tunnel, client_pid, api_key})
  end
  
  def get_tunnel_info(tunnel_id) do
    GenServer.call(__MODULE__, {:get_tunnel_info, tunnel_id})
  end
  
  ## Server Callbacks
  
  @impl true
  def init(_) do
    Logger.info("ClientManager started")
    {:ok, %{}}
  end
  
  @impl true
  def handle_call({:create_tunnel, client_pid, api_key}, _from, state) do
    # Validate API key if provided
    case validate_tunnel_creation(api_key) do
      :ok ->
        tunnel_id = generate_tunnel_id()
        
        case DynamicSupervisor.start_child(
          Cryptun.TunnelSupervisor,
          {Cryptun.Tunnel, [tunnel_id: tunnel_id, api_key: api_key]}
        ) do
          {:ok, _tunnel_pid} ->
            # Set the client for this tunnel
            :ok = Cryptun.Tunnel.set_client(tunnel_id, client_pid)
            
            # Get tunnel info
            case Registry.lookup(Cryptun.TunnelRegistry, tunnel_id) do
              [{_tunnel_pid, _}] ->
                # In a real implementation, you'd get the subdomain from the tunnel state
                subdomain = "tunnel-#{tunnel_id}"
                
                tunnel_info = %{
                  tunnel_id: tunnel_id,
                  subdomain: subdomain,
                  public_url: "http://#{subdomain}.localhost:4001",
                  api_key: api_key
                }
                
                Logger.info("Created tunnel #{tunnel_id} for client #{inspect(client_pid)}")
                
                {:reply, {:ok, tunnel_info}, state}
              
              [] ->
                {:reply, {:error, :tunnel_not_found}, state}
            end
          
          {:error, reason} ->
            Logger.error("Failed to create tunnel: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
      
      {:error, reason} ->
        Logger.warning("Tunnel creation denied: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:get_tunnel_info, tunnel_id}, _from, state) do
    case Registry.lookup(Cryptun.TunnelRegistry, tunnel_id) do
      [{_tunnel_pid, _}] ->
        tunnel_info = %{
          tunnel_id: tunnel_id,
          subdomain: "tunnel-#{tunnel_id}",
          public_url: "http://tunnel-#{tunnel_id}.localhost:4000"
        }
        {:reply, {:ok, tunnel_info}, state}
      
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end
  
  ## Private Functions
  
  defp validate_tunnel_creation(nil) do
    # Allow tunnel creation without API key for now (backward compatibility)
    :ok
  end
  
  defp validate_tunnel_creation(api_key) do
    case Cryptun.Auth.has_permission?(api_key, :create_tunnel) do
      true -> :ok
      false -> {:error, :insufficient_permissions}
    end
  end
  
  defp generate_tunnel_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end
end