#!/usr/bin/env bash
# Add LiteLLM models from config.yaml

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

LITELLM_URL="${LITELLM_URL:-http://localhost:4000}"
MASTER_KEY="${LITELLM_MASTER_KEY:-sk-1234-changeme}"

# Add a single model
add_model() {
    local model_name=$1
    local model_params=$2

    print_info "Adding model: $model_name"

    response=$(curl -s -X POST "$LITELLM_URL/model/new" \
        -H "Authorization: Bearer $MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d "$model_params")

    if echo "$response" | grep -q "model_name"; then
        echo "  ✓ Successfully added $model_name"
        return 0
    else
        echo "  ✗ Failed to add $model_name"
        echo "    Response: $response"
        return 1
    fi
}

# Parse models from config.yaml
if ! command -v python3 &> /dev/null; then
    print_error "python3 is required to parse config.yaml"
    exit 1
fi

print_info "Reading model configurations from config/litellm/config.yaml..."

models_json=$(python3 config/litellm/parse-models.py config/litellm/config.yaml 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$models_json" ]; then
    print_error "Failed to parse model configurations from config.yaml"
    exit 1
fi

# Count models
model_count=$(echo "$models_json" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))")
print_info "Found $model_count models to configure"

# Add each model
echo "$models_json" | python3 -c "
import sys, json
models = json.load(sys.stdin)
for model in models:
    print(json.dumps(model))
" | while read -r model_config; do
    model_name=$(echo "$model_config" | python3 -c "import sys, json; print(json.load(sys.stdin)['model_name'])")
    add_model "$model_name" "$model_config"
done

print_info "Model configuration complete"
