#!/bin/bash
# Entrypoint script for MCP SearXNG server
# Handles corporate CA certificate installation

set -e

# Check if corporate CA certificate exists
if [ -f "/app/certs/company-ca.pem" ]; then
    echo "[MCP SearXNG] Corporate CA certificate detected"

    # Copy to system CA certificates directory
    cp /app/certs/company-ca.pem /usr/local/share/ca-certificates/company-ca.crt

    # Update CA certificates
    update-ca-certificates

    echo "[MCP SearXNG] ✓ CA certificates updated"

    # Set Node.js to use system CA certificates
    export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
else
    echo "[MCP SearXNG] No corporate CA certificate found, using system defaults"
fi

# Execute the main command
exec "$@"
