#!/bin/sh
# N8N Workflow Import Script
# Automatically imports pre-configured workflows on first startup

set -e

echo "[N8N Import] Starting workflow import process..."

# Wait for N8N to be ready
echo "[N8N Import] Waiting for N8N to be ready..."
MAX_WAIT=120
WAIT_TIME=0

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    if nc -z localhost 5678 2>/dev/null; then
        echo "[N8N Import] N8N is ready!"
        break
    fi
    echo "[N8N Import] Waiting for N8N to start... ($WAIT_TIME/$MAX_WAIT seconds)"
    sleep 5
    WAIT_TIME=$((WAIT_TIME + 5))
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    echo "[N8N Import] ERROR: N8N did not start within $MAX_WAIT seconds"
    exit 1
fi

# Additional wait for database initialization
echo "[N8N Import] Waiting for database initialization..."
sleep 10

# Check if workflows already imported
WORKFLOW_DIR="/workflows"
MARKER_FILE="/home/node/.n8n/.workflows_imported"

if [ -f "$MARKER_FILE" ]; then
    echo "[N8N Import] Workflows already imported (marker file exists)"
    echo "[N8N Import] To re-import, delete: $MARKER_FILE"
    exit 0
fi

# Import workflows
echo "[N8N Import] Importing workflows from $WORKFLOW_DIR..."

for workflow_file in "$WORKFLOW_DIR"/*.json; do
    if [ -f "$workflow_file" ]; then
        workflow_name=$(basename "$workflow_file")
        echo "[N8N Import] Importing: $workflow_name"

        # Use n8n import command
        if n8n import:workflow --input="$workflow_file" 2>&1; then
            echo "[N8N Import] ✓ Successfully imported: $workflow_name"
        else
            echo "[N8N Import] ✗ Failed to import: $workflow_name"
            echo "[N8N Import] This may be expected if the workflow already exists"
        fi
    fi
done

# Create marker file to prevent re-import
touch "$MARKER_FILE"
echo "[N8N Import] Created marker file: $MARKER_FILE"

echo "[N8N Import] Workflow import process completed!"
echo ""
echo "=============================================="
echo "IMPORTANT: Configure Workflow Credentials"
echo "=============================================="
echo ""
echo "Workflows have been imported but are INACTIVE."
echo ""
echo "Next steps:"
echo "1. Access N8N at http://localhost:5678"
echo "2. Go to Settings > Credentials"
echo "3. Create the following credentials:"
echo "   - Google Cloud (service account JSON)"
echo "   - PostgreSQL (for embeddings database)"
echo "   - PostgreSQL (for AIRS database)"
echo "   - LiteLLM API (HTTP Bearer Auth)"
echo "4. Open each workflow and assign credentials"
echo "5. Activate workflows"
echo ""
echo "See README.md for detailed instructions."
echo "=============================================="

exit 0
