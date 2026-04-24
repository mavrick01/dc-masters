#!/usr/bin/env bash
# Wait for a service to be ready

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage: ./wait_for_service.sh <service_name> <url> [max_wait_seconds]
SERVICE_NAME="${1:-Service}"
URL="${2:-http://localhost:4000/health/liveness}"
MAX_WAIT="${3:-60}"

if [ -z "$URL" ]; then
    print_error "Usage: $0 <service_name> <url> [max_wait_seconds]"
    exit 1
fi

print_info "Waiting for $SERVICE_NAME to be ready..."
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -s -o /dev/null -w "%{http_code}" "$URL" | grep -q "200\|401\|403"; then
        print_info "$SERVICE_NAME is ready!"
        exit 0
    fi
    sleep 2
    WAITED=$((WAITED + 2))
done

print_error "$SERVICE_NAME did not become ready in time"
exit 1
