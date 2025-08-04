defmodule Cryptun.AuthPlug do
  @moduledoc """
  Plug for API key authentication and authorization.
  """
  
  import Plug.Conn
  require Logger
  
  def init(opts) do
    %{
      required_permission: Keyword.get(opts, :required_permission),
      optional: Keyword.get(opts, :optional, false)
    }
  end
  
  def call(conn, opts) do
    case Cryptun.Auth.extract_api_key(conn) do
      {:ok, api_key} ->
        case Cryptun.Auth.validate_api_key(api_key) do
          {:ok, metadata} ->
            if check_permission(api_key, opts.required_permission) do
              conn
              |> assign(:authenticated, true)
              |> assign(:api_key, api_key)
              |> assign(:api_key_metadata, metadata)
            else
              send_auth_error(conn, :insufficient_permissions)
            end
          
          {:error, :invalid_key} ->
            send_auth_error(conn, :invalid_api_key)
        end
      
      {:error, :no_api_key} ->
        if opts.optional do
          assign(conn, :authenticated, false)
        else
          send_auth_error(conn, :missing_api_key)
        end
    end
  end
  
  defp check_permission(_api_key, nil), do: true
  defp check_permission(api_key, permission) do
    Cryptun.Auth.has_permission?(api_key, permission)
  end
  
  defp send_auth_error(conn, reason) do
    error_message = case reason do
      :missing_api_key -> "API key required. Provide via Authorization header or api_key query parameter."
      :invalid_api_key -> "Invalid API key provided."
      :insufficient_permissions -> "API key does not have required permissions."
    end
    
    Logger.warning("Authentication failed: #{reason}")
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{
      error: "Authentication failed",
      message: error_message,
      code: reason
    }))
    |> halt()
  end
end