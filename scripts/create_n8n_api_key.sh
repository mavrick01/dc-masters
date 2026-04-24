#! /bin/bash

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
    >&2 echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    >&2 echo -e "${BLUE}=========================================${NC}"
    >&2 echo -e "${BLUE}$1${NC}"
    >&2 echo -e "${BLUE}=========================================${NC}"
}

# Commenting out set -e for debugging
# set -e

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


# Get N8N API key

print_info "Authenticating with N8N..."
print_info "N8N URL: $N8N_URL"

# Step 1: Login to get session cookie
print_info "Sending login request..."
login_response=$(curl -s -i --max-time 10 -X POST "$N8N_URL/rest/login" \
    -H "Content-Type: application/json" \
    -d "{
        \"emailOrLdapLoginId\": \"${N8N_OWNER_EMAIL:-admin@dcmasters.local}\",
        \"password\": \"${N8N_OWNER_PASSWORD:-changeme123}\"
    }")

print_info "Login response received"

# Extract session cookie
session_cookie=$(echo "$login_response" | grep -i "set-cookie:" | grep "n8n-auth" | sed 's/.*n8n-auth=\([^;]*\).*/n8n-auth=\1/')

if [ -z "$session_cookie" ]; then
    print_error "Failed to authenticate with N8N"
    print_error "Response:"
    print_error "$login_response" | grep -v "^$" | tail -5
    return 1
fi

print_info "Session obtained, creating API key..."

# Step 2: Create API key using session cookie
# Set expiration to 1 hour from now (in milliseconds)
expires_at=$(($(date +%s)*10 + 600))

print_info "Creating API key..."
api_key_response=$(curl -s --max-time 10 -X POST "$N8N_URL/rest/api-keys" \
    -H "Cookie: $session_cookie" \
    -H "Content-Type: application/json" \
    -d '{
        "label": "configure-toolkit",
        "scopes": ["credential:create", "credential:read", "credential:update", "credential:delete", "workflow:create", "workflow:read", "workflow:update", "workflow:delete"],
        "expiresAt": '"$expires_at"'
    }')
print_info "API key response received"

# Extract API key ID and rawApiKey
api_key_id=$(echo "$api_key_response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
api_key=$(echo "$api_key_response" | grep -o '"rawApiKey":"[^"]*"' | cut -d'"' -f4)

if [ -z "$api_key" ]; then
    print_error "Failed to create N8N API key"
    print_error "Response:"
    print_error "$api_key_response"
    return 1
fi

print_info "  ✓ N8N API key created"
# Return session cookie, ID, and key separated by pipe
echo "${session_cookie}|${api_key_id}|${api_key}"
