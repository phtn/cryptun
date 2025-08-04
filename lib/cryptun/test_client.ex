defmodule Cryptun.TestClient do
  @moduledoc """
  A simple test client that demonstrates how to connect to the tunnel service.
  
  This simulates a client that would run locally and forward requests to a local service.
  """
  
  use GenServer
  require Logger
  
  defstruct [:websocket_pid, :tunnel_info, :local_port]
  
  def start_link(opts \\ []) do
    local_port = Keyword.get(opts, :local_port, 3000)
    GenServer.start_link(__MODULE__, %{local_port: local_port}, name: __MODULE__)
  end
  
  def connect do
    GenServer.call(__MODULE__, :connect)
  end
  
  def get_tunnel_info do
    GenServer.call(__MODULE__, :get_tunnel_info)
  end
  
  ## Server Callbacks
  
  @impl true
  def init(state) do
    {:ok, struct(__MODULE__, state)}
  end
  
  @impl true
  def handle_call(:connect, _from, state) do
    # In a real implementation, this would establish a WebSocket connection
    # For now, we'll simulate it by creating a tunnel directly
    case Cryptun.ClientManager.create_tunnel(self()) do
      {:ok, tunnel_info} ->
        Logger.info("Connected to tunnel service: #{tunnel_info.public_url}")
        
        state = %{state | tunnel_info: tunnel_info}
        {:reply, {:ok, tunnel_info}, state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call(:get_tunnel_info, _from, state) do
    {:reply, state.tunnel_info, state}
  end
  
  @impl true
  def handle_info({:tunnel_request, request_id, request}, state) do
    Logger.info("Received request #{request_id}: #{request.method} #{request.path}")
    
    # Simulate forwarding to local service and getting a response
    response = simulate_local_response(request, state.local_port)
    
    # Send response back to tunnel
    case state.tunnel_info do
      %{tunnel_id: tunnel_id} ->
        Cryptun.Tunnel.client_response(tunnel_id, request_id, response)
      
      nil ->
        Logger.error("No tunnel info available to send response")
    end
    
    {:noreply, state}
  end
  
  ## Private Functions
  
  defp simulate_local_response(request, local_port) do
    # This simulates what a real client would do:
    # 1. Make HTTP request to localhost:local_port
    # 2. Return the response
    
    # For demo purposes, return a simple response
    %{
      status: 200,
      headers: [{"content-type", "text/html"}],
      body: """
      <html>
        <body>
          <h1>Hello from Cryptun!</h1>
          <p>This response was tunneled from localhost:#{local_port}</p>
          <p>Original request: #{request.method} #{request.path}</p>
          <p>Query: #{request.query_string}</p>
        </body>
      </html>
      """
    }
  end
end