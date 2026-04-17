# DC-Masters Container Toolkit - Quick Start

Get up and running in 15 minutes!

## Prerequisites Checklist

- [ ] Podman or Docker installed
- [ ] Google Cloud account with Vertex AI API enabled
- [ ] Service account JSON file downloaded
- [ ] 10GB free disk space
- [ ] Ports available: 4000, 5432, 5678, 8000, 8001

## Step 1: Initial Setup (5 minutes)

```bash
# Navigate to project directory
cd dc-masters

# Copy environment template
cp .env.example .env

# Edit configuration
nano .env  # or your preferred editor
```

**Required changes in `.env`**:
- Set `GOOGLE_APPLICATION_CREDENTIALS` path to your service account JSON
- Set `GCP_PROJECT_ID` to your Google Cloud project ID
- Set `GCP_REGION` (default: us-central1)
- Change default passwords (highly recommended!)

**Optional** (if you have access):
- Configure `AZURE_API_*` for GPT models
- Configure `AWS_*` for Claude models

## Step 2: Start Services (2 minutes)

```bash
# Start all containers
./start-toolkit.sh start

# Wait for services to initialize (watch logs)
./start-toolkit.sh logs
```

**Expected output**: All services should show "healthy" status after 2-3 minutes.

## Step 3: Configure N8N Workflows (5 minutes)

1. **Access N8N**: http://localhost:5678
   - Username: `admin` (or from your `.env`)
   - Password: `changeme123` (or from your `.env`)

2. **Create Credentials**:
   - Go to **Settings** → **Credentials**
   - Add **Google Cloud** credential (upload service account JSON)
   - Add **PostgreSQL** credentials for `litellm` database
   - Add **PostgreSQL** credentials for `airs_embedding` database
   - Add **LiteLLM API** credential (HTTP Bearer Auth with your master key)

3. **Configure Workflows**:
   - Open each workflow (1-5)
   - Assign credentials to nodes that need them
   - Save each workflow

4. **Activate Workflows**:
   - Toggle **Active** for workflows 1, 2, 3, and 5
   - Workflow 4 is manual trigger only

**Detailed instructions**: See [WORKFLOW_SETUP.md](WORKFLOW_SETUP.md)

## Step 4: Test the System (3 minutes)

### Test 1: Embedding Agent

```bash
# Create a test file
echo "Artificial intelligence is transforming cybersecurity." > data/sandbox/import/ai-security.txt

# Wait 5 minutes or manually trigger workflow 1 in N8N

# Verify embedding created
psql -h localhost -U dcmasters -d litellm -c "SELECT COUNT(*) FROM embeddings.documents;"
```

### Test 2: Basic AI Agent

```bash
curl -X POST http://localhost:5678/webhook/basic-ai-agent \
  -H "Content-Type: application/json" \
  -d '{"question": "What is artificial intelligence?"}'
```

**Expected**: JSON response with answer, sources, and model info.

### Test 3: Advanced AI Agent (LiteLLM)

```bash
curl -X POST http://localhost:5678/webhook/advanced-ai-agent \
  -H "Content-Type: application/json" \
  -d '{"question": "What is cybersecurity?", "model": "gemini-2-5-flash"}'
```

**Expected**: JSON response using specified model with MCP tools available.

### Test 4: AIRS PDF Downloader (Optional, 15 minutes)

1. Open N8N UI
2. Go to "4. AIRS PDF Downloader"
3. Click **Execute Workflow**
4. Monitor progress (downloads 5 PDFs, ~500-1000 chunks)

### Test 5: AIRS Chatbot (After Test 4)

```bash
curl -X POST http://localhost:5678/webhook/airs-chatbot \
  -H "Content-Type: application/json" \
  -d '{"question": "What is AI Runtime Security?"}'
```

**Expected**: Detailed answer with citations from AIRS documentation.

## Troubleshooting Quick Fixes

### Services Won't Start

```bash
# Check logs
./start-toolkit.sh logs

# Check specific service
./start-toolkit.sh logs postgres
./start-toolkit.sh logs litellm
./start-toolkit.sh logs n8n

# Restart services
./start-toolkit.sh restart
```

### Port Already in Use

```bash
# Find what's using the port
lsof -i :5432  # PostgreSQL
lsof -i :5678  # N8N
lsof -i :4000  # LiteLLM

# Stop the conflicting service or change ports in compose.yaml
```

### Credential Errors in N8N

1. Check credential names match workflow expectations
2. Test credential connection (click "Test" button)
3. Re-select credentials in workflow nodes
4. Save workflow

### "Cannot connect to PostgreSQL"

```bash
# Verify PostgreSQL is running
./start-toolkit.sh status

# Check if database exists
psql -h localhost -U dcmasters -l

# Restart PostgreSQL
./start-toolkit.sh restart postgres
```

### MCP Servers Not Responding

```bash
# Test filesystem server
curl -X POST http://localhost:8000/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'

# Test DuckDuckGo server
curl -X POST http://localhost:8001/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'

# Restart MCP servers
./start-toolkit.sh restart mcp-filesystem
./start-toolkit.sh restart mcp-duckduckgo
```

## What's Next?

### Learning Path

1. **Understand RAG**: Study workflows 2 and 3 to see how retrieval augmented generation works
2. **Experiment with Models**: Try different models in workflow 3 (GPT, Claude, Gemini)
3. **Build Custom Workflows**: Use the 5 workflows as templates
4. **Explore MCP Tools**: See how LiteLLM exposes tools to AI models

### Example Projects

1. **Document Q&A System**: Build a chatbot for your own PDF documents
2. **Multi-Agent System**: Combine workflows to create agent pipelines
3. **Automated Research**: Use web search + RAG for research tasks
4. **Code Documentation**: Embed code repositories for AI-assisted development

### Advanced Topics

- **Custom MCP Servers**: Add GitHub, Slack, or other MCP servers
- **Fine-tuning Prompts**: Optimize system prompts for your use case
- **Performance Tuning**: Optimize vector search parameters
- **Production Deployment**: Add authentication, SSL, monitoring

## Useful Commands

```bash
# Start toolkit
./start-toolkit.sh start

# Stop (preserve data)
./start-toolkit.sh stop

# Restart
./start-toolkit.sh restart

# View logs
./start-toolkit.sh logs

# Check status
./start-toolkit.sh status

# Clean everything
./start-toolkit.sh clean

# Access PostgreSQL
psql -h localhost -U dcmasters -d litellm

# Backup database
docker exec dc-masters-postgres pg_dump -U dcmasters litellm > backup.sql
```

## Service URLs

- **N8N UI**: http://localhost:5678
- **LiteLLM API**: http://localhost:4000
- **LiteLLM Docs**: http://localhost:4000/docs
- **PostgreSQL**: localhost:5432
- **MCP Filesystem**: http://localhost:8000/mcp
- **MCP DuckDuckGo**: http://localhost:8001/mcp

## Documentation

- [README.md](README.md) - Complete documentation
- [WORKFLOW_SETUP.md](WORKFLOW_SETUP.md) - Detailed workflow configuration
- Architecture diagram in README.md
- Troubleshooting section in README.md

## Support

If you encounter issues:

1. Check logs: `./start-toolkit.sh logs`
2. Verify credentials in `.env` and N8N
3. Consult [README.md](README.md) troubleshooting section
4. Check service health: `./start-toolkit.sh status`

---

**Security Reminder**: Change all default passwords in production!

Happy learning! 🚀
