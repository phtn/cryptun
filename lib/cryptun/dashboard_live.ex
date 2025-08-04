defmodule Cryptun.DashboardLive do
  use Phoenix.LiveView
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to tunnel events
      Phoenix.PubSub.subscribe(Cryptun.PubSub, "tunnel_events")
      # Refresh every 5 seconds
      :timer.send_interval(5000, self(), :refresh)
    end

    socket = 
      socket
      |> assign(:page_title, "Dashboard")
      |> load_dashboard_data()

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  @impl true
  def handle_info({:tunnel_created, _tunnel_info}, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  @impl true
  def handle_info({:tunnel_destroyed, _tunnel_id}, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  @impl true
  def handle_event("create_test_tunnel", _params, socket) do
    case create_test_tunnel() do
      {:ok, tunnel_info} ->
        socket = 
          socket
          |> put_flash(:info, "Test tunnel created: #{tunnel_info.public_url}")
          |> load_dashboard_data()
        
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
      <div class="mb-4">
        <h2 style="margin: 0 0 1rem 0; color: #2d3748; font-size: 2rem;">Tunnel Dashboard</h2>
        <p class="text-gray">Monitor and manage your active tunnels</p>
      </div>

      <!-- Stats Cards -->
      <div class="grid grid-3 mb-4">
        <div class="card">
          <h3 style="margin: 0 0 0.5rem 0; color: #4a5568;">Active Tunnels</h3>
          <div style="font-size: 2rem; font-weight: bold; color: #3182ce;"><%= @stats.active_tunnels %></div>
        </div>
        
        <div class="card">
          <h3 style="margin: 0 0 0.5rem 0; color: #4a5568;">Total Requests</h3>
          <div style="font-size: 2rem; font-weight: bold; color: #38a169;"><%= @stats.total_requests %></div>
        </div>
        
        <div class="card">
          <h3 style="margin: 0 0 0.5rem 0; color: #4a5568;">Uptime</h3>
          <div style="font-size: 2rem; font-weight: bold; color: #805ad5;"><%= @stats.uptime %></div>
        </div>
      </div>

      <!-- Actions -->
      <div class="card mb-4">
        <h3 style="margin: 0 0 1rem 0; color: #4a5568;">Quick Actions</h3>
        <button phx-click="create_test_tunnel" class="btn btn-primary">
          Create Test Tunnel
        </button>
      </div>

      <!-- Recent Tunnels -->
      <div class="card">
        <h3 style="margin: 0 0 1rem 0; color: #4a5568;">Recent Tunnels</h3>
        
        <%= if @tunnels == [] do %>
          <p class="text-gray">No active tunnels. Create one to get started!</p>
        <% else %>
          <div class="grid" style="gap: 0.5rem;">
            <%= for tunnel <- @tunnels do %>
              <div style="display: flex; justify-content: space-between; align-items: center; padding: 1rem; border: 1px solid #e2e8f0; border-radius: 0.375rem;">
                <div>
                  <div style="font-weight: 500; color: #2d3748;"><%= tunnel.subdomain %></div>
                  <div class="text-sm text-gray">ID: <%= String.slice(tunnel.tunnel_id, 0, 8) %>...</div>
                  <div class="text-sm">
                    <a href={tunnel.public_url} target="_blank" style="color: #3182ce; text-decoration: none;">
                      <%= tunnel.public_url %>
                    </a>
                  </div>
                </div>
                <div>
                  <span class="badge badge-green">Active</span>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp load_dashboard_data(socket) do
    tunnels = Cryptun.list_tunnels()
    
    stats = %{
      active_tunnels: length(tunnels),
      total_requests: get_total_requests(),
      uptime: get_uptime()
    }

    socket
    |> assign(:tunnels, tunnels)
    |> assign(:stats, stats)
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

  defp get_total_requests do
    # This would be tracked in a real implementation
    :rand.uniform(1000)
  end

  defp get_uptime do
    # Calculate uptime since application start
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    uptime_seconds = div(uptime_ms, 1000)
    
    hours = div(uptime_seconds, 3600)
    minutes = div(rem(uptime_seconds, 3600), 60)
    
    "#{hours}h #{minutes}m"
  end
end