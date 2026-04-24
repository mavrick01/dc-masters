#!/usr/bin/env bash
# Remove N8N workflows

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

# Check if workflow files exist
if ! ls workflows/*.json >/dev/null 2>&1; then
    print_info "No workflow JSON files found in workflows/"
    print_info "Nothing to remove"
    exit 0
fi

# Process each workflow JSON file
for workflow_file in workflows/*.json; do
    filename=$(basename "$workflow_file")

    # Extract workflow ID directly from JSON file
    workflow_id=$(grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' "$workflow_file" | tail -1 | sed 's/"id"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')

    # Extract workflow name for display
    workflow_name=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$workflow_file" | head -1 | sed 's/"name"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')

    if [ -z "$workflow_id" ]; then
        echo "  ⊙ Could not extract ID from: $filename"
        continue
    fi

    print_info "Removing workflow: $workflow_name (ID: $workflow_id)"

    delete_response=$(curl -s -X DELETE "$N8N_URL/api/v1/workflows/$workflow_id" \
        -H "X-N8N-API-KEY: $N8N_API_KEY")

    if [ $? -eq 0 ]; then
        echo "  ✓ Successfully removed: $workflow_name"
    else
        echo "  ⊙ Could not remove: $workflow_name (ID: $workflow_id)"
    fi
done

print_info "Workflow removal complete"
