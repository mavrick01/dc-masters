# DC-Masters Toolkit Scripts

This directory contains modular scripts for configuring and managing the DC-Masters container toolkit.

## Overview

The main `configure-toolkit.sh` orchestrates these scripts, but you can run them individually for granular control.

## Script Categories

### Service Utilities
- **`wait_for_service.sh`** - Wait for a service to become healthy
  ```bash
  ./scripts/wait_for_service.sh "LiteLLM" "http://localhost:4000/health" 60
  ```

### Authentication
- **`get_n8n_api_key.sh`** - Get temporary N8N API key (10-minute expiration)
  ```bash
  # Returns: session_cookie|api_key_id|api_key
  api_data=$(./scripts/get_n8n_api_key.sh)
  export N8N_SESSION_COOKIE=$(echo "$api_data" | cut -d'|' -f1)
  export N8N_API_KEY_ID=$(echo "$api_data" | cut -d'|' -f2)
  export N8N_API_KEY=$(echo "$api_data" | cut -d'|' -f3)
  ```

- **`remove_n8n_api_key.sh`** - Delete temporary N8N API key (cleanup)
  ```bash
  # Using environment variables
  ./scripts/remove_n8n_api_key.sh
  
  # Or pass directly
  ./scripts/remove_n8n_api_key.sh "$N8N_API_KEY_ID" "$N8N_SESSION_COOKIE"
  ```

### LiteLLM Models
- **`add_litellm_models.sh`** - Add models from config.yaml
  ```bash
  ./scripts/add_litellm_models.sh
  ```
  
- **`remove_litellm_models.sh`** - Remove models
  ```bash
  ./scripts/remove_litellm_models.sh
  ```

### MCP Servers
- **`add_mcp_servers.sh`** - Add filesystem and duckduckgo MCP servers
  ```bash
  ./scripts/add_mcp_servers.sh
  ```
  
- **`remove_mcp_servers.sh`** - Remove MCP servers
  ```bash
  ./scripts/remove_mcp_servers.sh
  ```

### Virtual Keys
- **`create_virtual_key.sh`** - Create LiteLLM virtual key for N8N
  ```bash
  # Default: n8n-workflows key with Gemini models
  virtual_key=$(./scripts/create_virtual_key.sh)
  
  # Custom key name and models
  virtual_key=$(./scripts/create_virtual_key.sh "my-key" '["gpt-4", "claude-3-5-sonnet"]')
  ```
  
- **`remove_virtual_keys.sh`** - Remove virtual keys
  ```bash
  ./scripts/remove_virtual_keys.sh
  ```

### N8N Credentials
- **`create_n8n_credentials.sh`** - Create all N8N credentials
  ```bash
  export N8N_API_KEY="your-api-key"
  export LITELLM_VIRTUAL_KEY="sk-litellm-..."
  ./scripts/create_n8n_credentials.sh
  ```
  
- **`remove_n8n_credentials.sh`** - Remove N8N credentials
  ```bash
  export N8N_API_KEY="your-api-key"
  ./scripts/remove_n8n_credentials.sh
  ```

### Workflows
- **`import_workflows.sh`** - Import workflows from workflows/ directory
  ```bash
  ./scripts/import_workflows.sh
  ```
  
- **`remove_workflows.sh`** - Remove workflows
  ```bash
  export N8N_API_KEY="your-api-key"
  ./scripts/remove_workflows.sh
  ```

## Common Usage Patterns

### Full Setup (Automated)
```bash
./configure-toolkit.sh
```

### Full Reset
```bash
./configure-toolkit.sh clean
```

### Selective Operations

**Add only LiteLLM models:**
```bash
./scripts/add_litellm_models.sh
```

