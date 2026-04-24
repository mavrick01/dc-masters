#!/usr/bin/env bash
# Remove LiteLLM models

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
   >&2  echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
   >&2  echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

LITELLM_URL="${LITELLM_URL:-http://localhost:4000}"
MASTER_KEY="${LITELLM_MASTER_KEY:-sk-1234-changeme}"

print_info "Fetching model list from LiteLLM..."
models_response=$(curl -s -X GET "$LITELLM_URL/model/info" \
    -H "Authorization: Bearer $MASTER_KEY")

# Get model names from config.yaml
print_info "Reading model names from config/litellm/config.yaml..."
models_json=$(python3 config/litellm/parse-models.py config/litellm/config.yaml 2>/dev/null || echo "[]")

# Extract model names into array (bash 3 compatible)
MODEL_NAMES=()
while IFS= read -r model_name; do
    MODEL_NAMES+=("$model_name")
done < <(echo "$models_json" | python3 -c "
import sys, json
try:
    models = json.load(sys.stdin)
    for model in models:
        print(model['model_name'])
except:
    pass
" 2>/dev/null)

# Remove each model
for model_name in "${MODEL_NAMES[@]}"; do
    # Extract model ID using Python to parse JSON properly
    model_id=$(echo "$models_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    models = data.get('data', [])
    for model in models:
        if model.get('model_name') == '$model_name':
            print(model.get('model_info', {}).get('id', ''))
            break
except:
    pass
" 2>/dev/null)

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

print_info "Model removal complete"
