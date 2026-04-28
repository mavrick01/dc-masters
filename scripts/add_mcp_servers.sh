#!/usr/bin/env bash
# Add MCP servers to LiteLLM from config file

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

LITELLM_URL="${LITELLM_URL:-http://localhost:4000}"
MASTER_KEY="${LITELLM_MASTER_KEY:-sk-1234-changeme}"
CONFIG_FILE="${1:-config/litellm/config.yaml}"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Config file not found: $CONFIG_FILE"
    exit 1
fi

# Parse config file
print_info "Reading MCP server configurations from $CONFIG_FILE..."
servers_json=$(python3 config/litellm/parse-mcp-servers.py "$CONFIG_FILE" 2>&1)

if [ $? -ne 0 ]; then
    print_error "Failed to parse config file"
    echo "$servers_json" | grep "^Warning:" >&2 || true
    echo "$servers_json" | grep "^Error:" >&2 || true
    exit 1
fi

# Show warnings
echo "$servers_json" | grep "^Warning:" >&2 || true

# Filter out warnings from JSON
servers_json_clean=$(echo "$servers_json" | grep -v "^Warning:" || echo "$servers_json")

# Count servers
server_count=$(echo "$servers_json_clean" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data))" 2>/dev/null || echo "0")
print_info "Found $server_count MCP servers to configure"

if [ "$server_count" = "0" ]; then
    print_warn "No MCP servers to add"
    exit 0
fi

# Add each server
echo "$servers_json_clean" | python3 -c "
import sys, json
servers = json.load(sys.stdin)
for server in servers:
    print(json.dumps(server))
" | while read -r server_config; do
    server_name=$(echo "$server_config" | python3 -c "import sys, json; print(json.load(sys.stdin)['name'])")
    transport=$(echo "$server_config" | python3 -c "import sys, json; print(json.load(sys.stdin).get('transport', 'http'))")

    print_info "Adding MCP server: $server_name (transport: $transport)"

    # Build the request body based on transport type
    if [ "$transport" = "http" ]; then
        # HTTP transport
        request_body=$(echo "$server_config" | python3 -c "
import sys, json
server = json.load(sys.stdin)
body = {
    'server_name': server['name'],
    'url': server['url'],
    'transport': 'http',
    'auth_type': server.get('auth_type', 'none'),
    'available_on_public_internet': server.get('available_on_public_internet', False),
    'alias': server.get('alias', ''),
    'allow_all_keys': server.get('allow_all_keys', False)
}
print(json.dumps(body))
")
    else
        # Stdio transport
        request_body=$(echo "$server_config" | python3 -c "
import sys, json
server = json.load(sys.stdin)
body = {
    'server_name': server['name'],
    'transport': 'stdio',
    'command': server['command'],
    'args': server.get('args', []),
    'env': server.get('env', {}),
    'allow_all_keys': server.get('allow_all_keys', False)
}
if 'alias' in server:
    body['alias'] = server['alias']
print(json.dumps(body))
")
    fi

    response=$(curl -s -X POST "$LITELLM_URL/v1/mcp/server" \
        -H "x-litellm-api-key: $MASTER_KEY" \
        -H 'accept: application/json' \
        -H "Content-Type: application/json" \
        -d "$request_body")

    if echo "$response" | grep -q "server_name\|name"; then
        echo "  ✓ Successfully added: $server_name"
    else
        echo "  ✗ Failed to add: $server_name"
        echo "    Response: $response"
    fi
done

print_info "MCP server configuration complete"
