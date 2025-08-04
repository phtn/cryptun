defmodule Cryptun.SimpleWeb do
  @moduledoc """
  Simple web interface using Plug.Router for the dashboard
  """
  
  use Plug.Router
  require Logger

  plug Plug.Logger
  plug :match
  plug :dispatch

  get "/" do
    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Cryptun Dashboard</title>
      <style>
        body { font-family: system-ui, sans-serif; margin: 2rem; background: #f8fafc; }
        .container { max-width: 1200px; margin: 0 auto; }
        .card { background: white; border-radius: 0.5rem; box-shadow: 0 1px 3px rgba(0,0,0,0.1); padding: 1.5rem; margin-bottom: 1rem; }
        .btn { display: inline-block; padding: 0.5rem 1rem; background: #3182ce; color: white; text-decoration: none; border-radius: 0.375rem; border: none; cursor: pointer; }
        .grid { display: grid; gap: 1rem; grid-template-columns: repeat(3, 1fr); }
        .badge { padding: 0.25rem 0.75rem; background: #c6f6d5; color: #22543d; border-radius: 9999px; font-size: 0.875rem; }
      </style>
      <script>
        function createTunnel() {
          fetch('/api/create-tunnel', {method: 'POST'})
            .then(r => r.json())
            .then(data => {
              alert('Tunnel created: ' + data.public_url);
              location.reload();
            });
        }
        
        function refreshData() {
          fetch('/api/tunnels')
            .then(r => r.json())
            .then(data => {
              document.getElementById('tunnel-count').textContent = data.length;
              const list = document.getElementById('tunnel-list');
              list.innerHTML = data.map(t => 
                `<div class="card">
                  <h3>${t.subdomain}</h3>
                  <p><a href="${t.public_url}" target="_blank">${t.public_url}</a></p>
                  <span class="badge">Active</span>
                </div>`
              ).join('');
            });
        }
        
        setInterval(refreshData, 3000);
        window.onload = refreshData;
      </script>
    </head>
    <body>
      <div class="container">
        <h1>🔒 Cryptun Dashboard</h1>
        
        <div class="grid">
          <div class="card">
            <h3>Active Tunnels</h3>
            <div style="font-size: 2rem; color: #3182ce;" id="tunnel-count">0</div>
          </div>
          <div class="card">
            <h3>Gateway Port</h3>
            <div style="font-size: 2rem; color: #38a169;">4001</div>
          </div>
          <div class="card">
            <h3>Dashboard Port</h3>
            <div style="font-size: 2rem; color: #805ad5;">4000</div>
          </div>
        </div>
        
        <div class="card">
          <h3>Quick Actions</h3>
          <button onclick="createTunnel()" class="btn">Create Test Tunnel</button>
          <button onclick="refreshData()" class="btn" style="background: #38a169;">Refresh</button>
        </div>
        
        <div class="card">
          <h3>Active Tunnels</h3>
          <div id="tunnel-list">Loading...</div>
        </div>
      </div>
    </body>
    </html>
    """
    
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  get "/api/tunnels" do
    tunnels = Cryptun.list_tunnels()
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(tunnels))
  end

  post "/api/create-tunnel" do
    case create_test_tunnel() do
      {:ok, tunnel_info} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(tunnel_info))
      
      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(%{error: inspect(reason)}))
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp create_test_tunnel do
    client_name = String.to_atom("test_client_#{:rand.uniform(10000)}")
    
    case GenServer.start_link(Cryptun.TestClient, %{local_port: 3000}, name: client_name) do
      {:ok, _pid} ->
        GenServer.call(client_name, :connect)
      
      {:error, reason} ->
        {:error, reason}
    end
  end
end