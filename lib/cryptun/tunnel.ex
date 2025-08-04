defmodule Cryptun.Tunnel do
  @moduledoc """
  GenServer that manages an individual tunnel connection.
  
  Each tunnel:
  - Has a unique subdomain
  - Maintains connection to a client
  - Buffers incoming HTTP requests
  - Forwards requests to client and returns responses
  """
  
  use GenServer
  require Logger
  
  defstruct [
    :tunnel_id,
    :subdomain,
    :client_pid,
    :client_ref,
    pending_requests: %{},
    request_counter: 0
  ]
  
  ## Client API
  
  def start_link(opts) do
    tunnel_id = Keyword.fetch!(opts, :tunnel_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(tunnel_id))
  end
  
  def handle_request(tunnel_id, request) do
    GenServer.call(via_tuple(tunnel_id), {:handle_request, request}, 30_000)
  end
  
  def set_client(tunnel_id, client_pid) do
    GenServer.call(via_tuple(tunnel_id), {:set_client, client_pid})
  end
  
  def client_response(tunnel_id, request_id, response) do
    GenServer.cast(via_tuple(tunnel_id), {:client_response, request_id, response})
  end
  
  ## Server Callbacks
  
  @impl true
  def init(opts) do
    tunnel_id = Keyword.fetch!(opts, :tunnel_id)
    subdomain = Keyword.get(opts, :subdomain, generate_subdomain())
    
    state = %__MODULE__{
      tunnel_id: tunnel_id,
      subdomain: subdomain
    }
    
    Logger.info("Started tunnel #{tunnel_id} with subdomain #{subdomain}")
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:handle_request, request}, from, state) do
    case state.client_pid do
      nil ->
        {:reply, {:error, :no_client}, state}
      
      _client_pid ->
        request_id = state.request_counter + 1
        
        # Store the pending request
        pending_requests = Map.put(state.pending_requests, request_id, from)
        
        # Forward to client (this would be sent via WebSocket in real implementation)
        send(state.client_pid, {:tunnel_request, request_id, request})
        
        state = %{state | 
          pending_requests: pending_requests,
          request_counter: request_id
        }
        
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_call({:set_client, client_pid}, _from, state) do
    # Monitor the client process
    _ref = if state.client_ref, do: Process.demonitor(state.client_ref), else: nil
    new_ref = Process.monitor(client_pid)
    
    state = %{state | client_pid: client_pid, client_ref: new_ref}
    
    Logger.info("Client connected to tunnel #{state.tunnel_id}")
    
    {:reply, :ok, state}
  end
  
  @impl true
  def handle_cast({:client_response, request_id, response}, state) do
    case Map.pop(state.pending_requests, request_id) do
      {nil, _} ->
        Logger.warning("Received response for unknown request #{request_id}")
        {:noreply, state}
      
      {from, pending_requests} ->
        GenServer.reply(from, {:ok, response})
        state = %{state | pending_requests: pending_requests}
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{client_ref: ref} = state) do
    Logger.info("Client disconnected from tunnel #{state.tunnel_id}: #{inspect(reason)}")
    
    # Reply to all pending requests with error
    Enum.each(state.pending_requests, fn {_id, from} ->
      GenServer.reply(from, {:error, :client_disconnected})
    end)
    
    state = %{state | 
      client_pid: nil, 
      client_ref: nil,
      pending_requests: %{}
    }
    
    {:noreply, state}
  end
  
  ## Private Functions
  
  defp via_tuple(tunnel_id) do
    {:via, Registry, {Cryptun.TunnelRegistry, tunnel_id}}
  end
  
  defp generate_subdomain do
    :crypto.strong_rand_bytes(8)
    |> Base.encode32(case: :lower, padding: false)
  end
end