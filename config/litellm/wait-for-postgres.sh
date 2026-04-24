#!/bin/sh
# Wait for PostgreSQL to be ready before starting LiteLLM

set -e

echo "Waiting for PostgreSQL to be ready..."

# Extract host and port from DATABASE_URL
# Format: postgresql://user:pass@host:port/database
DB_HOST=$(echo $DATABASE_URL | sed -E 's/.*@([^:]+):.*/\1/')
DB_PORT=$(echo $DATABASE_URL | sed -E 's/.*:([0-9]+)\/.*/\1/')

echo "PostgreSQL host: $DB_HOST"
echo "PostgreSQL port: $DB_PORT"

# Wait for PostgreSQL to accept connections
MAX_TRIES=30
COUNT=0

while [ $COUNT -lt $MAX_TRIES ]; do
    if nc -z $DB_HOST $DB_PORT 2>/dev/null; then
        echo "PostgreSQL is accepting connections on $DB_HOST:$DB_PORT"

        # Additional check: try to connect with psql
        if command -v psql >/dev/null 2>&1; then
            if psql "$DATABASE_URL" -c "SELECT 1" >/dev/null 2>&1; then
                echo "Successfully connected to database!"
                break
            else
                echo "Port is open but database not ready yet..."
            fi
        else
            echo "PostgreSQL port is open (psql not available for verification)"
            break
        fi
    else
        echo "Waiting for PostgreSQL... ($COUNT/$MAX_TRIES)"
    fi

    COUNT=$((COUNT + 1))
    sleep 2
done

if [ $COUNT -eq $MAX_TRIES ]; then
    echo "ERROR: PostgreSQL did not become ready in time"
    exit 1
fi

echo "Starting LiteLLM..."
exec litellm "$@"
