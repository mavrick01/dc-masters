#!/usr/bin/env bash
# DC-Masters Container Toolkit - Reset Configuration Script
# Removes models, virtual keys, credentials, and workflows added by configure-toolkit.sh

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=========================================${NC}"
}

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

print_section "DC-Masters Toolkit Configuration Reset"
echo ""

print_warn "This will remove all configuration added by configure-toolkit.sh:"
print_warn "  - LiteLLM models (Gemini, GPT, Claude)"
print_warn "  - LiteLLM virtual keys"
print_warn "  - N8N credentials"
print_warn "  - N8N workflows"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    print_info "Reset cancelled"
    exit 0
fi

###########################################
# Step 1: Remove LiteLLM Models
###########################################
print_section "Step 1: Removing LiteLLM Models"

# Get all models
print_info "Fetching model list from LiteLLM..."
models_response=$(curl -s -X GET "$LITELLM_URL/model/info" \
    -H "Authorization: Bearer $MASTER_KEY")

# Models to remove (added by configure-toolkit.sh)
MODEL_NAMES=(
    "gemini-2-5-flash"
    "gemini-3.1-flash-lite-preview"
    "gemini-3.1-pro-preview"
    "text-embedding-004"
    "gpt-4"
    "gpt-35-turbo"
    "claude-3-5-sonnet"
)

for model_name in "${MODEL_NAMES[@]}"; do
    # Extract model ID from response
    model_id=$(echo "$models_response" | grep -o "\"model_name\":\"$model_name\"" -A 20 | grep -o '"model_id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$model_id" ]; then
        print_info "Removing model: $model_name (ID: $model_id)"

        delete_response=$(curl -s -X POST "$LITELLM_URL/model/delete" \
            -H "Authorization: Bearer $MASTER_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"id\": \"$model_id\"}")

        if echo "$delete_response" | grep -q "deleted"; then
            echo "  ✓ Successfully removed: $model_name"
        else
            echo "  ⊙ Could not remove: $model_name (may not exist)"
        fi
    else
        echo "  ⊙ Model not found: $model_name"
    fi
done

echo ""

###########################################
# Step 2: Remove LiteLLM Virtual Keys
###########################################
print_section "Step 2: Removing LiteLLM Virtual Keys"

print_info "Fetching virtual keys from LiteLLM..."
keys_response=$(curl -s -X GET "$LITELLM_URL/key/info" \
    -H "Authorization: Bearer $MASTER_KEY")

# Look for n8n-workflows key alias
key_id=$(echo "$keys_response" | grep -o '"key_alias":"n8n-workflows"' -B 5 | grep -o '"key":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$key_id" ]; then
    print_info "Removing virtual key: n8n-workflows"

    delete_response=$(curl -s -X POST "$LITELLM_URL/key/delete" \
        -H "Authorization: Bearer $MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"key\": \"$key_id\"}")

    if echo "$delete_response" | grep -q "deleted"; then
        echo "  ✓ Successfully removed virtual key"
    else
        echo "  ⊙ Could not remove virtual key"
    fi
else
    echo "  ⊙ Virtual key 'n8n-workflows' not found"
fi

echo ""

###########################################
# Step 3: Remove N8N Credentials
###########################################
print_section "Step 3: Removing N8N Credentials"

# Credentials to remove (added by configure-toolkit.sh)
CREDENTIAL_NAMES=(
    "Google Cloud - Vertex AI"
    "PostgreSQL - Embeddings DB"
    "PostgreSQL - AIRS DB"
    "LiteLLM API"
)

print_info "Fetching credentials from N8N..."
creds_response=$(curl -s -X GET "$N8N_URL/api/v1/credentials" \
    -u "${N8N_OWNER_EMAIL:-admin@dcmasters.local}:${N8N_OWNER_PASSWORD:-changeme123}")

for cred_name in "${CREDENTIAL_NAMES[@]}"; do
    # Extract credential ID from response
    cred_id=$(echo "$creds_response" | grep -o "\"name\":\"$cred_name\"" -B 5 | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$cred_id" ]; then
        print_info "Removing credential: $cred_name (ID: $cred_id)"

        delete_response=$(curl -s -X DELETE "$N8N_URL/api/v1/credentials/$cred_id" \
            -u "${N8N_OWNER_EMAIL:-admin@dcmasters.local}:${N8N_OWNER_PASSWORD:-changeme123}")

        if [ $? -eq 0 ]; then
            echo "  ✓ Successfully removed: $cred_name"
        else
            echo "  ⊙ Could not remove: $cred_name"
        fi
    else
        echo "  ⊙ Credential not found: $cred_name"
    fi
done

echo ""

###########################################
# Step 4: Remove N8N Workflows
###########################################
print_section "Step 4: Removing N8N Workflows"

WORKFLOW_FILES=(
    "1-embedding-agent.json"
    "2-basic-ai-agent.json"
    "3-advanced-ai-agent.json"
    "4-airs-pdf-downloader.json"
    "5-airs-chatbot.json"
)

print_info "Fetching workflows from N8N..."
workflows_response=$(curl -s -X GET "$N8N_URL/api/v1/workflows" \
    -u "${N8N_OWNER_EMAIL:-admin@dcmasters.local}:${N8N_OWNER_PASSWORD:-changeme123}")

for workflow_file in "${WORKFLOW_FILES[@]}"; do
    # Extract workflow name without extension
    workflow_basename="${workflow_file%.json}"

    # Try to find workflow ID by matching name pattern
    workflow_id=$(echo "$workflows_response" | grep -o "\"name\":\"[^\"]*$workflow_basename[^\"]*\"" -B 5 | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$workflow_id" ]; then
        print_info "Removing workflow: $workflow_file (ID: $workflow_id)"

        delete_response=$(curl -s -X DELETE "$N8N_URL/api/v1/workflows/$workflow_id" \
            -u "${N8N_OWNER_EMAIL:-admin@dcmasters.local}:${N8N_OWNER_PASSWORD:-changeme123}")

        if [ $? -eq 0 ]; then
            echo "  ✓ Successfully removed: $workflow_file"
        else
            echo "  ⊙ Could not remove: $workflow_file"
        fi
    else
        echo "  ⊙ Workflow not found: $workflow_file"
    fi
done

echo ""

###########################################
# Step 5: Remove Marker File
###########################################
print_section "Step 5: Removing Marker File"

MARKER_FILE="data/n8n/.workflows_imported"
if [ -f "$MARKER_FILE" ]; then
    rm "$MARKER_FILE"
    print_info "✓ Removed marker file: $MARKER_FILE"
else
    print_info "⊙ Marker file not found (already removed)"
fi

echo ""

###########################################
# Summary
###########################################
print_section "Reset Complete!"
echo ""
print_info "Configuration has been reset to pre-configure state"
print_info "You can now run ./configure-toolkit.sh again if needed"
echo ""
