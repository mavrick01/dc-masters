# DC-Masters Container Toolkit

A comprehensive containerized toolkit for DC-Masters students to learn and demonstrate AI applications. Includes LiteLLM AI gateway, N8N workflow automation, PostgreSQL with pgvector for embeddings, and MCP servers for tool integration.

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│  DC-Masters Container Toolkit                                  │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐  ┌──────┐  ┌────────────────────┐              │
│  │ LiteLLM  │  │ N8N  │  │ PostgreSQL+pgvector│              │
│  │  :4000   │  │:5678 │  │      :5432         │              │
│  └────┬─────┘  └───┬──┘  └──────────┬─────────┘              │
│       │            │                 │                         │
│       │   ┌────────┴─────────────────┘                         │
│       │   │                                                     │
│       │   │  ┌───────────────────────────────────┐            │
│       │   │  │ Databases:                        │            │
│       │   │  │  1. litellm (LiteLLM config)      │            │
│       │   │  │  2. n8n (N8N workflows)           │            │
│       │   │  │  3. embeddings.documents          │            │
│       │   │  │     (general vectors 1536-d)      │            │
│       │   │  │  4. airs_embedding.documents      │            │
│       │   │  │     (AIRS docs vectors 1536-d)    │            │
│       │   │  └───────────────────────────────────┘            │
│       │   │                                                     │
│       └───┼────────┐                                           │
│           │        │                                            │
│  ┌────────┴────────┴─────────────────────────────┐            │
│  │ MCP Servers (HTTP transport)                  │            │
│  ├────────────────────────────────────────────────┤            │
│  │  • SearXNG :8081 (web search)                 │            │
│  └────────────────────────────────────────────────┘            │
│                                                                 │
│  Pre-configured N8N Workflows:                                 │
│  1. Embedding Agent (Vertex AI) - watches /import dir          │
│  2. Basic AI Agent (Gemini 2.5) - RAG + search                │
│  3. Advanced AI Agent (LiteLLM) - RAG + MCP DuckDuckGo         │
│  4. AIRS PDF Downloader - download & embed AIRS docs          │
│  5. AIRS Chatbot - query AIRS documentation                    │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

## Components

- **LiteLLM**: Unified AI gateway supporting Azure OpenAI (GPT), AWS Bedrock (Claude), and Vertex AI (Gemini)
- **N8N**: Low-code workflow automation with 5 pre-built AI workflows
- **PostgreSQL + pgvector**: Vector database for semantic search and RAG
- **SearXNG**: Privacy-focused metasearch engine (DuckDuckGo, etc.)
- **MCP SearXNG Server**: Web search capability for AI models via Model Context Protocol

## Prerequisites

- **Container Runtime**: Podman (recommended) or Docker
- **Google Cloud Account**: With Vertex AI API enabled (required for embeddings and Gemini)
- **Optional**: Azure OpenAI access (for GPT models) and/or AWS Bedrock access (for Claude models)
- **System Resources**: Minimum 4GB RAM, 10GB disk space
- **Network**: Internet access for API calls and container image downloads

### Corporate Firewall Users

If you're behind a corporate firewall with SSL inspection or proxy requirements, see [CORPORATE_FIREWALL.md](CORPORATE_FIREWALL.md) for configuration instructions.

**Quick fix**: Add to your `.env` file:
```bash
DC_NODE_TLS_REJECT_UNAUTHORIZED=0
DC_REQUESTS_CA_BUNDLE=/app/certs/company-ca.pem
DC_CURL_CA_BUNDLE=/app/certs/company-ca.pem
DC_SSL_CERT_FILE=/app/certs/company-ca.pem
HTTP_PROXY=http://your-proxy:8080
HTTPS_PROXY=http://your-proxy:8080
```

## Quick Start

### 1. Clone and Configure

