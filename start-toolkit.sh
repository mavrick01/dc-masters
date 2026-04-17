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
    COMPOSE_CMD="podman-compose"
    if ! command -v podman &> /dev/null; then
        print_error "Podman is not installed or not in PATH"
        exit 1
    fi
    if ! command -v podman-compose &> /dev/null; then
        print_error "podman-compose is not installed or not in PATH"
        print_info "Install with: pip install podman-compose"
        exit 1
    fi
fi

print_info "Using container runtime: $RUNTIME"
print_info "Using compose command: $COMPOSE_CMD"

# Function to start services
start_services() {
    print_info "Creating data directories..."
    mkdir -p data/{postgres,n8n,sandbox/{import,shared}}

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
    print_info "  - N8N: ${N8N_BASIC_AUTH_USER:-admin} / ${N8N_BASIC_AUTH_PASSWORD:-changeme123}"
    print_info "  - PostgreSQL: ${POSTGRES_USER:-dcmasters} / ${POSTGRES_PASSWORD:-changeme123}"
    print_info ""
    print_warn "Please wait a few minutes for all services to initialize..."
    print_info "Check status with: $0 logs"
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
