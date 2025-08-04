# Cryptun Phase 1 - Core Architecture Implementation

## Overview

Phase 1 establishes the foundational architecture for Cryptun, a secure tunneling service built with Elixir/OTP. This phase implements the core components needed for basic tunnel functionality, including process supervision, request routing, and a test client for validation.

## Architecture Implemented

### OTP Supervision Tree

```
Cryptun.Application
├── Registry (Cryptun.TunnelRegistry) - Maps tunnel IDs to processes
├── DynamicSupervisor (Cryptun.TunnelSupervisor) - Manages tunnel processes
├── Cryptun.ClientManager - Handles client connections and tunnel lifecycle
└── Plug.Cowboy (Cryptun.Gateway) - HTTP server on port 4000
```

### Core Components

#### 1. Cryptun.Tunnel (GenServer)
- **Purpose**: Manages individual tunnel state and request forwarding
- **Key Features**:
  - Unique tunnel ID and subdomain generation
  - Client process monitoring with automatic cleanup
  - Request buffering and response correlation
  - Fault tolerance through process isolation

**State Structure**:
```elixir
%Cryptun.Tunnel{
  tunnel_id: "unique_id",
  subdomain: "generated_subdomain", 
  client_pid: pid(),
  client_ref: reference(),
  pending_requests: %{request_id => from},
  request_counter: integer()
}
```

#### 2. Cryptun.ClientManager (GenServer)
- **Purpose**: Orchestrates tunnel creation and client management
- **Key Features**:
  - Dynamic tunnel creation via DynamicSupervisor
  - Tunnel ID generation using cryptographically secure random bytes
  - Client-to-tunnel association management
  - Tunnel information retrieval

#### 3. Cryptun.Gateway (Plug Router)
- **Purpose**: HTTP gateway that routes public requests to tunnels
- **Key Features**:
  - Subdomain-based routing (`tunnel-{id}.localhost:4000`)
  - Request/response transformation between HTTP and internal format
  - WebSocket upgrade endpoint at `/ws`
  - Error handling for disconnected clients

#### 4. Cryptun.WebSocketHandler (Cowboy WebSocket)
- **Purpose**: Handles WebSocket connections from tunnel clients
- **Key Features**:
  - JSON-based protocol for client communication
  - Tunnel creation and association
  - Request forwarding and response handling
  - Connection lifecycle management

#### 5. Cryptun.TestClient (GenServer)
- **Purpose**: Simulates a local tunnel client for testing
- **Key Features**:
  - Direct integration with ClientManager (bypasses WebSocket for simplicity)
  - Simulated local service responses
  - Request logging and response generation

## Protocol Design

### Client-Server Communication

**Tunnel Creation Flow**:
1. Client connects to `/ws` endpoint
2. Client sends `{"type": "create_tunnel"}` message
3. Server creates tunnel process and assigns subdomain
4. Server responds with tunnel information

**Request Forwarding Flow**:
1. HTTP request arrives at gateway with subdomain
2. Gateway extracts tunnel ID from subdomain
3. Gateway forwards request to tunnel process
4. Tunnel sends request to client via WebSocket
5. Client processes request and sends response
6. Tunnel correlates response and returns to gateway

### Message Format

**Client Messages**:
```json
{"type": "create_tunnel"}
{"type": "response", "request_id": 123, "response": {...}}
{"type": "ping"}
```

**Server Messages**:
```json
{"type": "tunnel_created", "tunnel_id": "...", "subdomain": "...", "public_url": "..."}
{"type": "request", "request_id": 123, "request": {...}}
{"type": "pong"}
```

## Dependencies Added

```elixir
{:phoenix, "~> 1.7.0"},           # WebSocket and LiveView support
{:phoenix_live_view, "~> 0.20.0"}, # Real-time features
{:cowboy, "~> 2.10"},             # HTTP server
{:plug, "~> 1.15"},               # HTTP middleware
{:plug_cowboy, "~> 2.7"},         # Cowboy adapter for Plug
{:jason, "~> 1.4"},               # JSON encoding/decoding
{:websock_adapter, "~> 0.5"}      # WebSocket adapter
```

## File Structure Created

