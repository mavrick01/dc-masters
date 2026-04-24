#!/usr/bin/env bash

# DC-Masters Container Toolkit - LiteLLM Database Fix
# Fixes missing source_url column in LiteLLM_MCPServerTable
# This is a workaround for LiteLLM migration issues

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Load .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Get LiteLLM master key
MASTER_KEY="${LITELLM_MASTER_KEY:-sk-1234-changeme}"

# Detect container runtime
RUNTIME=${CONTAINER_RUNTIME:-podman}

# Validate runtime is installed
if [ "$RUNTIME" = "docker" ]; then
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
else
    if ! command -v podman &> /dev/null; then
        print_error "Podman is not installed or not in PATH"
        exit 1
    fi
fi

print_info "Using container runtime: $RUNTIME"

# Check if LiteLLM is running and ready
print_info "Checking if LiteLLM is running and ready..."
MAX_WAIT=60
WAITED=0
LITELLM_READY=false

while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -s -o /dev/null -w "%{http_code}" \
        http://localhost:4000/health/liveness | grep -q "200"; then
        LITELLM_READY=true
        print_info "✓ LiteLLM is ready!"
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
    if [ $((WAITED % 10)) -eq 0 ]; then
        print_warn "Still waiting for LiteLLM... ($WAITED/$MAX_WAIT seconds)"
    fi
done

if [ "$LITELLM_READY" = false ]; then
    print_error "LiteLLM did not become ready in time"
    print_error "Please ensure LiteLLM is running: ./start-toolkit.sh status"
    exit 1
fi

# Apply database schema fix
print_info "Applying database schema fix for LiteLLM MCPServerTable..."
print_warn "Note: This fixes a bug with migrations not adding the source_url column in some cases"

$RUNTIME exec dc-masters-postgres psql -U dcmasters -d litellm -c "ALTER TABLE \"LiteLLM_MCPServerTable\" ADD COLUMN IF NOT EXISTS \"source_url\" TEXT;"

if [ $? -eq 0 ]; then
    print_info "✓ Database schema fix applied successfully"
    print_info "LiteLLM should now work correctly with MCP servers"
else
    print_error "Failed to apply database fix"
    print_error "Check that PostgreSQL is running: ./start-toolkit.sh status"
    exit 1
fi