#!/usr/bin/env bash
# Remove N8N credentials

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    >&2 echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    >&2 echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

N8N_URL="${N8N_URL:-http://localhost:5678}"

# Require N8N_API_KEY
if [ -z "$N8N_API_KEY" ]; then
    print_error "N8N_API_KEY environment variable is required"
    exit 1
fi

CREDENTIAL_NAMES=(
    "Google Cloud - Vertex AI"
    "PostgreSQL - Embeddings DB"
    "PostgreSQL - AIRS DB"
    "LiteLLM API"
    "LiteLLM API Bearer Token"
)

print_info "Fetching credentials from N8N..."
creds_response=$(curl -s -X GET "$N8N_URL/api/v1/credentials" \
    -H "X-N8N-API-KEY: $N8N_API_KEY")

for cred_name in "${CREDENTIAL_NAMES[@]}"; do
    # Use jq to properly parse JSON and extract all matching credential IDs
    cred_ids=$(echo "$creds_response" | jq -r ".data[] | select(.name == \"$cred_name\") | .id")

    if [ -n "$cred_ids" ]; then
        # Process each credential ID (in case of duplicates)
        while IFS= read -r cred_id; do
            print_info "Removing credential: $cred_name (ID: $cred_id)"

            delete_response=$(curl -s -X DELETE "$N8N_URL/api/v1/credentials/$cred_id" \
                -H "X-N8N-API-KEY: $N8N_API_KEY")

            if [ $? -eq 0 ]; then
                echo "  ✓ Successfully removed: $cred_name"
            else
                echo "  ⊙ Could not remove: $cred_name"
            fi
        done <<< "$cred_ids"
    else
        echo "  ⊙ Credential not found: $cred_name"
    fi
done

print_info "N8N credential removal complete"