```bash
# Navigate to the project directory
cd dc-masters

# Copy environment template
cp .env.example .env

# Edit .env and configure your credentials
nano .env  # or use your preferred editor
```

**Required Credentials:**
- Google Cloud service account JSON file for Vertex AI
- At least one of: Azure OpenAI credentials, AWS Bedrock credentials, or use Vertex AI Gemini

### 2. Start the Toolkit

```bash
# Start all services (infrastructure only)
./start-toolkit.sh start

# Wait 2-3 minutes for initialization
# Check logs
./start-toolkit.sh logs
```

### 3. Configure the Toolkit

```bash
# Configure LiteLLM models, virtual keys, and N8N credentials
./configure-toolkit.sh
```

This will automatically:
- ✅ Read model definitions from `config/litellm/config.yaml`
- ✅ Add AI models to LiteLLM (Vertex AI Gemini, Azure GPT, AWS Claude)
- ✅ Configure MCP servers (filesystem, duckduckgo)
- ✅ Create a virtual key in LiteLLM for N8N to use
- ✅ Create N8N credentials (Google Cloud, PostgreSQL, LiteLLM)
- ✅ Import N8N workflows (all 5 workflows imported via API)

**Note**: You can re-run `./configure-toolkit.sh` anytime to reconfigure or add more models/credentials.

**Adding Custom Models**: Edit `config/litellm/config.yaml` to add or modify models, then run `./configure-toolkit.sh` to apply changes.

**Reset Configuration**: To undo all changes made by `configure-toolkit.sh`:
```bash
./configure-toolkit.sh clean
```
This removes all models, virtual keys, credentials, and workflows, allowing you to start fresh.

**Alternative**: Configure manually via UIs:
- LiteLLM: http://localhost:4000 (see [LITELLM_SETUP.md](LITELLM_SETUP.md))
- N8N: http://localhost:5678 (see [WORKFLOW_SETUP.md](WORKFLOW_SETUP.md))

### 4. Access Services

- **N8N UI**: http://localhost:5678
  - Username: `admin` (or your configured value)
  - Password: `changeme123` (or your configured value)
- **LiteLLM API**: http://localhost:4000
- **SearXNG**: http://localhost:8080 (search engine web interface)
- **MCP SearXNG Server**: http://localhost:8081 (MCP HTTP endpoint)
- **PostgreSQL**: `localhost:5432`

### 4. Configure N8N Workflows

1. Log into N8N at http://localhost:5678
2. Go to **Settings** → **Credentials**
3. Create the following credentials:
   - **Google Cloud** - Upload your service account JSON
   - **PostgreSQL** - Use credentials from `.env`
   - **LiteLLM API** - Use `LITELLM_MASTER_KEY` from `.env`
4. Go to **Workflows** and update each workflow to use your credentials
5. Activate workflows

## Pre-configured Workflows

### Workflow 1: Embedding Agent

**Purpose**: Automatically embed files from the import directory into the vector database

**How to use**:
1. Place text files in `data/sandbox/import/`
2. Workflow runs every 5 minutes automatically
3. Files are embedded using Vertex AI text-embedding-004
4. Embeddings stored in `embeddings.documents` table
5. Processed files moved to `data/sandbox/shared/`

### Workflow 2: Basic AI Agent

**Purpose**: RAG-based chatbot using Vertex AI Gemini 2.5 with vector search and web search

**How to test**:
```bash
curl -X POST http://localhost:5678/webhook/basic-ai-agent \
  -H "Content-Type: application/json" \
  -d '{"question": "What are the key features of this toolkit?"}'
```

### Workflow 3: Advanced AI Agent

**Purpose**: Same as Workflow 2 but uses LiteLLM gateway with MCP tool integration

**Benefits**:
- Switch between GPT (Azure), Claude (AWS), or Gemini (Vertex) by changing model parameter
- Automatic access to MCP tools (filesystem, web search)
- Unified credential management

