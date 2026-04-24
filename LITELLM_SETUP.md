# LiteLLM Configuration Guide

This guide explains how to configure AI models in LiteLLM using the database-backed approach.

## Overview

LiteLLM is configured to store all model configurations in the PostgreSQL database. This provides:

- ✅ Dynamic model management via UI or API
- ✅ No file-based configuration conflicts
- ✅ Persistent model settings across restarts
- ✅ Easy model updates without restarting containers

## Quick Setup

### Step 1: Start the Toolkit

```bash
./start-toolkit.sh start
```

Wait for all services to be ready.

### Step 2: Configure via Script

Run the automated configuration script:

```bash
./configure-toolkit.sh
```

This will:
- Read model definitions from `config/litellm/config.yaml`
- Add Vertex AI Gemini models (gemini-2-5-flash, gemini-3.1-flash-lite-preview, gemini-3.1-pro-preview, gemini-2-0-flash)
- Add Vertex AI embeddings (text-embedding-004)
- Add Azure OpenAI models (if credentials configured in `.env`)
- Add AWS Bedrock Claude models (if credentials configured in `.env`)
- Create virtual keys for N8N access
- Configure N8N credentials

**Note**: Model configurations are defined in `config/litellm/config.yaml`. Edit this file to add or modify models, then run `./configure-toolkit.sh` to apply changes.

### Step 3: Verify Models

Access LiteLLM UI: http://localhost:4000

Login with:
- Username: `admin@dcmasters.local`
- Password: `changeme123` (or your configured password)

Navigate to **Models** tab to see all configured models.

## Adding Models via config.yaml (Recommended)

The easiest way to add or modify models is by editing `config/litellm/config.yaml`.

### Step 1: Edit config.yaml

```bash
nano config/litellm/config.yaml
```

Add your model to the `model_list` section:

```yaml
model_list:
  - model_name: your-model-name
    litellm_params:
      model: provider/model-id
      api_key: os.environ/YOUR_API_KEY
      # other parameters...
```

**Environment Variable Syntax**: Use `os.environ/VAR_NAME` to reference environment variables from `.env`.

### Step 2: Apply Changes

```bash
# Remove old models
./configure-toolkit.sh clean

# Re-add all models from config.yaml
./configure-toolkit.sh
```

Or manually add the new model via API (see below).

## Manual Model Configuration

### Via API

Add a model using curl:

```bash
curl -X POST http://localhost:4000/model/new \
  -H "Authorization: Bearer YOUR_LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "gemini-2-5-flash",
    "litellm_params": {
      "model": "vertex_ai/gemini-2.5-flash",
      "vertex_credentials": "/app/credentials/google_credentials.json"
    }
  }'
```

### Via LiteLLM UI

1. Go to http://localhost:4000
2. Navigate to **Models** tab
3. Click **Add New Model**
4. Fill in:
   - **Model Name**: Display name (e.g., `gemini-2-5-flash`)
   - **LiteLLM Model**: Backend model (e.g., `vertex_ai/gemini-2.5-flash`)
   - **Custom Parameters**: Add credentials and config as JSON

Example custom parameters for Vertex AI:
```json
{
  "vertex_credentials": "/app/credentials/google_credentials.json"
}
```

## Model Examples

### Vertex AI Gemini

**Gemini 2.x models** (use regional endpoints):

```json
{
  "model_name": "gemini-2-5-flash",
  "litellm_params": {
    "model": "vertex_ai/gemini-2.5-flash",
    "vertex_credentials": "/app/credentials/google_credentials.json"
  }
}
```

**Gemini 3.x models** (require global location):

```json
{
  "model_name": "gemini-3.1-flash-lite-preview",
  "litellm_params": {
    "model": "vertex_ai/gemini-3.1-flash-lite-preview",
    "vertex_credentials": "/app/credentials/google_credentials.json",
    "vertex_location": "global"
  }
}
```

**Note**: 
- `GCP_PROJECT_ID` is automatically read from environment variables
- Gemini 2.x models use `GCP_REGION` (default: us-central1)
- Gemini 3.x models must use `"vertex_location": "global"`

### Azure OpenAI

```json
{
  "model_name": "gpt-4",
  "litellm_params": {
    "model": "azure/gpt-4",
    "api_base": "https://your-resource.openai.azure.com/",
    "api_key": "your-api-key",
    "api_version": "2024-02-15-preview"
  }
}
```

### AWS Bedrock (Claude)

```json
{
  "model_name": "claude-3-5-sonnet",
  "litellm_params": {
    "model": "bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0",
    "aws_access_key_id": "your-access-key",
    "aws_secret_access_key": "your-secret-key",
    "aws_region_name": "us-east-1"
  }
}
```

### Vertex AI Embeddings

```json
{
  "model_name": "text-embedding-004",
  "litellm_params": {
    "model": "vertex_ai/text-embedding-004",
    "vertex_credentials": "/app/credentials/google_credentials.json"
  }
}
```

## Listing Models

