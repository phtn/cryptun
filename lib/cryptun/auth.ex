defmodule Cryptun.Auth do
  @moduledoc """
  Authentication and authorization system for Cryptun.
  
  Manages API keys for tunnel creation and access control.
  """
  
  use GenServer
  require Logger
  
  defstruct api_keys: %{}, key_metadata: %{}
  
  ## Client API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  @doc """
  Generate a new API key with optional metadata.
  """
  def generate_api_key(metadata \\ %{}) do
    GenServer.call(__MODULE__, {:generate_api_key, metadata})
  end
  
  @doc """
  Validate an API key and return metadata if valid.
  """
  def validate_api_key(api_key) do
    GenServer.call(__MODULE__, {:validate_api_key, api_key})
  end
  
  @doc """
  Revoke an API key.
  """
  def revoke_api_key(api_key) do
    GenServer.call(__MODULE__, {:revoke_api_key, api_key})
  end
  
  @doc """
  List all active API keys with metadata.
  """
  def list_api_keys do
    GenServer.call(__MODULE__, :list_api_keys)
  end
  
  @doc """
  Get statistics about API key usage.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  ## Server Callbacks
  
  @impl true
  def init(_) do
    # Generate a default admin API key on startup
    admin_key = generate_secure_key()
    
    state = %__MODULE__{
      api_keys: %{admin_key => true},
      key_metadata: %{
        admin_key => %{
          name: "Admin Key",
          created_at: DateTime.utc_now(),
          last_used: nil,
          usage_count: 0,
          permissions: [:admin, :create_tunnel, :manage_keys]
        }
      }
    }
    
    Logger.info("Auth system started with admin key: #{admin_key}")
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:generate_api_key, metadata}, _from, state) do
    api_key = generate_secure_key()
    
    default_metadata = %{
      name: metadata[:name] || "Unnamed Key",
      created_at: DateTime.utc_now(),
      last_used: nil,
      usage_count: 0,
      permissions: metadata[:permissions] || [:create_tunnel]
    }
    
    final_metadata = Map.merge(default_metadata, metadata)
    
    state = %{state |
      api_keys: Map.put(state.api_keys, api_key, true),
      key_metadata: Map.put(state.key_metadata, api_key, final_metadata)
    }
    
    Logger.info("Generated new API key: #{String.slice(api_key, 0, 8)}...")
    
    {:reply, {:ok, api_key, final_metadata}, state}
  end
  
  @impl true
  def handle_call({:validate_api_key, api_key}, _from, state) do
    case Map.get(state.api_keys, api_key) do
      true ->
        # Update usage statistics
        metadata = Map.get(state.key_metadata, api_key, %{})
        updated_metadata = %{metadata |
          last_used: DateTime.utc_now(),
          usage_count: (metadata[:usage_count] || 0) + 1
        }
        
        state = %{state |
          key_metadata: Map.put(state.key_metadata, api_key, updated_metadata)
        }
        
        {:reply, {:ok, updated_metadata}, state}
      
      nil ->
        {:reply, {:error, :invalid_key}, state}
    end
  end
  
  @impl true
  def handle_call({:revoke_api_key, api_key}, _from, state) do
    case Map.get(state.api_keys, api_key) do
      true ->
        state = %{state |
          api_keys: Map.delete(state.api_keys, api_key),
          key_metadata: Map.delete(state.key_metadata, api_key)
        }
        
        Logger.info("Revoked API key: #{String.slice(api_key, 0, 8)}...")
        
        {:reply, :ok, state}
      
      nil ->
        {:reply, {:error, :key_not_found}, state}
    end
  end
  
  @impl true
  def handle_call(:list_api_keys, _from, state) do
    keys_with_metadata = 
      Enum.map(state.api_keys, fn {key, _active} ->
        metadata = Map.get(state.key_metadata, key, %{})
        %{
          key: key,
          key_preview: "#{String.slice(key, 0, 8)}...#{String.slice(key, -4, 4)}",
          metadata: metadata
        }
      end)
    
    {:reply, keys_with_metadata, state}
  end
  
  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      total_keys: map_size(state.api_keys),
      total_usage: Enum.sum(Enum.map(state.key_metadata, fn {_key, meta} -> 
        meta[:usage_count] || 0 
      end))
    }
    
    {:reply, stats, state}
  end
  
  ## Private Functions
  
  defp generate_secure_key do
    :crypto.strong_rand_bytes(32)
    |> Base.encode64(padding: false)
    |> String.replace(["+", "/"], ["_", "-"])
  end
  
  ## Public Helper Functions
  
  @doc """
  Extract API key from various sources (header, query param, etc.)
  """
  def extract_api_key(conn) do
    # Try Authorization header first
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> api_key] -> {:ok, api_key}
      ["Token " <> api_key] -> {:ok, api_key}
      _ ->
        # Try query parameter
        case conn.query_params["api_key"] do
          nil -> {:error, :no_api_key}
          api_key -> {:ok, api_key}
        end
    end
  end
  
  @doc """
  Check if an API key has a specific permission.
  """
  def has_permission?(api_key, permission) do
    case validate_api_key(api_key) do
      {:ok, metadata} ->
        permissions = metadata[:permissions] || []
        permission in permissions or :admin in permissions
      
      {:error, _} ->
        false
    end
  end
end