# MCP Server for DC-Masters Toolkit

This directory contains the HTTP-based MCP (Model Context Protocol) server that provides tools for AI models via LiteLLM.

## Service

### MCP SearXNG Server (port 8081)
- **Purpose**: Provides web search capability via SearXNG
- **Transport**: HTTP
- **Container**: `dc-masters-mcp-searxng`
- **Dependencies**: SearXNG service
- **Package**: `mcp-searxng` (npm)
- **Implementation**: Custom container with Node.js and corporate certificate support
- **Health endpoint**: http://localhost:8081/health

## Why HTTP Transport?

The latest stable LiteLLM containers don't include Node.js/npm, which means `stdio` transport with `npx` commands won't work. By running MCP servers as separate HTTP services:

✅ **No npx dependency** - Works with any LiteLLM version  
✅ **Independent scaling** - Each MCP server can be scaled separately  
✅ **Better isolation** - Failures in one MCP server don't affect others  
✅ **Health monitoring** - Each container has its own health check  
✅ **Easier debugging** - Separate logs for each service  

## Corporate Firewall Support

The MCP SearXNG server supports corporate CA certificates via custom entrypoint:

1. Place your corporate CA certificate at: `certs/company-ca.pem`
2. The entrypoint script automatically:
   - Copies the certificate to `/usr/local/share/ca-certificates/company-ca.crt`
   - Runs `update-ca-certificates`
   - Sets `NODE_EXTRA_CA_CERTS` environment variable

## Building and Running

### Build the MCP SearXNG server:
```bash
docker compose build mcp-searxng
# OR
podman compose build mcp-searxng
```

### Start the service:
```bash
docker compose up -d mcp-searxng
# OR
podman compose up -d mcp-searxng
```

### Rebuild after code changes:
```bash
docker compose up -d --build mcp-searxng
# OR
podman compose up -d --build mcp-searxng
```

## Health Check

```bash
curl http://localhost:8081/health
# Expected: {"status":"healthy"}
```

## Testing MCP Tools

### List available tools:
```bash
curl -X POST http://localhost:8081/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": 1
  }'
```

### Perform a search:
```bash
curl -X POST http://localhost:8081/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "search",
      "arguments": {"query": "artificial intelligence"}
    },
    "id": 2
  }'
```

## LiteLLM Configuration

The MCP servers are configured in `config/litellm/config.yaml`:

```yaml
mcp_servers:
  - name: searxng
    transport: http
    url: "http://mcp-searxng:3000"
    allow_all_keys: true

  - name: filesystem
    transport: http
    url: "http://mcp-filesystem:3001"
    allow_all_keys: true
```

## Troubleshooting

### MCP server won't start:
```bash
# Check logs
docker logs dc-masters-mcp-searxng

# Rebuild with no cache
docker compose build --no-cache mcp-searxng
docker compose up -d mcp-searxng
```

### Certificate errors:
1. Verify certificate exists: `ls -la certs/company-ca.pem`
2. Check entrypoint logs: `docker logs dc-masters-mcp-searxng | grep CA`
3. Verify certificate was installed: `docker exec dc-masters-mcp-searxng ls -la /usr/local/share/ca-certificates/`

### Connection refused from LiteLLM:
```bash
# Verify MCP server is on same network
docker network inspect dc-masters_toolkit-network

# Test from LiteLLM container
docker exec dc-masters-litellm curl http://mcp-searxng:8081/health
```

## Adding New MCP Servers

To add a new MCP server:

1. Create directory: `mcp-servers/your-server/`
2. Create `Dockerfile` with HTTP transport support
3. Create `entrypoint.sh` for CA certificate handling
4. Add service to `compose.yaml`
5. Update `config/litellm/config.yaml`
6. Rebuild and restart services

See existing servers as templates.

## References

- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [LiteLLM MCP Documentation](https://docs.litellm.ai/docs/mcp)
- [mcp-searxng Package](https://www.npmjs.com/package/mcp-searxng)