**Recreate N8N credentials:**
```bash
# Get API key
api_data=$(./scripts/get_n8n_api_key.sh)
export N8N_SESSION_COOKIE=$(echo "$api_data" | cut -d'|' -f1)
export N8N_API_KEY_ID=$(echo "$api_data" | cut -d'|' -f2)
export N8N_API_KEY=$(echo "$api_data" | cut -d'|' -f3)

# Remove old credentials
./scripts/remove_n8n_credentials.sh

# Create new credentials
export LITELLM_VIRTUAL_KEY=$(./scripts/create_virtual_key.sh)
./scripts/create_n8n_credentials.sh

# Cleanup temporary API key
./scripts/remove_n8n_api_key.sh
```

**Re-import workflows:**
```bash
# Get API key
api_data=$(./scripts/get_n8n_api_key.sh)
export N8N_API_KEY=$(echo "$api_data" | cut -d'|' -f3)

# Remove old workflows
./scripts/remove_workflows.sh

# Import new workflows
./scripts/import_workflows.sh
```

**Add MCP servers after initial setup:**
```bash
./scripts/add_mcp_servers.sh
```

## Environment Variables

Most scripts read from `.env` but these can be overridden:

| Variable | Description | Default |
|----------|-------------|---------|
| `LITELLM_URL` | LiteLLM API URL | `http://localhost:4000` |
| `N8N_URL` | N8N API URL | `http://localhost:5678` |
| `LITELLM_MASTER_KEY` | LiteLLM admin key | From `.env` |
| `N8N_API_KEY` | N8N temporary API key | From `get_n8n_api_key.sh` |
| `N8N_API_KEY_ID` | N8N API key ID (for deletion) | From `get_n8n_api_key.sh` |
| `N8N_SESSION_COOKIE` | N8N session cookie | From `get_n8n_api_key.sh` |
| `LITELLM_VIRTUAL_KEY` | LiteLLM virtual key | From `create_virtual_key.sh` |
| `POSTGRES_USER` | PostgreSQL username | `dcmasters` |
| `POSTGRES_PASSWORD` | PostgreSQL password | From `.env` |

## Script Dependencies

```
configure-toolkit.sh (orchestrator)
├── wait_for_service.sh
├── get_n8n_api_key.sh
├── add_litellm_models.sh
│   └── config/litellm/parse-models.py
├── add_mcp_servers.sh
├── create_virtual_key.sh
├── create_n8n_credentials.sh
│   ├── Requires: N8N_API_KEY
│   └── Optional: LITELLM_VIRTUAL_KEY
└── import_workflows.sh
```

## Error Handling

All scripts:
- Exit with code `0` on success
- Exit with code `1` on failure
- Output errors to stderr
- Use colored output for clarity (can be disabled by setting `NO_COLOR=1`)

## Development

### Adding a New Script

1. Create the script in `scripts/`
2. Add the standard header with colors and print functions
3. Make it executable: `chmod +x scripts/your-script.sh`
4. Add error handling with `set -e`
5. Load `.env` if needed
6. Document it in this README

### Standard Template

```bash
#!/usr/bin/env bash
# Description of what this script does

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Your script logic here
print_info "Script started"
```

## Testing

Test individual scripts before running the full orchestrator:

```bash
# Dry run - check services are up
./scripts/wait_for_service.sh "LiteLLM" "http://localhost:4000/health"
./scripts/wait_for_service.sh "N8N" "http://localhost:5678"

# Test authentication
./scripts/get_n8n_api_key.sh

# Test read-only operations first
curl -s http://localhost:4000/model/info

# Then test write operations
./scripts/add_litellm_models.sh
```

## Troubleshooting

**"Service not ready" errors:**
- Check containers are running: `podman ps`
- Check logs: `podman logs dc-masters-litellm`
- Increase timeout: `./scripts/wait_for_service.sh "Service" "url" 120`

**"API key failed" errors:**
- Verify N8N credentials in `.env`
- Check N8N is accessible: `curl http://localhost:5678`
- Try manual login at http://localhost:5678

**"Model already exists" warnings:**
- This is normal - script will skip existing models
- To replace: run `./scripts/remove_litellm_models.sh` first

**Import failures:**
- Check workflow JSON files exist in `workflows/`
- Verify N8N database is initialized
- Check for syntax errors in JSON files
