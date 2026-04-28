#!/usr/bin/env bash
# Reset N8N Owner Account
# This script deletes the existing owner and recreates it with current .env values

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

# Detect container runtime
RUNTIME=${CONTAINER_RUNTIME:-podman}
if ! command -v "$RUNTIME" &> /dev/null; then
    RUNTIME="docker"
fi

print_info "Using container runtime: $RUNTIME"

# Check if N8N container is running
if ! $RUNTIME ps | grep -q dc-masters-n8n; then
    print_error "N8N container is not running!"
    print_info "Start services with: ./start-toolkit.sh start"
    exit 1
fi

print_warn "This will DELETE the existing N8N owner account and recreate it!"
print_warn "Current owner email: ${N8N_OWNER_EMAIL:-admin@dcmasters.local}"
print_warn "New password will be: ${N8N_OWNER_PASSWORD:-changeme123}"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    print_info "Aborted."
    exit 0
fi

print_info "Deleting existing owner account..."

# Delete existing owner from database
$RUNTIME exec dc-masters-postgres psql -U dcmasters -d n8n -c \
    "DELETE FROM public.user WHERE \"roleSlug\" = 'global:owner';" 2>&1

print_info "Creating new owner account with values from .env..."

# Create new owner with environment variables
$RUNTIME exec -i dc-masters-postgres psql -U dcmasters -d n8n \
    -v owner_email="${N8N_OWNER_EMAIL:-admin@dcmasters.local}" \
    -v owner_password="${N8N_OWNER_PASSWORD:-changeme123}" \
    -v owner_first_name="${N8N_OWNER_FIRST_NAME:-Admin}" \
    -v owner_last_name="${N8N_OWNER_LAST_NAME:-User}" \
    -f - < config/n8n/create-owner.sql 2>&1 | grep "NOTICE" | sed 's/NOTICE:  //'

print_info ""
print_info "Owner account reset complete!"
print_info "Login at: http://localhost:5678"
print_info "Email: ${N8N_OWNER_EMAIL:-admin@dcmasters.local}"
print_info "Password: ${N8N_OWNER_PASSWORD:-changeme123}"
