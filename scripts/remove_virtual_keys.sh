#!/usr/bin/env bash
# Remove LiteLLM virtual keys

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    >&2 echo -e "${GREEN}[INFO]${NC} $1"
}

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

LITELLM_URL="${LITELLM_URL:-http://localhost:4000}"
MASTER_KEY="${LITELLM_MASTER_KEY:-sk-1234-changeme}"

print_info "Fetching virtual keys from LiteLLM..."
keys_response=$(curl -s -X GET "$LITELLM_URL/key/info" \
    -H "Authorization: Bearer $MASTER_KEY")

key_alias=n8n-workflows

if [ -n "$key_alias" ]; then
    print_info "Removing virtual key: $key_alias"

    delete_response=$(curl -s -X POST "$LITELLM_URL/key/delete" \
        -H "Authorization: Bearer $MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"key_aliases\": [ \"$key_alias\" ] }")

    if echo "$delete_response" | grep -q "deleted"; then
        echo "  ✓ Successfully removed virtual key"
    else
        echo "  ⊙ Could not remove virtual key"
    fi
else
    echo "  ⊙ Virtual key 'n8n-workflows' not found"
fi

print_info "Virtual key removal complete"