**How to test**:
```bash
curl -X POST http://localhost:5678/webhook/advanced-ai-agent \
  -H "Content-Type: application/json" \
  -d '{"question": "What are the key features of this toolkit?", "model": "gpt-4"}'
```

### Workflow 4: AIRS PDF Downloader

**Purpose**: Download and embed Palo Alto Networks AI Runtime Security documentation

**How to use**:
1. Manually trigger this workflow in N8N (one-time setup)
2. Downloads 5 AIRS documentation PDFs
3. Extracts text and creates embeddings
4. Stores in separate `airs_embedding` database
5. Takes ~10-15 minutes to complete

### Workflow 5: AIRS Chatbot

**Purpose**: Answer questions about Palo Alto Networks AI Runtime Security

**How to test**:
```bash
curl -X POST http://localhost:5678/webhook/airs-chatbot \
  -H "Content-Type: application/json" \
  -d '{"question": "How do I activate AI Runtime Security?"}'
```

## Configuration Guide

### Google Cloud / Vertex AI Setup

1. Create a Google Cloud project
2. Enable Vertex AI API
3. Create a service account with Vertex AI permissions
4. Download service account JSON file
5. Update `.env`:
   ```bash
   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
   GCP_PROJECT_ID=your-project-id
   GCP_REGION=us-central1
   ```

### Azure OpenAI Setup (Optional)

1. Create Azure OpenAI resource
2. Deploy gpt-4 and gpt-35-turbo models
3. Update `.env`:
   ```bash
   AZURE_API_KEY=your-azure-api-key
   AZURE_API_BASE=https://your-resource.openai.azure.com/
   AZURE_API_VERSION=2024-02-15-preview
   ```

### AWS Bedrock Setup (Optional)

1. Enable AWS Bedrock in your AWS account
2. Request access to Claude models
3. Create IAM user with Bedrock permissions
4. Update `.env`:
   ```bash
   AWS_ACCESS_KEY_ID=your-access-key
   AWS_SECRET_ACCESS_KEY=your-secret-key
   AWS_REGION_NAME=us-east-1
   ```

## MCP Server Usage

### Direct HTTP Access

Test MCP servers directly:

```bash
# List available tools
curl -X POST http://localhost:8081/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'

# Search the web
curl -X POST http://localhost:8081/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"search","arguments":{"query":"AI safety"}},"id":1}'
```

### Via LiteLLM

MCP tools are automatically available to all LiteLLM models:

```bash
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Search for information about AI safety"}],
    "tools": "auto"
  }'
```

## Database Access

### Connect to PostgreSQL

```bash
# Connect to main database
psql -h localhost -U dcmasters -d litellm

# Connect to AIRS database
psql -h localhost -U dcmasters -d airs_embedding
```

### Query Embeddings

```sql
-- Check embedded documents
SELECT COUNT(*) FROM embeddings.documents;

-- Vector similarity search
SELECT content, 1 - (embedding <=> '[0.1, 0.2, ...]'::vector) AS similarity
FROM embeddings.documents
ORDER BY similarity DESC
LIMIT 5;
```

## Troubleshooting

### LiteLLM SSL Certificate Warning

**Symptom**: LiteLLM logs show:
```
LiteLLM: Failed to fetch remote model cost map... [SSL: CERTIFICATE_VERIFY_FAILED]
certificate verify failed: self-signed certificate in certificate chain
```

**Impact**: None - LiteLLM automatically falls back to local model cost map. This is a harmless warning in corporate firewall environments.

**To suppress the warning** (optional):
1. Add to `.env`: `SSL_VERIFY=false`
2. Or, see [CORPORATE_FIREWALL.md](CORPORATE_FIREWALL.md) for CA certificate configuration

### Services Not Starting

```bash
# Check logs
./start-toolkit.sh logs

# Check specific service
./start-toolkit.sh logs postgres
./start-toolkit.sh logs litellm
./start-toolkit.sh logs n8n
```

