#!/bin/sh
# N8N Owner Account Setup Script
# Creates the owner account if it doesn't exist

set -e

echo "[N8N Setup] Waiting for N8N to be ready..."
sleep 15

# Check if owner already exists
OWNER_EXISTS=$(n8n user:list 2>/dev/null | grep -c "${N8N_OWNER_EMAIL:-admin@dcmasters.local}" || echo "0")

if [ "$OWNER_EXISTS" -eq "0" ]; then
    echo "[N8N Setup] Creating owner account..."

    # Create owner using the API
    # N8N's setup endpoint allows creating the first user
    curl -X POST http://localhost:5678/api/v1/owner/setup \
      -H "Content-Type: application/json" \
      -d "{
        \"email\": \"${N8N_OWNER_EMAIL:-admin@dcmasters.local}\",
        \"firstName\": \"${N8N_OWNER_FIRST_NAME:-Admin}\",
        \"lastName\": \"${N8N_OWNER_LAST_NAME:-User}\",
        \"password\": \"${N8N_OWNER_PASSWORD:-changeme123}\"
      }" 2>&1 || echo "[N8N Setup] Owner setup API call completed (may have already been set up)"

    echo "[N8N Setup] Owner account setup completed!"
else
    echo "[N8N Setup] Owner account already exists, skipping creation"
fi

exit 0
