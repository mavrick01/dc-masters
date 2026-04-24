#!/usr/bin/env bash
# DC-Masters Container Toolkit - Import Workflows Script
# Imports n8n workflows from the workflows/ directory into the n8n instance running in the container

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    >&2 echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    >&2 echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
   >&2  echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    >&2 echo -e "${BLUE}=========================================${NC}"
    >&2 echo -e "${BLUE}$1${NC}"
    >&2 echo -e "${BLUE}=========================================${NC}"
}

# Load .env file
if [ -f .env ]; then
    print_info "Loading environment from .env file..."
    export $(grep -v '^#' .env | xargs)
else
    print_warn ".env file not found. Using defaults from .env.example"
    print_warn "Please copy .env.example to .env and configure your credentials"
fi

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

print_info "[N8N Import] Starting workflow import process..."

# Wait for N8N to be ready
print_info "[N8N Import] Waiting for N8N to be ready..."
MAX_WAIT=120
WAIT_TIME=0

./scripts/wait_for_service.sh "N8N" "http://localhost:5678" 5 || {
    print_error "[N8N Import] ERROR: N8N did not become ready in time"
    exit 1
}
# Additional wait for database initialization
print_info "[N8N Import] Waiting for database initialization..."
sleep 10

# Import workflows
print_info "[N8N Import] Importing workflows from workflows/..."

mkdir -p data/sandbox/workflows

# Check if any workflow files exist
if ! ls workflows/*.json >/dev/null 2>&1; then
    print_warn "No workflow JSON files found in workflows/"
    print_info "Skipping workflow import"
    exit 0
else
    print_info "Copying workflow files to sandbox directory..."
    cp workflows/*.json data/sandbox/workflows/
    print_info "✓ Workflow files copied"
fi

print_info "Importing workflows into N8N..."
$RUNTIME exec -it dc-masters-n8n n8n import:workflow --separate --input=/home/node/data/workflows/