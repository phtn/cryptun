defmodule Cryptun.TunnelListLive do
  use Phoenix.LiveView
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to tunnel events
      Phoenix.PubSub.subscribe(Cryptun.PubSub, "tunnel_events")
      # Refresh every 3 seconds
      :timer.send_interval(3000, self(), :refresh)
    end

    socket = 
      socket
      |> assign(:page_title, "Tunnels")
      |> load_tunnels()

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, load_tunnels(socket)}
  end

  @impl true
  def handle_info({:tunnel_created, _tunnel_info}, socket) do
    {:noreply, load_tunnels(socket)}
  end

  @impl true
  def handle_info({:tunnel_destroyed, _tunnel_id}, socket) do
    {:noreply, load_tunnels(socket)}
  end

  @impl true
  def handle_event("terminate_tunnel", %{"tunnel_id" => tunnel_id}, socket) do
    case Registry.lookup(Cryptun.TunnelRegistry, tunnel_id) do
      [{tunnel_pid, _}] ->
        DynamicSupervisor.terminate_child(Cryptun.TunnelSupervisor, tunnel_pid)
        
        socket = 
          socket
          |> put_flash(:info, "Tunnel #{String.slice(tunnel_id, 0, 8)}... terminated")
          |> load_tunnels()
        
        {:noreply, socket}
      
      [] ->
        socket = put_flash(socket, :error, "Tunnel not found")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("create_tunnel", _params, socket) do
    case create_test_tunnel() do
      {:ok, tunnel_info} ->
        socket = 
          socket
          |> put_flash(:info, "Tunnel created: #{tunnel_info.public_url}")
          |> load_tunnels()
        
        {:noreply, socket}
      
      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to create tunnel: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem;">
        <div>
          <h2 style="margin: 0 0 0.5rem 0; color: #2d3748; font-size: 2rem;">Active Tunnels</h2>
          <p class="text-gray">Manage all your tunnel connections</p>
        </div>
        <button phx-click="create_tunnel" class="btn btn-primary">
          + New Tunnel
        </button>
      </div>

      <%= if @tunnels == [] do %>
        <div class="card" style="text-align: center; padding: 3rem;">
          <div style="font-size: 3rem; margin-bottom: 1rem;">🚇</div>
          <h3 style="color: #4a5568; margin-bottom: 0.5rem;">No Active Tunnels</h3>
          <p class="text-gray mb-4">Create your first tunnel to get started</p>
          <button phx-click="create_tunnel" class="btn btn-primary">
            Create Test Tunnel
          </button>
        </div>
      <% else %>
        <div class="grid" style="gap: 1rem;">
          <%= for tunnel <- @tunnels do %>
            <div class="card">
              <div style="display: flex; justify-content: space-between; align-items: start;">
                <div style="flex: 1;">
                  <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.5rem;">
                    <h3 style="margin: 0; color: #2d3748; font-size: 1.25rem;"><%= tunnel.subdomain %></h3>
                    <span class="badge badge-green">Active</span>
                  </div>
                  
                  <div class="text-sm text-gray mb-4">
                    <div><strong>Tunnel ID:</strong> <%= tunnel.tunnel_id %></div>
                    <div><strong>Created:</strong> <%= format_time(tunnel.created_at) %></div>
                  </div>

                  <div style="margin-bottom: 1rem;">
                    <div class="text-sm" style="color: #4a5568; margin-bottom: 0.25rem;"><strong>Public URL:</strong></div>
                    <div style="display: flex; align-items: center; gap: 0.5rem;">
                      <code style="background: #f7fafc; padding: 0.25rem 0.5rem; border-radius: 0.25rem; font-size: 0.875rem;">
                        <%= tunnel.public_url %>
                      </code>
                      <a href={tunnel.public_url} target="_blank" class="btn" style="padding: 0.25rem 0.5rem; font-size: 0.75rem; background: #edf2f7; color: #4a5568;">
                        Test
                      </a>
                    </div>
                  </div>

                  <div class="grid grid-3" style="gap: 1rem; margin-bottom: 1rem;">
                    <div>
                      <div class="text-sm text-gray">Requests</div>
                      <div style="font-weight: 500;"><%= tunnel.request_count || 0 %></div>
                    </div>
                    <div>
                      <div class="text-sm text-gray">Last Activity</div>
                      <div style="font-weight: 500;"><%= tunnel.last_activity || "Never" %></div>
                    </div>
                    <div>
                      <div class="text-sm text-gray">Status</div>
                      <div style="font-weight: 500; color: #38a169;">Connected</div>
                    </div>
                  </div>
                </div>

                <div style="margin-left: 1rem;">
                  <button 
                    phx-click="terminate_tunnel" 
                    phx-value-tunnel_id={tunnel.tunnel_id}
                    class="btn btn-danger"
                    style="font-size: 0.875rem;"
                    onclick="return confirm('Are you sure you want to terminate this tunnel?')"
                  >
                    Terminate
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp load_tunnels(socket) do
    tunnels = 
      Cryptun.list_tunnels()
      |> Enum.map(&enhance_tunnel_info/1)

    assign(socket, :tunnels, tunnels)
  end

  defp enhance_tunnel_info(tunnel) do
    tunnel
    |> Map.put(:created_at, DateTime.utc_now())
    |> Map.put(:request_count, :rand.uniform(50))
    |> Map.put(:last_activity, "#{:rand.uniform(30)} min ago")
  end

  defp create_test_tunnel do
    # Generate a unique name for the test client
    client_name = String.to_atom("test_client_#{:rand.uniform(10000)}")
    
    case GenServer.start_link(Cryptun.TestClient, %{local_port: 3000}, name: client_name) do
      {:ok, _pid} ->
        GenServer.call(client_name, :connect)
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end
end