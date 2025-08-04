defmodule Cryptun.Gateway do
  @moduledoc """
  HTTP Gateway that receives public requests and routes them to appropriate tunnels.
  """
  
  use Plug.Router
  require Logger
  
  plug Plug.Logger
  plug :match
  plug :dispatch
  
  # WebSocket endpoint for client connections
  get "/ws" do
    conn
    |> WebSockAdapter.upgrade(Cryptun.WebSocketHandler, [], timeout: 60_000)
    |> halt()
  end
  
  # Handle all other HTTP methods and paths
  match _ do
    case extract_tunnel_id(conn.host) do
      {:ok, tunnel_id} ->
        handle_tunnel_request(conn, tunnel_id)
      
      {:error, :invalid_host} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Tunnel not found")
    end
  end
  
  defp extract_tunnel_id(host) do
    case String.split(host, ".") do
      ["tunnel-" <> tunnel_id | _rest] ->
        {:ok, tunnel_id}
      
      _ ->
        {:error, :invalid_host}
    end
  end
  
  defp handle_tunnel_request(conn, tunnel_id) do
    # Convert Plug.Conn to a simple request map
    request = %{
      method: conn.method,
      path: conn.request_path,
      query_string: conn.query_string,
      headers: conn.req_headers,
      body: read_request_body(conn)
    }
    
    case Cryptun.Tunnel.handle_request(tunnel_id, request) do
      {:ok, response} ->
        conn
        |> put_response_headers(response.headers || [])
        |> put_resp_content_type(get_content_type(response.headers))
        |> send_resp(response.status || 200, response.body || "")
      
      {:error, :no_client} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(503, "Tunnel client not connected")
      
      {:error, :client_disconnected} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(503, "Tunnel client disconnected")
      
      {:error, reason} ->
        Logger.error("Tunnel request failed: #{inspect(reason)}")
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(500, "Internal server error")
    end
  end
  
  defp read_request_body(conn) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, _conn} -> body
      {:more, _partial, _conn} -> ""  # For simplicity, not handling chunked requests yet
      {:error, _reason} -> ""
    end
  end
  
  defp put_response_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, acc ->
      Plug.Conn.put_resp_header(acc, key, value)
    end)
  end
  
  defp get_content_type(headers) do
    case Enum.find(headers, fn {key, _value} -> String.downcase(key) == "content-type" end) do
      {_key, content_type} -> content_type
      nil -> "text/plain"
    end
  end
end