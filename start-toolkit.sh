#!/usr/bin/env bash

# DC-Masters Container Toolkit - Startup Script
# Supports both Docker and Podman

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
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
    COMPOSE_CMD="docker compose"
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
else
    COMPOSE_CMD="podman compose"
    if ! command -v podman &> /dev/null; then
        print_error "Podman is not installed or not in PATH"
        exit 1
    fi
    # Check if podman compose works
    if ! podman compose version &> /dev/null; then
        print_warn "podman compose not available, trying podman-compose..."
        COMPOSE_CMD="podman-compose"
        if ! command -v podman-compose &> /dev/null; then
            print_error "Neither 'podman compose' nor 'podman-compose' is available"
            print_info "Install with: pip install podman-compose"
            exit 1
        fi
    fi
fi

print_info "Using container runtime: $RUNTIME"
print_info "Using compose command: $COMPOSE_CMD"

# Function to start services
start_services() {
    print_info "Creating data directories..."
    mkdir -p data/{postgres,n8n,sandbox/{import,shared}}
    mkdir -p credentials
    mkdir -p certs

    # Copy Google Cloud credentials if specified
    if [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
        print_info "Copying Google Cloud credentials to credentials directory..."
        cp "$GOOGLE_APPLICATION_CREDENTIALS" credentials/google_credentials.json
        # Set readable permissions for containers
        chmod 644 credentials/google_credentials.json
        print_info "✓ Credentials copied successfully"
    elif [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
        print_warn "GOOGLE_APPLICATION_CREDENTIALS is set but file not found: $GOOGLE_APPLICATION_CREDENTIALS"
        print_warn "LiteLLM and N8N will not be able to access Vertex AI"
    else
        print_warn "GOOGLE_APPLICATION_CREDENTIALS not set in .env file"
        print_warn "LiteLLM and N8N will not be able to access Vertex AI"
    fi

    # Check for corporate CA certificate
    if [ -f "certs/company-ca.pem" ]; then
        print_info "Corporate CA certificate detected: certs/company-ca.pem"
        print_info "Configuring SSL certificate trust for LiteLLM and N8N..."

        # Export certificate paths for containers
        export REQUESTS_CA_BUNDLE=/app/certs/company-ca.pem
        export CURL_CA_BUNDLE=/app/certs/company-ca.pem
        export NODE_EXTRA_CA_CERTS=/app/certs/company-ca.pem
        export SSL_CERT_FILE=/app/certs/company-ca.pem

        print_info "✓ Corporate CA certificate will be trusted by services"
    elif [ -d "certs" ] && [ -n "$(ls -A certs 2>/dev/null)" ]; then
        print_warn "certs/ directory exists but company-ca.pem not found"
        print_warn "To enable corporate firewall support, place your CA certificate at:"
        print_warn "  certs/company-ca.pem"
    fi

    print_info "Starting DC-Masters Container Toolkit..."
    $COMPOSE_CMD up -d

    print_info ""
    print_info "========================================="
    print_info "DC-Masters Container Toolkit is starting"
    print_info "========================================="
    print_info ""
    print_info "Services will be available at:"
    print_info "  - LiteLLM API: http://localhost:4000"
    print_info "  - N8N UI: http://localhost:5678"
    print_info "  - PostgreSQL: localhost:5432"
    print_info "  - MCP Filesystem: http://localhost:8000"
    print_info "  - MCP DuckDuckGo: http://localhost:8001"
    print_info ""
    print_info "Default credentials (change in .env):"
    print_info "  - N8N UI: ${N8N_OWNER_EMAIL:-admin@dcmasters.local} / ${N8N_OWNER_PASSWORD:-changeme123}"
    print_info "  - LiteLLM UI: ${UI_USERNAME:-admin@dcmasters.local} / ${UI_PASSWORD:-changeme123}"
    print_info "  - PostgreSQL: ${POSTGRES_USER:-dcmasters} / ${POSTGRES_PASSWORD:-changeme123}"
    print_info ""
    print_info "Note: N8N owner account will be created automatically"
    print_warn "Please wait a few minutes for all services to initialize..."

    # Wait for N8N to be ready and create owner account
    print_info "Waiting for N8N to be ready..."
    MAX_WAIT=60
    WAITED=0
    while [ $WAITED -lt $MAX_WAIT ]; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 | grep -q "200\|401\|403"; then
            print_info "N8N is ready!"
            break
        fi
        sleep 2
        WAITED=$((WAITED + 2))
    done

    if [ $WAITED -ge $MAX_WAIT ]; then
        print_warn "N8N did not become ready in time, skipping owner account creation"
        print_warn "You may need to register manually at http://localhost:5678"
    else
        # Wait a bit longer for N8N to fully initialize
        print_info "Waiting for N8N to fully initialize..."
        sleep 10

        # Create N8N owner account using SQL script
        print_info "Creating N8N owner account..."

        # Run SQL script in PostgreSQL container
        CREATE_OUTPUT=$($RUNTIME exec -i dc-masters-postgres psql -U dcmasters -d n8n -f - < config/n8n/create-owner.sql 2>&1)

        if echo "$CREATE_OUTPUT" | grep -q "NOTICE.*N8N Setup"; then
            echo "$CREATE_OUTPUT" | grep "NOTICE" | sed 's/NOTICE:  //'
        elif echo "$CREATE_OUTPUT" | grep -q "ERROR"; then
            print_warn "Owner account creation failed:"
            echo "$CREATE_OUTPUT" | head -5
        else
            print_info "Owner setup completed"
        fi
    fi

    print_info ""
    print_info "Check status with: $0 logs"
    print_info ""
    print_warn "========================================="
    print_warn "IMPORTANT: First-Time Setup"
    print_warn "========================================="
    print_warn "After services are ready, run the configuration script:"
    print_warn "  ./configure-toolkit.sh"
    print_warn ""
    print_warn "This will configure:"
    print_warn "  - AI models in LiteLLM"
    print_warn "  - Virtual keys for N8N"
    print_warn "  - N8N credentials"
    print_warn "========================================="
}

# Function to stop services
stop_services() {
    print_info "Stopping DC-Masters Container Toolkit..."
    $COMPOSE_CMD stop
    print_info "Services stopped (data preserved)"
}

# Function to restart services
restart_services() {
    print_info "Restarting DC-Masters Container Toolkit..."
    $COMPOSE_CMD restart
    print_info "Services restarted"
}

# Function to show logs
show_logs() {
    if [ -n "$2" ]; then
        $COMPOSE_CMD logs -f "$2"
    else
        $COMPOSE_CMD logs -f
    fi
}

# Function to show status
show_status() {
    $COMPOSE_CMD ps
}

# Function to clean everything
clean_all() {
    print_warn "This will remove all containers and volumes!"
    read -p "Are you sure? (yes/no): " -r
    if [[ $REPLY == "yes" ]]; then
        print_info "Stopping and removing containers..."
        $COMPOSE_CMD down -v
        print_warn "Data directories preserved. To remove data, manually delete ./data/"
    else
        print_info "Cleanup cancelled"
    fi
}

# Main command handling
case "${1:-start}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    logs)
        show_logs "$@"
        ;;
    status)
        show_status
        ;;
    clean)
        clean_all
        ;;
    *)
        echo "DC-Masters Container Toolkit"
        echo ""
        echo "Usage: $0 {start|stop|restart|logs|status|clean}"
        echo ""
        echo "Commands:"
        echo "  start    - Start all services (default)"
        echo "  stop     - Stop all services (preserve data)"
        echo "  restart  - Restart all services"
        echo "  logs     - Show logs (use 'logs <service>' for specific service)"
        echo "  status   - Show service status"
        echo "  clean    - Stop and remove all containers"
        echo ""
        exit 1
        ;;
esac
