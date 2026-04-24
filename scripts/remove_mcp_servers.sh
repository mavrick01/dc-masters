#!/usr/bin/env bash
# Remove MCP servers from LiteLLM based on config file

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    >&2 echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    >&2 echo -e "${YELLOW}[WARN]${NC} $1"
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
    print_warn "Config file not found: $CONFIG_FILE"
    print_info "Will try to fetch and remove all MCP servers from LiteLLM"
fi

print_info "Fetching MCP servers from LiteLLM..."
mcp_response=$(curl -s -X GET "$LITELLM_URL/v1/mcp/server" \
    -H "Authorization: Bearer $MASTER_KEY" 2>/dev/null || echo "[]")

# Get server names from config file if it exists
if [ -f "$CONFIG_FILE" ]; then
    print_info "Reading server names from $CONFIG_FILE..."
    MCP_NAMES=()
    while IFS= read -r server_name; do
        MCP_NAMES+=("$server_name")
    done < <(python3 config/litellm/parse-mcp-servers.py "$CONFIG_FILE" 2>/dev/null | python3 -c "
import sys, json
try:
    servers = json.load(sys.stdin)
    for server in servers:
        print(server['name'])
except:
    pass
" 2>/dev/null)
else
    # Fallback: get all server names from LiteLLM
    print_info "Fetching all server names from LiteLLM..."
    MCP_NAMES=()
    while IFS= read -r server_name; do
        MCP_NAMES+=("$server_name")
    done < <(echo "$mcp_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    servers = data if isinstance(data, list) else data.get('data', [])
    for server in servers:
        if 'server_name' in server:
            print(server['server_name'])
except:
    pass
" 2>/dev/null)
fi

if [ ${#MCP_NAMES[@]} -eq 0 ]; then
    print_info "No MCP servers to remove"
    exit 0
fi

print_info "Found ${#MCP_NAMES[@]} MCP server(s) to remove"

# Remove each server
for mcp_name in "${MCP_NAMES[@]}"; do
    # Extract server_id using Python to parse JSON properly
    server_id=$(echo "$mcp_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    servers = data if isinstance(data, list) else data.get('data', [])
    for server in servers:
        if server.get('server_name') == '$mcp_name':
            print(server.get('server_id', ''))
            break
except:
    pass
" 2>/dev/null)

    if [ -n "$server_id" ]; then
        print_info "Removing MCP server: $mcp_name (ID: $server_id)"

        http_code=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE "$LITELLM_URL/v1/mcp/server/$server_id" \
            -H "Authorization: Bearer $MASTER_KEY" \
            -H "Content-Type: application/json" 2>/dev/null)

        if [ "$http_code" = "200" ] || [ "$http_code" = "202" ] || [ "$http_code" = "204" ]; then
            echo "  ✓ Successfully removed: $mcp_name"
        else
            echo "  ⊙ Could not remove: $mcp_name (HTTP $http_code)"
        fi
    else
        echo "  ⊙ MCP server not found: $mcp_name"
    fi
done

print_info "MCP server removal complete"
