#!/usr/bin/env bash
# List all configuration components and their status

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_section() {
    >&2 echo -e "${BLUE}=========================================${NC}"
    >&2 echo -e "${BLUE}$1${NC}"
    >&2 echo -e "${BLUE}=========================================${NC}"
}

# Load environment
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

LITELLM_URL="http://localhost:4000"
N8N_URL="http://localhost:5678"
MASTER_KEY="${LITELLM_MASTER_KEY:-sk-1234-changeme}"

echo ""
print_section "DC-Masters Toolkit Component Status"
echo ""

# Check LiteLLM Models
echo -e "${BLUE}LiteLLM Models:${NC}"
model_count=$(curl -s -X GET "$LITELLM_URL/model/info" \
    -H "Authorization: Bearer $MASTER_KEY" 2>/dev/null | \
    grep -o '"model_name"' | wc -l | tr -d ' ')
echo "  Models configured: $model_count"
echo ""

# Check MCP Servers
echo -e "${BLUE}MCP Servers:${NC}"
mcp_response=$(curl -s -X GET "$LITELLM_URL/mcp/servers" \
    -H "Authorization: Bearer $MASTER_KEY" 2>/dev/null || echo "[]")
if echo "$mcp_response" | grep -q "filesystem"; then
    echo "  ✓ filesystem"
else
    echo "  ✗ filesystem (not registered)"
fi
if echo "$mcp_response" | grep -q "duckduckgo"; then
    echo "  ✓ duckduckgo"
else
    echo "  ✗ duckduckgo (not registered)"
fi
echo ""

# Check Virtual Keys
echo -e "${BLUE}Virtual Keys:${NC}"
key_count=$(curl -s -X GET "$LITELLM_URL/key/info" \
    -H "Authorization: Bearer $MASTER_KEY" 2>/dev/null | \
    grep -o '"key_alias"' | wc -l | tr -d ' ')
echo "  Keys configured: $key_count"
if curl -s -X GET "$LITELLM_URL/key/info" -H "Authorization: Bearer $MASTER_KEY" 2>/dev/null | grep -q "n8n-workflows"; then
    echo "  ✓ n8n-workflows key exists"
else
    echo "  ✗ n8n-workflows key not found"
fi
echo ""

# Check N8N Credentials (requires API key)
echo -e "${BLUE}N8N Credentials:${NC}"
echo "  Run with N8N_API_KEY to check credentials"
if [ -n "$N8N_API_KEY" ]; then
    cred_count=$(curl -s -X GET "$N8N_URL/api/v1/credentials" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" 2>/dev/null | \
        grep -o '"name"' | wc -l | tr -d ' ')
    echo "  Credentials configured: $cred_count"
fi
echo ""

# Check N8N Workflows
echo -e "${BLUE}N8N Workflows:${NC}"
echo "  Run with N8N_API_KEY to check workflows"
if [ -n "$N8N_API_KEY" ]; then
    workflow_count=$(curl -s -X GET "$N8N_URL/api/v1/workflows" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" 2>/dev/null | \
        grep -o '"name"' | wc -l | tr -d ' ')
    echo "  Workflows imported: $workflow_count"
fi
echo ""

# Available Scripts
print_section "Available Scripts"
echo ""
echo "Configuration:"
echo "  ./scripts/add_litellm_models.sh      - Add LiteLLM models"
echo "  ./scripts/add_mcp_servers.sh         - Add MCP servers"
echo "  ./scripts/create_virtual_key.sh      - Create virtual key"
echo "  ./scripts/create_n8n_credentials.sh  - Create N8N credentials"
echo "  ./scripts/import_workflows.sh        - Import workflows"
echo ""
echo "Removal:"
echo "  ./scripts/remove_litellm_models.sh   - Remove models"
echo "  ./scripts/remove_mcp_servers.sh      - Remove MCP servers"
echo "  ./scripts/remove_virtual_keys.sh     - Remove virtual keys"
echo "  ./scripts/remove_n8n_credentials.sh  - Remove credentials"
echo "  ./scripts/remove_workflows.sh        - Remove workflows"
echo ""
echo "Utilities:"
echo "  ./scripts/get_n8n_api_key.sh         - Get N8N API key"
echo "  ./scripts/wait_for_service.sh        - Wait for service"
echo ""
echo "Full Setup/Reset:"
echo "  ./configure-toolkit.sh               - Full configuration"
echo "  ./configure-toolkit.sh clean         - Full reset"
echo ""
