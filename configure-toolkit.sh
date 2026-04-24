#!/usr/bin/env bash
# DC-Masters Container Toolkit - Configuration Orchestrator
# Configures or resets LiteLLM models, virtual keys, N8N credentials, and workflows
#
# Usage:
#   ./configure-toolkit.sh        - Configure everything
#   ./configure-toolkit.sh clean  - Reset configuration to pre-configured state

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=========================================${NC}"
}

# Load environment variables
if [ -f .env ]; then
    print_info "Loading environment from .env file..."
    export $(grep -v '^#' .env | xargs)
else
    print_error ".env file not found!"
    exit 1
fi

LITELLM_URL="http://localhost:4000"
N8N_URL="http://localhost:5678"
MASTER_KEY="${LITELLM_MASTER_KEY:-sk-1234-changeme}"

###########################################
# RESET/CLEAN MODE
###########################################

if [ "${1:-}" = "clean" ]; then
    print_section "DC-Masters Toolkit Configuration Reset"
    echo ""

    print_warn "This will remove all configuration added by configure-toolkit.sh:"
    print_warn "  - LiteLLM models (Gemini, GPT, Claude)"
    print_warn "  - LiteLLM MCP servers (filesystem, duckduckgo)"
    print_warn "  - LiteLLM virtual keys"
    print_warn "  - N8N credentials"
    print_warn "  - N8N workflows"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        print_info "Reset cancelled"
        exit 0
    fi

    # Wait for services
    print_section "Waiting for Services"
    scripts/wait_for_service.sh "LiteLLM" "$LITELLM_URL/health/liveness" || exit 1
    scripts/wait_for_service.sh "N8N" "$N8N_URL" || exit 1
    echo ""

    # Get N8N API key
    api_key_data=$(scripts/create_n8n_api_key.sh)
    if [ -z "$api_key_data" ]; then
        print_error "Failed to obtain N8N API key"
        exit 1
    fi
    export N8N_SESSION_COOKIE=$(echo "$api_key_data" | cut -d'|' -f1)
    export N8N_API_KEY_ID=$(echo "$api_key_data" | cut -d'|' -f2)
    export N8N_API_KEY=$(echo "$api_key_data" | cut -d'|' -f3)
    echo ""

    # Remove components
    print_section "Step 1: Removing LiteLLM Models"
    scripts/remove_litellm_models.sh
    echo ""

    print_section "Step 2: Removing MCP Servers"
    scripts/remove_mcp_servers.sh
    echo ""

    print_section "Step 3: Removing LiteLLM Virtual Keys"
    scripts/remove_virtual_keys.sh
    echo ""

    print_section "Step 4: Removing N8N Credentials"
    scripts/remove_n8n_creds.sh
    echo ""

    print_section "Step 5: Removing N8N Workflows"
    scripts/remove_workflows.sh
    echo ""

    # Cleanup temporary API key
    print_section "Step 6: Cleanup"
    scripts/remove_n8n_api_key.sh  || \
        print_warn "  ⊙ Could not delete temporary API key (it will expire in 10 minutes)"
    echo ""

    print_section "Reset Complete!"
    echo ""
    print_info "Configuration has been reset to pre-configure state"
    print_info "You can now run ./configure-toolkit.sh again if needed"
    echo ""

    exit 0
fi

###########################################
# MAIN CONFIGURATION MODE
###########################################

print_section "DC-Masters Toolkit Configuration"
echo ""

# Step 1: Wait for services
print_section "Step 1: Waiting for Services"
scripts/wait_for_service.sh "LiteLLM" "$LITELLM_URL/health/liveness" || exit 1
scripts/wait_for_service.sh "N8N" "$N8N_URL" || exit 1
echo ""

# Get N8N API key for subsequent operations
api_key_data=$(scripts/create_n8n_api_key.sh)
if [ -z "$api_key_data" ]; then
    print_error "Failed to obtain N8N API key"
    exit 1
fi
export N8N_SESSION_COOKIE=$(echo "$api_key_data" | cut -d'|' -f1)
export N8N_API_KEY_ID=$(echo "$api_key_data" | cut -d'|' -f2)
export N8N_API_KEY=$(echo "$api_key_data" | cut -d'|' -f3)

print_info "Obtained N8N API key (ID: $N8N_API_KEY_ID)"
print_info "Obtained N8N Key ID: $N8N_API_KEY_ID"
print_info "Obtained N8N Session Cookie: $N8N_SESSION_COOKIE"

echo ""

# Step 2: Configure LiteLLM Models
print_section "Step 2: Configuring LiteLLM Models"
scripts/add_litellm_models.sh
echo ""

# Step 3: Configure MCP Servers
print_section "Step 3: Configuring MCP Servers"
scripts/add_mcp_servers.sh
echo ""

# Step 4: Create LiteLLM Virtual Key for N8N
print_section "Step 4: Creating LiteLLM Virtual Key for N8N"
VIRTUAL_KEY=$(scripts/create_virtual_key.sh "n8n-workflows" '["gemini-2-5-flash", "gemini-3.1-flash-lite-preview", "gemini-3.1-pro-preview", "text-embedding-005"]')

if [ -n "$VIRTUAL_KEY" ]; then
    echo ""
    print_info "Virtual key created: $VIRTUAL_KEY"
    print_info "This key will be used for N8N workflow credentials"
    export LITELLM_VIRTUAL_KEY="$VIRTUAL_KEY"
else
    print_error "Failed to create virtual key - N8N configuration may be incomplete"
fi
echo ""

# Step 5: Configure N8N Credentials
print_section "Step 5: Configuring N8N Credentials"
scripts/create_n8n_creds.sh
echo ""

# Step 6: Import N8N Workflows
print_section "Step 6: Importing N8N Workflows"
scripts/import_workflows.sh
echo ""

# Step 7: Cleanup Temporary API Key
print_section "Step 7: Cleanup"
scripts/remove_n8n_api_key.sh  || \
    echo "  ⊙ Could not delete temporary API key (it will expire in 10 minutes)"
echo ""

# Summary
print_section "Configuration Complete!"
echo ""
echo "Services configured:"
echo "  ✓ LiteLLM: http://localhost:4000"
echo "    - Models configured from config/litellm/config.yaml"
echo "    - MCP servers: filesystem, duckduckgo"
echo "  ✓ N8N: http://localhost:5678"
echo ""
echo "Credentials created in N8N:"
echo "  - Google Cloud - Vertex AI"
echo "  - PostgreSQL - Embeddings DB"
echo "  - PostgreSQL - AIRS DB"
if [ -n "$VIRTUAL_KEY" ]; then
    echo "  - LiteLLM API"
fi
echo ""
echo "Workflows imported:"
echo "  - 1. Embedding Agent - Auto-embed Files"
echo "  - 2. Basic AI Agent - RAG with Gemini"
echo "  - 3. Advanced AI Agent - LiteLLM with MCP"
echo "  - 4. AIRS PDF Downloader - Embed Documentation"
echo "  - 5. AIRS Chatbot - Query Documentation"
echo ""
echo "Next steps:"
echo "  1. Access N8N at http://localhost:5678"
echo "  2. Login: ${N8N_OWNER_EMAIL:-admin@dcmasters.local} / ${N8N_OWNER_PASSWORD:-changeme123}"
echo "  3. Open each workflow and assign the credentials created above"
echo "  4. Activate workflows 1, 2, 3, and 5"
echo "  5. Manually run workflow 4 once to download AIRS PDFs"
echo ""
print_info "Individual steps can be run separately using scripts in scripts/"
echo ""