### Via API

```bash
curl -X GET http://localhost:4000/model/info \
  -H "Authorization: Bearer YOUR_LITELLM_MASTER_KEY"
```

### Via UI

Navigate to **Models** tab at http://localhost:4000

## Updating Models

### Via API

```bash
curl -X POST http://localhost:4000/model/update \
  -H "Authorization: Bearer YOUR_LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model_id": "model-id-from-list",
    "model_name": "gemini-2-5-flash",
    "litellm_params": {
      "model": "vertex_ai/gemini-2.5-flash",
      "vertex_credentials": "/app/credentials/google_credentials.json"
    }
  }'
```

### Via UI

1. Go to **Models** tab
2. Click on the model to edit
3. Update parameters
4. Click **Save**

## Deleting Models

### Via API

```bash
curl -X POST http://localhost:4000/model/delete \
  -H "Authorization: Bearer YOUR_LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"id": "model-id-from-list"}'
```

### Via UI

1. Go to **Models** tab
2. Click on the model
3. Click **Delete**

## Testing Models

### Via API

```bash
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer YOUR_LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-2-5-flash",
    "messages": [{"role": "user", "content": "Hello, world!"}],
    "max_tokens": 100
  }'
```

### Via UI

1. Go to **Playground** tab
2. Select your model
3. Enter a test message
4. Click **Send**

## Environment Variables

LiteLLM automatically reads these environment variables from `.env`:

- `GCP_PROJECT_ID` - Google Cloud project ID
- `GCP_REGION` - Google Cloud region (default: us-central1)
- `GOOGLE_APPLICATION_CREDENTIALS` - Path to service account JSON (auto-copied by startup script)
- `AZURE_API_KEY`, `AZURE_API_BASE`, `AZURE_API_VERSION` - Azure OpenAI credentials
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION_NAME` - AWS Bedrock credentials

These are automatically available to all models without needing to specify them in model parameters.

## Troubleshooting

### Models Not Appearing

1. Check if model was added successfully:
   ```bash
   curl -X GET http://localhost:4000/model/info \
     -H "Authorization: Bearer YOUR_LITELLM_MASTER_KEY"
   ```

2. Check LiteLLM logs:
   ```bash
   ./start-toolkit.sh logs litellm
   ```

### Authentication Errors

1. Verify credentials in `.env` file
2. For Vertex AI: Ensure `credentials/google_credentials.json` exists and has correct permissions (644)
3. Restart LiteLLM:
   ```bash
   ./start-toolkit.sh restart
   ```

### Database Connection Issues

Check if PostgreSQL is running:
```bash
./start-toolkit.sh status
```

Verify database connection:
```bash
podman exec dc-masters-postgres psql -U dcmasters -d litellm -c "SELECT 1;"
```

## Migration Notes

If you see migration warnings on startup, they are normal and auto-resolve. LiteLLM will mark failed migrations as resolved automatically.

Common migration message:
```
Migration failed due to idempotent error (e.g., column already exists), resolving as applied
```

This is expected behavior and doesn't affect functionality.

## Backup and Restore

### Backup Model Configurations

```bash
curl -X GET http://localhost:4000/model/info \
  -H "Authorization: Bearer YOUR_LITELLM_MASTER_KEY" \
  > litellm-models-backup.json
```

### Restore from Backup

```bash
# Parse backup file and re-add models
cat litellm-models-backup.json | jq -c '.data[]' | while read model; do
  curl -X POST http://localhost:4000/model/new \
    -H "Authorization: Bearer YOUR_LITELLM_MASTER_KEY" \
    -H "Content-Type: application/json" \
    -d "$model"
done
```

## Advanced: MCP Server Configuration

MCP servers are configured via database. The `configure-toolkit.sh` script automatically adds:
- **filesystem** - Sandboxed file operations at http://mcp-filesystem:8000/mcp
- **duckduckgo** - Web search and URL fetching at http://mcp-duckduckgo:8001/mcp

### Manually Adding MCP Servers

To add additional MCP servers manually:

```bash
curl -X POST http://localhost:4000/mcp/server/new \
  -H "Authorization: Bearer YOUR_LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "your-server-name",
    "url": "http://your-mcp-server:port/mcp",
    "transport": "http",
    "alias": "shortname"
  }'
```

### Verifying MCP Servers

Check configured MCP servers:

```bash
curl -X GET http://localhost:4000/mcp/servers \
  -H "Authorization: Bearer YOUR_LITELLM_MASTER_KEY"
```

## Next Steps

- **Use Models in N8N**: Configure N8N workflows to use LiteLLM endpoint
- **Build Custom Workflows**: Create workflows that leverage multiple models
- **Monitor Usage**: Check usage statistics in LiteLLM UI
- **Experiment with Models**: Try different models for different tasks

## Documentation Links

- LiteLLM Docs: https://docs.litellm.ai
- Supported Models: https://docs.litellm.ai/docs/providers
- API Reference: http://localhost:4000/docs