```
cryptun/
├── lib/
│   ├── cryptun.ex                    # Main API module
│   └── cryptun/
│       ├── application.ex            # OTP Application with supervision tree
│       ├── tunnel.ex                 # Individual tunnel GenServer
│       ├── client_manager.ex         # Client connection management
│       ├── gateway.ex                # HTTP gateway and routing
│       ├── websocket_handler.ex      # WebSocket protocol handler
│       └── test_client.ex            # Test client for validation
├── mix.exs                           # Project configuration and dependencies
└── PHASE_1.md                        # This documentation
```

## Testing and Validation

### Manual Testing Commands

**Start IEx session**:
```bash
cd cryptun
iex -S mix
```

**Create and test tunnel**:
```elixir
# Start test client
{:ok, _pid} = Cryptun.TestClient.start_link(local_port: 3000)

# Create tunnel
{:ok, tunnel_info} = Cryptun.TestClient.connect()

# Inspect tunnel info
IO.inspect(tunnel_info)
# Output: %{tunnel_id: "...", subdomain: "tunnel-...", public_url: "http://tunnel-....localhost:4000"}

# List active tunnels
Cryptun.list_tunnels()

# Check tunnel count
Cryptun.tunnel_count()
```

**Test HTTP requests**:
```bash
# In another terminal
curl http://tunnel-[your-tunnel-id].localhost:4000/test
```

Expected response: HTML page showing "Hello from Cryptun!" with request details.

## Key Design Decisions

### 1. Process-Per-Tunnel Architecture
- Each tunnel runs as an isolated GenServer
- Fault tolerance: tunnel crashes don't affect others
- Natural request buffering and state management
- Easy to monitor and debug individual tunnels

### 2. Registry-Based Routing
- Uses Elixir's built-in Registry for tunnel lookup
- O(1) tunnel resolution by ID
- Automatic cleanup when processes die
- No external dependencies required

### 3. Subdomain-Based Public URLs
- Format: `tunnel-{id}.localhost:4000`
- Simple parsing and routing logic
- Easy to extend for custom domains later
- Clear separation between tunnels

### 4. JSON Protocol for WebSocket
- Human-readable for debugging
- Easy to extend with new message types
- Standard format for web clients
- Built-in validation with Jason library

### 5. Request Correlation System
- Each request gets unique ID for response matching
- Handles concurrent requests correctly
- Timeout protection for abandoned requests
- Clean error handling for client disconnections

## Limitations and Future Work

### Current Limitations
1. **No Authentication**: All tunnels are publicly accessible
2. **No Persistence**: Tunnels die when application restarts
3. **Single Node**: No distributed operation support
4. **Basic Error Handling**: Limited retry and recovery mechanisms
5. **No Rate Limiting**: Vulnerable to abuse
6. **HTTP Only**: No HTTPS/TLS support yet

### Next Phase Priorities
1. **Real WebSocket Client**: Replace test client with actual WebSocket implementation
2. **Authentication System**: API keys and tunnel access control
3. **HTTPS Support**: SSL termination and certificate management
4. **Rate Limiting**: Request throttling and abuse prevention
5. **Monitoring**: Metrics collection and health checks
6. **Configuration**: Environment-based settings management

## Performance Characteristics

### Strengths
- **Low Latency**: Direct process communication within BEAM VM
- **High Concurrency**: Lightweight processes handle thousands of tunnels
- **Fault Isolation**: Individual tunnel failures don't cascade
- **Memory Efficient**: Minimal overhead per tunnel process

### Scalability Considerations
- **Memory Usage**: ~2KB per tunnel process (estimated)
- **Connection Limits**: Bounded by system file descriptors
- **Request Throughput**: Limited by single HTTP gateway process
- **Network I/O**: Cowboy handles connection pooling efficiently

## Conclusion

Phase 1 successfully establishes a working tunnel service with core functionality:
- ✅ Dynamic tunnel creation and management
- ✅ HTTP request routing and forwarding
- ✅ WebSocket protocol for client communication
- ✅ Process supervision and fault tolerance
- ✅ Basic testing and validation framework

The architecture provides a solid foundation for building a production-ready tunneling service, with clear extension points for authentication, monitoring, and advanced features in future phases.