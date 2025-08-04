defmodule Cryptun.WebSocketHandler do
  @moduledoc """
  WebSocket handler for client connections.
  
  This handles the WebSocket protocol for tunnel clients to connect
  and receive HTTP requests to forward to their local services.
  """
  
  @behaviour :cowboy_websocket
  require Logger
  
  def init(req, _state) do
    {:cowboy_websocket, req, %{tunnel_info: nil}}
  end
  
  def websocket_init(state) do
    Logger.info("WebSocket client connected")
    {:ok, state}
  end
  
  def websocket_handle({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, %{"type" => "create_tunnel"}} ->
        handle_create_tunnel(state)
      
      {:ok, %{"type" => "response", "request_id" => request_id, "response" => response}} ->
        handle_client_response(state, request_id, response)
      
      {:ok, %{"type" => "ping"}} ->
        response = Jason.encode!(%{type: "pong"})
        {:reply, {:text, response}, state}
      
      {:error, _reason} ->
        error_msg = Jason.encode!(%{type: "error", message: "Invalid JSON"})
        {:reply, {:text, error_msg}, state}
      
      _ ->
        error_msg = Jason.encode!(%{type: "error", message: "Unknown message type"})
        {:reply, {:text, error_msg}, state}
    end
  end
  
  def websocket_handle({:binary, _data}, state) do
    # For now, we only handle text messages
    {:ok, state}
  end
  
  def websocket_info({:tunnel_request, request_id, request}, state) do
    # Forward the HTTP request to the client
    message = %{
      type: "request",
      request_id: request_id,
      request: request
    }
    
    response = Jason.encode!(message)
    {:reply, {:text, response}, state}
  end
  
  def websocket_info(info, state) do
    Logger.debug("Unhandled websocket info: #{inspect(info)}")
    {:ok, state}
  end
  
  def terminate(reason, _req, state) do
    Logger.info("WebSocket client disconnected: #{inspect(reason)}")
    
    # Clean up tunnel if it exists
    case state.tunnel_info do
      %{tunnel_id: tunnel_id} ->
        # In a real implementation, you might want to keep the tunnel alive
        # for a grace period in case the client reconnects
        DynamicSupervisor.terminate_child(Cryptun.TunnelSupervisor, tunnel_id)
      
      nil ->
        :ok
    end
    
    :ok
  end
  
  ## Private Functions
  
  defp handle_create_tunnel(state) do
    case Cryptun.ClientManager.create_tunnel(self()) do
      {:ok, tunnel_info} ->
        response = %{
          type: "tunnel_created",
          tunnel_id: tunnel_info.tunnel_id,
          subdomain: tunnel_info.subdomain,
          public_url: tunnel_info.public_url
        }
        
        message = Jason.encode!(response)
        new_state = %{state | tunnel_info: tunnel_info}
        
        {:reply, {:text, message}, new_state}
      
      {:error, reason} ->
        error_msg = Jason.encode!(%{
          type: "error", 
          message: "Failed to create tunnel: #{inspect(reason)}"
        })
        
        {:reply, {:text, error_msg}, state}
    end
  end
  
  defp handle_client_response(state, request_id, response) do
    case state.tunnel_info do
      %{tunnel_id: tunnel_id} ->
        Cryptun.Tunnel.client_response(tunnel_id, request_id, response)
        {:ok, state}
      
      nil ->
        error_msg = Jason.encode!(%{
          type: "error", 
          message: "No tunnel associated with this connection"
        })
        
        {:reply, {:text, error_msg}, state}
    end
  end
end