### Port Already in Use

Change ports in `compose.yaml` or stop conflicting services:
```bash
# Check what's using port 5432
lsof -i :5432

# Kill process (if safe to do so)
kill -9 <PID>
```

### Permission Denied (Podman)

If using Podman on SELinux systems:
```bash
# Relabel volumes
sudo chcon -Rt svirt_sandbox_file_t ./data
```

### Database Connection Errors

1. Wait for PostgreSQL to fully initialize (check logs)
2. Verify credentials in `.env` match
3. Check network: `docker/podman network ls`

### PDF Processing Errors (Workflow 4)

Ensure pdf-parse is installed in N8N container:
```bash
# Access N8N container
docker exec -it dc-masters-n8n sh

# Install pdf-parse
npm install pdf-parse
```

## Management Commands

```bash
# Start services
./start-toolkit.sh start

# Stop services (preserve data)
./start-toolkit.sh stop

# Restart services
./start-toolkit.sh restart

# View logs
./start-toolkit.sh logs
./start-toolkit.sh logs n8n  # specific service

# Check status
./start-toolkit.sh status

# Clean everything
./start-toolkit.sh clean

# Configure models, keys, credentials, workflows
./configure-toolkit.sh

# Reset configuration (remove models, keys, credentials, workflows)
./configure-toolkit.sh clean
```

## Security Considerations

⚠️ **IMPORTANT**: Change default passwords in `.env` before production use!

- Default N8N password: `changeme123`
- Default PostgreSQL password: `changeme123`
- Default LiteLLM master key: `sk-1234-changeme`

### Security Best Practices

1. **Credentials**: Never commit `.env` to version control
2. **Service Accounts**: Use minimal required permissions
3. **Network**: MCP servers are only accessible within container network
4. **Sandbox**: Filesystem MCP server is restricted to `/projects` directory
5. **API Keys**: Rotate keys regularly

## Backup and Restore

### Backup PostgreSQL

```bash
# Backup main database
docker exec dc-masters-postgres pg_dump -U dcmasters litellm > backup-litellm.sql

# Backup AIRS database
docker exec dc-masters-postgres pg_dump -U dcmasters airs_embedding > backup-airs.sql
```

### Restore PostgreSQL

```bash
# Restore main database
cat backup-litellm.sql | docker exec -i dc-masters-postgres psql -U dcmasters litellm

# Restore AIRS database
cat backup-airs.sql | docker exec -i dc-masters-postgres psql -U dcmasters airs_embedding
```

### Backup N8N Workflows

```bash
# Export all workflows from N8N UI
# Or backup N8N data directory
tar -czf n8n-backup.tar.gz data/n8n/
```

## Advanced Usage

### Adding Custom Models to LiteLLM

Edit `config/litellm/config.yaml`:

```yaml
model_list:
  - model_name: my-custom-model
    litellm_params:
      model: provider/model-name
      api_key: ${MY_API_KEY}
```

### Creating Custom N8N Workflows

1. Use existing workflows as templates
2. Export workflows as JSON for version control
3. Import workflows via N8N CLI or UI

### Adding New MCP Servers

1. Create server in `mcp-servers/<name>/`
2. Add to `compose.yaml`
3. Register in `config/litellm/config.yaml` under `mcp_servers`

## Performance Tuning

### Resource Limits

Edit `compose.yaml` to add limits:

```yaml
services:
  postgres:
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '1.0'
```

### Vector Index Optimization

```sql
-- Tune ivfflat parameters for better performance
CREATE INDEX ON embeddings.documents
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);  -- Adjust based on data size
```

## Support and Contributing

- **Issues**: Report bugs at project repository
- **Documentation**: Contribution welcome
- **Questions**: Ask in DC-Masters community

## License

Educational use for DC-Masters students.

---

**Note**: This toolkit is for educational purposes. Ensure compliance with all API provider terms of service.
