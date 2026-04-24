#!/usr/bin/env bash
# Create LiteLLM virtual key for N8N

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

LITELLM_URL="${LITELLM_URL:-http://localhost:4000}"
MASTER_KEY="${LITELLM_MASTER_KEY:-sk-1234-changeme}"

# Usage: ./create_virtual_key.sh [key_name] [models_json]
KEY_NAME="${1:-n8n-workflows}"
MODELS="${2:-[\"gemini-2-5-flash\", \"gemini-3.1-flash-lite-preview\", \"gemini-3.1-pro-preview\", \"text-embedding-005\"]}"

print_info "Creating virtual key: $KEY_NAME"

response=$(curl -s -X POST "$LITELLM_URL/key/generate" \
    -H "Authorization: Bearer $MASTER_KEY" \
    -H "Content-Type: application/json" \
    -d "{
        \"key_alias\": \"$KEY_NAME\",
        \"models\": $MODELS,
        \"max_budget\": null
    }")

if echo "$response" | grep -q "key"; then
    virtual_key=$(echo "$response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    print_info "  ✓ Created virtual key: $KEY_NAME"
    echo "$virtual_key"
    exit 0
else
    print_error "  ✗ Failed to create virtual key"
    print_error "    Response: $response"
    exit 1
fi
