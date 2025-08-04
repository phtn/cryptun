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
        .btn { display: inline-block; padding: 0.5rem 1rem; background: #3182ce; color: white; text-decoration: none; border-radius: 0.375rem; border: none; cursor: pointer; margin-right: 0.5rem; }
        .btn-danger { background: #e53e3e; }
        .btn-success { background: #38a169; }
        .grid { display: grid; gap: 1rem; grid-template-columns: repeat(3, 1fr); }
        .badge { padding: 0.25rem 0.75rem; background: #c6f6d5; color: #22543d; border-radius: 9999px; font-size: 0.875rem; }
        .code { background: #f7fafc; padding: 0.25rem 0.5rem; border-radius: 0.25rem; font-family: monospace; font-size: 0.875rem; }
        .tabs { display: flex; border-bottom: 1px solid #e2e8f0; margin-bottom: 1rem; }
        .tab { padding: 0.5rem 1rem; cursor: pointer; border-bottom: 2px solid transparent; }
        .tab.active { border-bottom-color: #3182ce; color: #3182ce; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
        input { padding: 0.5rem; border: 1px solid #d1d5db; border-radius: 0.375rem; margin-right: 0.5rem; }
      </style>
      <script>
        function showTab(tabName) {
          // Hide all tab contents
          document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
          document.querySelectorAll('.tab').forEach(el => el.classList.remove('active'));
          
          // Show selected tab
          document.getElementById(tabName + '-tab').classList.add('active');
          document.getElementById(tabName + '-content').classList.add('active');
        }
        
        function createTunnel() {
          fetch('/api/create-tunnel', {method: 'POST'})
            .then(r => r.json())
            .then(data => {
              if (data.error) {
                alert('Error: ' + data.message);
              } else {
                alert('Tunnel created: ' + data.public_url);
                refreshData();
              }
            });
        }
        
        function createApiKey() {
          const name = document.getElementById('key-name').value || 'Unnamed Key';
          fetch('/api/keys', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({name: name})
          })
          .then(r => r.json())
          .then(data => {
            if (data.error) {
              alert('Error: ' + data.message);
            } else {
              alert('API Key created: ' + data.api_key);
              document.getElementById('key-name').value = '';
              refreshApiKeys();
            }
          });
        }
        
        function revokeApiKey(apiKey) {
          if (confirm('Are you sure you want to revoke this API key?')) {
            fetch('/api/keys/' + encodeURIComponent(apiKey), {method: 'DELETE'})
              .then(r => r.json())
              .then(data => {
                if (data.error) {
                  alert('Error: ' + data.message);
                } else {
                  alert('API key revoked');
                  refreshApiKeys();
                }
              });
          }
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
                  <p><small>API Key: ${t.api_key ? 'Protected' : 'None'}</small></p>
                  <span class="badge">Active</span>
                </div>`
              ).join('');
            });
        }
        
        function refreshApiKeys() {
          fetch('/api/keys')
            .then(r => r.json())
            .then(data => {
              document.getElementById('key-count').textContent = data.length;
              const list = document.getElementById('key-list');
              list.innerHTML = data.map(k => 
                `<div class="card">
                  <h4>${k.metadata.name}</h4>
                  <p class="code">${k.key_preview}</p>
                  <p><small>Created: ${new Date(k.metadata.created_at).toLocaleString()}</small></p>
                  <p><small>Usage: ${k.metadata.usage_count || 0} requests</small></p>
                  <button onclick="revokeApiKey('${k.key}')" class="btn btn-danger">Revoke</button>
                </div>`
              ).join('');
            });
        }
        
        function refreshAll() {
          refreshData();
          refreshApiKeys();
        }
        
        setInterval(refreshAll, 5000);
        window.onload = function() {
          showTab('tunnels');
          refreshAll();
        };
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
            <h3>API Keys</h3>
            <div style="font-size: 2rem; color: #38a169;" id="key-count">0</div>
          </div>
          <div class="card">
            <h3>Gateway Port</h3>
            <div style="font-size: 2rem; color: #805ad5;">4001</div>
          </div>
        </div>
        
        <div class="card">
          <div class="tabs">
            <div class="tab active" id="tunnels-tab" onclick="showTab('tunnels')">Tunnels</div>
            <div class="tab" id="keys-tab" onclick="showTab('keys')">API Keys</div>
          </div>
          
          <div id="tunnels-content" class="tab-content active">
            <div style="margin-bottom: 1rem;">
              <button onclick="createTunnel()" class="btn">Create Test Tunnel</button>
              <button onclick="refreshData()" class="btn btn-success">Refresh</button>
            </div>
            <div id="tunnel-list">Loading...</div>
          </div>
          
          <div id="keys-content" class="tab-content">
            <div style="margin-bottom: 1rem;">
              <input type="text" id="key-name" placeholder="API Key Name" />
              <button onclick="createApiKey()" class="btn">Create API Key</button>
              <button onclick="refreshApiKeys()" class="btn btn-success">Refresh</button>
            </div>
            <div id="key-list">Loading...</div>
          </div>
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
        |> send_resp(500, Jason.encode!(%{error: true, message: inspect(reason)}))
    end
  end

  get "/api/keys" do
    keys = Cryptun.Auth.list_api_keys()
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(keys))
  end

  post "/api/keys" do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    
    case Jason.decode(body) do
      {:ok, %{"name" => name}} ->
        case Cryptun.Auth.generate_api_key(%{name: name}) do
          {:ok, api_key, metadata} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Jason.encode!(%{
              api_key: api_key,
              metadata: metadata
            }))
          
          {:error, reason} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(500, Jason.encode!(%{error: true, message: inspect(reason)}))
        end
      
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: true, message: "Invalid JSON or missing name"}))
    end
  end

  delete "/api/keys/:api_key" do
    case Cryptun.Auth.revoke_api_key(api_key) do
      :ok ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{success: true}))
      
      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: true, message: inspect(reason)}))
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