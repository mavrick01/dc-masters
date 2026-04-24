#!/usr/bin/env bash
# Create N8N credentials

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    >&2  echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    >&2 echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    >&2  echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

N8N_URL="${N8N_URL:-http://localhost:5678}"

# Require N8N_API_KEY to be passed or set
if [ -z "$N8N_API_KEY" ]; then
    print_error "N8N_API_KEY environment variable is required"
    print_info "Run: export N8N_API_KEY=\$(scripts/create_n8n_api_key.sh | cut -d'|' -f3)"
    exit 1
fi

# Create a single credential
create_credential() {
    local cred_name=$1
    local cred_type=$2
    local cred_data=$3

    print_info "Creating N8N credential: $cred_name ($cred_type)"


    # Construct the full payload using jq to ensure proper JSON escaping
    payload=$(jq -n \
        --arg name "$cred_name" \
        --arg type "$cred_type" \
        --argjson data "$cred_data" \
        '{
            name: $name,
            type: $type,
            data: $data,
            isGlobal: true,
            isResolvable: false
        }')

    response=$(curl -s -X POST "$N8N_URL/api/v1/credentials" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload")
    if echo "$response" | grep -q "id"; then
        cred_id=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        print_info  "  ✓ Created credential: $cred_name (ID: $cred_id)"
        echo "$cred_id"
        return 0
    else
        print_error "  ✗ Failed to create credential: $cred_name"
        print_error "    Response: $response"
        return 1
    fi
}

# Create Google Cloud credential
if [ -f "credentials/google_credentials.json" ]; then
    cred_data=$(cat credentials/google_credentials.json | jq -c '{
        email: .client_email,
        privateKey: .private_key,
        inpersonate: false,
        httpNode: false
    }')

    create_credential "Google Cloud - Vertex AI" "googleApi" "$cred_data"
else
    print_warn "Google credentials file not found at credentials/google_credentials.json"
    print_warn "Skipping Google Cloud credential creation"
fi

# Create PostgreSQL credential for embeddings
create_credential \
    "PostgreSQL - Embeddings DB" \
    "postgres" \
    "{
        \"host\": \"postgres\",
        \"database\": \"litellm\",
        \"user\": \"${POSTGRES_USER:-dcmasters}\",
        \"password\": \"${POSTGRES_PASSWORD:-changeme123}\",
        \"port\": 5432,
        \"ssl\": \"disable\",
        \"allowUnauthorizedCerts\": false,
        \"sshTunnel\": false
    }"

# Create PostgreSQL credential for AIRS
create_credential \
    "PostgreSQL - AIRS DB" \
    "postgres" \
    "{
        \"host\": \"postgres\",
        \"database\": \"airs_embedding\",
        \"user\": \"${POSTGRES_USER:-dcmasters}\",
        \"password\": \"${POSTGRES_PASSWORD:-changeme123}\",
        \"port\": 5432,
        \"ssl\": \"disable\",
        \"allowUnauthorizedCerts\": false,
        \"sshTunnel\": false
    }"

# Create LiteLLM API credential if virtual key provided
if [ -n "$LITELLM_VIRTUAL_KEY" ]; then
    create_credential \
        "LiteLLM API" \
        "openAiApi" \
        "{
            \"header\": false,
            \"url\": \"http://litellm:4000\",
            \"apiKey\": \"$LITELLM_VIRTUAL_KEY\"
        }"
else
    print_warn "LITELLM_VIRTUAL_KEY not set - skipping LiteLLM credential creation"
    print_info "Run: export LITELLM_VIRTUAL_KEY=\$(scripts/create_virtual_key.sh)"
fi

print_info "N8N credential creation complete"
