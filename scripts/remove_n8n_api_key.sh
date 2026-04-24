#!/usr/bin/env bash
# Remove N8N API key by label (finds and deletes API keys with specific label)

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    >&2 echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    >&2 echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    >&2 echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

N8N_URL="${N8N_URL:-http://localhost:5678}"

# Get label to search for (default: configure-toolkit)
LABEL="${1:-configure-toolkit}"

print_info "Authenticating with N8N..."

# Step 1: Login to get session cookie
login_response=$(curl -s -i --max-time 10 -X POST "$N8N_URL/rest/login" \
    -H "Content-Type: application/json" \
    -d "{
        \"emailOrLdapLoginId\": \"${N8N_OWNER_EMAIL:-admin@dcmasters.local}\",
        \"password\": \"${N8N_OWNER_PASSWORD:-changeme123}\"
    }")

# Extract session cookie
session_cookie=$(echo "$login_response" | grep -i "set-cookie:" | grep "n8n-auth" | sed 's/.*n8n-auth=\([^;]*\).*/n8n-auth=\1/')

if [ -z "$session_cookie" ]; then
    print_error "Failed to authenticate with N8N"
    exit 1
fi

print_info "Session obtained, fetching API keys..."

# Step 2: Get all API keys
api_keys_response=$(curl -s --max-time 10 -X GET "$N8N_URL/rest/api-keys" \
    -H "Cookie: $session_cookie" \
    -H "Content-Type: application/json")

# Step 3: Find API key ID with matching label using Python
api_key_id=$(echo "$api_keys_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for key in data.get('data', []):
        if key.get('label') == '$LABEL':
            print(key.get('id', ''))
            break
except Exception as e:
    print('', file=sys.stderr)
" 2>/dev/null)

if [ -z "$api_key_id" ]; then
    print_warn "No API key found with label: $LABEL"
    exit 0
fi

print_info "Found API key with label '$LABEL' (ID: $api_key_id)"

# Step 4: Delete the API key
print_info "Deleting API key..."
delete_response=$(curl -s -w "\n%{http_code}" -X DELETE "$N8N_URL/rest/api-keys/$api_key_id" \
    -H "Cookie: $session_cookie" \
    -H "Content-Type: application/json")

http_code=$(echo "$delete_response" | tail -1)
response_body=$(echo "$delete_response" | sed '$d')

if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
    echo "  ✓ API key deleted successfully"
    exit 0
else
    print_error "Failed to delete API key (HTTP $http_code)"
    echo "    Response: $response_body"
    exit 1
fi
