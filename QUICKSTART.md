# DC-Masters Container Toolkit - Quick Start Guide

Get your AI toolkit running in 5 automated steps! ⚡

For manual/self-service setup with full GUI instructions, see [SELFSERVE.md](SELFSERVE.md).

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Configure Environment](#step-1-configure-environment)
3. [Step 2: Corporate Certificate Setup (Optional)](#step-2-corporate-certificate-setup-optional)
4. [Step 3: Start Services](#step-3-start-services)
5. [Step 4: Apply LiteLLM Database Fix](#step-4-apply-litellm-database-fix)
6. [Step 5: Configure Models, Credentials, and Workflows](#step-5-configure-models-credentials-and-workflows)
7. [Step 6: Activate Workflows](#step-6-activate-workflows)
8. [Verification and Testing](#verification-and-testing)
9. [Troubleshooting](#troubleshooting)
10. [Next Steps](#next-steps)
11. [Reference Tables](#reference-tables)

---

## Prerequisites

### Hardware Requirements
- **RAM**: Minimum 4GB (8GB recommended)
- **Disk Space**: 10GB free space
- **CPU**: 2+ cores recommended

### Software Requirements
- **Container Runtime**: Podman (recommended) or Docker
- **Python 3**: For configuration scripts
- **jq**: For JSON processing
- **curl**: For API testing

### Cloud Account Requirements
- **Google Cloud Account** with Vertex AI API enabled (required)
  - Service account with "Vertex AI User" role
  - Service account JSON key file
- **Optional**: Azure OpenAI access (for GPT models)
- **Optional**: AWS Bedrock access (for Claude models)

### Port Availability
Ensure these ports are available:
- `4000` - LiteLLM API
- `5432` - PostgreSQL
- `5678` - N8N

Check port availability:
```bash
lsof -i :4000 :5432 :5678
# Should show no results
```

### Corporate Firewall Users

⚠️ If you're behind a corporate firewall with SSL inspection or proxy requirements, you'll need additional configuration. See [CORPORATE_FIREWALL.md](CORPORATE_FIREWALL.md) for detailed instructions.

**Quick symptoms check:**
- SSL certificate errors when pulling containers
- Connection timeouts to external APIs
- HTTP 407 Proxy Authentication errors

---

## Step 1: Configure Environment

```bash
# Navigate to project directory
cd dc-masters

# Copy environment template
cp .env.example .env

# Edit configuration with your preferred editor
nano .env
# OR
vi .env
# OR
code .env
```

### Required Configuration

Edit `.env` and configure:

**Database Credentials:**
```bash
POSTGRES_USER=dcmasters              # Choose any username
POSTGRES_PASSWORD=changeme123        # ⚠️ Change to strong password!
```

**LiteLLM Settings:**
```bash
LITELLM_MASTER_KEY=sk-1234-changeme  # ⚠️ Generate strong key!
UI_USERNAME=admin@dcmasters.local    # LiteLLM UI username
UI_PASSWORD=changeme123              # ⚠️ Change to strong password!
```

**N8N Settings:**
```bash
N8N_OWNER_EMAIL=admin@dcmasters.local   # Your email for N8N
N8N_OWNER_PASSWORD=changeme123          # ⚠️ Change to strong password!
```

**Google Cloud (Vertex AI) - REQUIRED:**
```bash
# Path to your service account JSON file
GOOGLE_APPLICATION_CREDENTIALS=/path/to/your/service-account.json

# Your Google Cloud project ID (from GCP Console)
GCP_PROJECT_ID=your-project-id

# Vertex AI region (choose closest to you)
GCP_REGION=us-central1
```

**How to obtain Google Cloud credentials:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Vertex AI API for your project
3. Create a service account with "Vertex AI User" role
4. Download the JSON key file
5. Update `GOOGLE_APPLICATION_CREDENTIALS` with the absolute path to this file

For complete environment variable reference, see [Table 1](#table-1-environment-variables) below.

For detailed explanation of all variables, see [SELFSERVE.md](SELFSERVE.md).

---

## Step 2: Corporate Certificate Setup (Optional)

**Do you need this step?**
- ✅ Skip if: You're on a home/university network
- ⚠️ Complete if: You're behind a corporate firewall with SSL inspection

### Quick Setup

1. **Obtain your corporate CA certificate** (from IT department):
   ```bash
   # Place certificate in certs directory
   mkdir -p certs
   cp /path/to/your-cert.pem certs/company-ca.pem
   ```

2. **The start script will automatically detect and mount it**

For detailed troubleshooting, see [CORPORATE_FIREWALL.md](CORPORATE_FIREWALL.md).

---

## Step 3: Start Services

```bash
# Start all services
./start-toolkit.sh start

# Wait 2-3 minutes for initialization
# Watch the logs (optional)
./start-toolkit.sh logs
```

**Expected output:**
- Services starting up messages
- N8N owner account auto-creation
- "DC-Masters Container Toolkit is starting" confirmation

**Verify services are running:**
```bash
./start-toolkit.sh status

# Should show:
# dc-masters-postgres   Up
# dc-masters-litellm    Up
# dc-masters-n8n        Up
```

### Access URLs

Once services are running, you can access:

- **LiteLLM API**: http://localhost:4000
  - Login: `admin@dcmasters.local` / `changeme123`
- **N8N Workflow Automation**: http://localhost:5678
  - Login: `admin@dcmasters.local` / `changeme123`
- **PostgreSQL Database**: `localhost:5432`
  - User: `dcmasters` / Password: `changeme123`

For manual Docker/Podman Compose setup, see [SELFSERVE.md](SELFSERVE.md).

---

## Step 4: Apply LiteLLM Database Fix

### Why This Is Needed

LiteLLM has a migration bug where the `source_url` column is sometimes not added to the `LiteLLM_MCPServerTable`. This fix ensures the column exists before configuring MCP servers.

### Run the Fix

```bash
./bug-fix-litellm-db.sh
```

**Expected output:**
```
[INFO] Using container runtime: docker
[INFO] Checking if LiteLLM is running and ready...
[INFO] ✓ LiteLLM is ready!
[INFO] Applying database schema fix for LiteLLM MCPServerTable...
[INFO] ✓ Database schema fix applied successfully
[INFO] LiteLLM should now work correctly with MCP servers
```

For manual database fix steps, see [SELFSERVE.md](SELFSERVE.md).

---

## Step 5: Configure Models, Credentials, and Workflows

```bash
./configure-toolkit.sh
```

**What this does:**
1. Waits for services to be ready
2. Creates temporary N8N API key
3. Configures LiteLLM models from `config.yaml`
4. Configures MCP servers (Brave Search, Filesystem)
5. Creates LiteLLM virtual key for N8N
6. Creates N8N credentials (Google Cloud, PostgreSQL, LiteLLM)
7. Imports all 5 N8N workflows
8. Cleans up temporary API key

**Time:** ~3-5 minutes

**Expected output:**
```
Step 1: Waiting for Services
  ✓ LiteLLM is ready
  ✓ N8N is ready

Step 2: Configuring LiteLLM Models
  ✓ Successfully added gemini-2-5-flash
  ✓ Successfully added gemini-2-0-flash
  ✓ Successfully added text-embedding-004
  ...

Step 5: Configuring N8N Credentials
  ✓ Created credential: Google Cloud - Vertex AI
  ✓ Created credential: PostgreSQL - Embeddings DB
  ...

Configuration Complete!
```

For manual GUI-based configuration, see [SELFSERVE.md](SELFSERVE.md).

---

## Step 6: Activate Workflows

All 5 workflows are now imported with credentials assigned. You need to activate them in the N8N UI.

**Note**: Workflow numbers match the filename prefixes (e.g., `1-airs-pdf-downloader.json` = Workflow 1)

### Quick Activation Steps

1. **Open N8N**: http://localhost:5678
2. **Navigate to Workflows**
3. **For each workflow** (except Workflow 1):
   - Open the workflow
   - Toggle the **Active** switch at the top right

### Workflow Overview

| # | Name | Type | Action Required |
|---|------|------|-----------------|
| 1 | **AIRS PDF Downloader** 📥 | Manual | Execute once to populate AIRS database |
| 2 | **Embedding Agent** 📥 | Scheduled | Toggle Active (runs every 5 min) |
| 3 | **Basic AI Agent** 💬 | Webhook | Toggle Active |
| 4 | **Advanced AI Agent** 💬 | Webhook | Toggle Active |
| 5 | **AIRS Chatbot** 💬 | Webhook | Toggle Active |

### Execute Workflow 1 (AIRS PDF Downloader)

This is a one-time execution to populate the AIRS documentation database:

1. Open **Workflow 1: AIRS PDF Downloader** in N8N
2. Click **Execute Workflow** button
3. Wait 10-15 minutes for completion
4. This populates the `airs_embedding` database for Workflow 5

For detailed workflow configuration instructions, see [WORKFLOW_SETUP.md](WORKFLOW_SETUP.md) or [SELFSERVE.md](SELFSERVE.md).

---

## Verification and Testing

### Verify RAG Databases are Populated

```bash
# Check general embeddings database (populated by Workflow 2)
psql -h localhost -U dcmasters -d litellm \
  -c "SELECT COUNT(*) FROM embeddings.documents;"

# Expected: Should show number of embedded documents (> 0 after Workflow 2 runs)

# Check AIRS database (populated by Workflow 1)
psql -h localhost -U dcmasters -d airs_embedding \
  -c "SELECT document_name, COUNT(*) FROM airs.documents GROUP BY document_name;"

# Expected: Should show 5 AIRS PDF documents with chunk counts
```

### Test RAG Functionality

**Add a test file for Workflow 2:**
```bash
# Create a test file
echo "Artificial intelligence is transforming cybersecurity." > data/sandbox/import/ai-security.txt

# Wait 5 minutes or manually execute Workflow 2
# File will be moved to data/sandbox/shared/ after processing
```

**Test Workflow 3 (Basic AI Agent):**
```bash
curl -X POST http://localhost:5678/webhook/basic-ai-agent \
  -H "Content-Type: application/json" \
  -d '{"question": "What files have been embedded?"}'
```

**Test Workflow 4 (Advanced AI Agent):**
```bash
curl -X POST http://localhost:5678/webhook/advanced-ai-agent \
  -H "Content-Type: application/json" \
  -d '{"question": "What information do you have?", "model": "gemini-2-5-flash"}'
```

**Test Workflow 5 (AIRS Chatbot):**
```bash
curl -X POST http://localhost:5678/webhook/airs-chatbot \
  -H "Content-Type: application/json" \
  -d '{"question": "What is AI Runtime Security?"}'
```

### Other Verifications

- **LiteLLM API Documentation**: https://docs.litellm.ai/docs/
- **LiteLLM Playground**: Test models at http://localhost:4000/ui/?page=llm-playground
- **N8N Workflows Active**: http://localhost:5678 → Workflows (should show "Active" badge on Workflows 2, 3, 4, 5)
- **N8N Executions**: View recent workflow runs to verify they completed successfully

For GUI-based testing methods, see [SELFSERVE.md](SELFSERVE.md).

---

## Troubleshooting

### Services Won't Start

**Check logs:**
```bash
# All services
./start-toolkit.sh logs

# Specific service
./start-toolkit.sh logs postgres
./start-toolkit.sh logs litellm
./start-toolkit.sh logs n8n
```

**Restart services:**
```bash
./start-toolkit.sh restart
```

### Port Already in Use

**Find what's using the port:**
```bash
lsof -i :5432  # PostgreSQL
lsof -i :5678  # N8N
lsof -i :4000  # LiteLLM
```

**Solutions:**
1. Stop the conflicting service
2. Change ports in `compose.yaml` (not recommended)

### Credential Errors in N8N

**Symptoms:** Workflows fail with "credential not found" errors

**Solutions:**
1. Check credential names match exactly (case-sensitive)
2. Test credential connection (click **Test** button in N8N UI)
3. Re-run configuration: `./configure-toolkit.sh`

### "Cannot connect to PostgreSQL"

**Verify PostgreSQL is running:**
```bash
./start-toolkit.sh status

# Check if databases exist
psql -h localhost -U dcmasters -l
```

**Restart PostgreSQL:**
```bash
./start-toolkit.sh restart postgres
```

### LiteLLM Database Errors

**If you see errors about missing columns or tables:**
```bash
# Run the database fix script
./bug-fix-litellm-db.sh
```

### Corporate Firewall Issues

**Symptoms:**
- SSL certificate errors
- Connection timeouts
- Proxy authentication errors

**Solution:** See [CORPORATE_FIREWALL.md](CORPORATE_FIREWALL.md) for comprehensive troubleshooting.

**Quick fix:**
1. Add to `.env`:
   ```bash
   NODE_TLS_REJECT_UNAUTHORIZED=0
   SSL_VERIFY=false
   ```
2. Restart services: `./start-toolkit.sh restart`

---

## Next Steps

### Learning Path

1. **Understand RAG**: Study Workflows 3 and 4 to see how retrieval augmented generation works
2. **Experiment with Models**: Try different models in Workflow 4 (GPT, Claude, Gemini)
3. **Build Custom Workflows**: Use the 5 workflows as templates
4. **Explore MCP Tools**: See how LiteLLM exposes tools to AI models

### Example Projects

1. **Document Q&A System**: Build a chatbot for your own PDF documents
2. **Multi-Agent System**: Combine workflows to create agent pipelines
3. **Automated Research**: Use web search + RAG for research tasks
4. **Code Documentation**: Embed code repositories for AI-assisted development

### Production Recommendations

- **Change all default passwords** in `.env`
- **Use strong API keys** for `LITELLM_MASTER_KEY`
- **Enable SSL/TLS** for external access
- **Set up authentication** for LiteLLM and N8N
- **Configure monitoring** and logging
- **Back up databases** regularly

### Advanced Topics

- **Custom MCP Servers**: Add GitHub, Slack, or other MCP servers
- **Fine-tuning Prompts**: Optimize system prompts for your use case
- **Performance Tuning**: Optimize vector search parameters
- **Production Deployment**: Add reverse proxy, SSL, monitoring

---

## Reference Tables

### Table 1: Environment Variables

| Variable | Required | Default | Purpose | How to obtain |
|----------|----------|---------|---------|---------------|
| `POSTGRES_USER` | No | `dcmasters` | PostgreSQL username | Choose any username |
| `POSTGRES_PASSWORD` | Yes | `changeme123` | PostgreSQL password | ⚠️ Choose strong password |
| `LITELLM_MASTER_KEY` | Yes | `sk-1234-changeme` | LiteLLM API master key | ⚠️ Generate strong key |
| `UI_USERNAME` | No | `admin@dcmasters.local` | LiteLLM UI username | Your email or username |
| `UI_PASSWORD` | Yes | `changeme123` | LiteLLM UI password | ⚠️ Choose strong password |
| `N8N_OWNER_EMAIL` | No | `admin@dcmasters.local` | N8N owner email | Your email |
| `N8N_OWNER_PASSWORD` | Yes | `changeme123` | N8N owner password | ⚠️ Choose strong password |
| `N8N_OWNER_FIRST_NAME` | No | `Admin` | N8N owner first name | Your first name |
| `N8N_OWNER_LAST_NAME` | No | `User` | N8N owner last name | Your last name |
| `GOOGLE_APPLICATION_CREDENTIALS` | Yes | - | Path to GCP service account JSON | Download from GCP Console |
| `GCP_PROJECT_ID` | Yes | - | Google Cloud project ID | From GCP Console |
| `GCP_REGION` | No | `us-central1` | Vertex AI region | Choose closest region |
| `AZURE_API_KEY` | No | - | Azure OpenAI API key | From Azure Portal (optional) |
| `AZURE_API_BASE` | No | - | Azure OpenAI endpoint | From Azure Portal (optional) |
| `AZURE_API_VERSION` | No | - | Azure OpenAI API version | From Azure Portal (optional) |
| `AWS_ACCESS_KEY_ID` | No | - | AWS access key | From AWS Console (optional) |
| `AWS_SECRET_ACCESS_KEY` | No | - | AWS secret key | From AWS Console (optional) |
| `AWS_REGION_NAME` | No | - | AWS region | Choose closest region (optional) |
| `NODE_TLS_REJECT_UNAUTHORIZED` | No | - | Disable SSL verification | Set to `0` if behind firewall |
| `HTTP_PROXY` | No | - | HTTP proxy URL | From IT dept if behind firewall |
| `HTTPS_PROXY` | No | - | HTTPS proxy URL | From IT dept if behind firewall |
| `NO_PROXY` | No | `localhost,...` | Proxy bypass list | Comma-separated hostnames |

### Table 2: Services and Ports

| Service | Port | Purpose | Login/Access |
|---------|------|---------|--------------|
| **LiteLLM API** | 4000 | AI gateway and model proxy | UI: `admin@dcmasters.local` / `changeme123` |
| **N8N** | 5678 | Workflow automation platform | `admin@dcmasters.local` / `changeme123` |
| **PostgreSQL** | 5432 | Database (4 databases: litellm, n8n, embeddings, airs_embedding) | `dcmasters` / `changeme123` |

### Table 3: Workflows Overview

**Note:** Workflow numbers match the filename prefix. Workflows 1 & 2 populate the RAG databases.

| # | JSON Filename | Name | Type | Purpose | Prerequisites |
|---|---------------|------|------|---------|---------------|
| 1 | `1-airs-pdf-downloader.json` | **AIRS PDF Downloader** 📥 | Manual | Download & embed AIRS documentation (5 PDFs) | Google Cloud, PostgreSQL-AIRS |
| 2 | `2-embedding-agent.json` | **Embedding Agent** 📥 | Scheduled (every 5 min) | Auto-embed files from import folder | Google Cloud, PostgreSQL-Embeddings |
| 3 | `3-basic-ai-agent.json` | **Basic AI Agent** 💬 | Webhook | RAG chatbot with Gemini | Workflow 2 data, Google Cloud |
| 4 | `4-advanced-ai-agent.json` | **Advanced AI Agent** 💬 | Webhook | Multi-model RAG with MCP tools | Workflow 2 data, LiteLLM |
| 5 | `5-airs-chatbot.json` | **AIRS Chatbot** 💬 | Webhook | Query AIRS documentation | Workflow 1 data, LiteLLM |

### Table 4: Database Structure

| Database | Schema | Table | Purpose |
|----------|--------|-------|---------|
| `litellm` | `embeddings` | `documents` | General document embeddings from Workflow 2 |
| `airs_embedding` | `airs` | `documents` | AIRS documentation embeddings from Workflow 1 |
| `n8n` | `public` | (multiple) | N8N workflow and execution data |
| `litellm` | `public` | `LiteLLM_*` | LiteLLM configuration and API keys |

---

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

# Configure models, keys, credentials, workflows
./configure-toolkit.sh

# Reset configuration (start fresh)
./configure-toolkit.sh clean

# Access PostgreSQL
psql -h localhost -U dcmasters -d litellm

# Backup database
docker exec dc-masters-postgres pg_dump -U dcmasters litellm > backup.sql
# OR for Podman:
podman exec dc-masters-postgres pg_dump -U dcmasters litellm > backup.sql
```

---

## Documentation

- **[README.md](README.md)** - Complete project documentation and architecture
- **[SELFSERVE.md](SELFSERVE.md)** - Manual setup with GUI instructions (alternative to automated scripts)
- **[WORKFLOW_SETUP.md](WORKFLOW_SETUP.md)** - Detailed workflow configuration guide
- **[CORPORATE_FIREWALL.md](CORPORATE_FIREWALL.md)** - Corporate firewall troubleshooting
- **[compose.yaml](compose.yaml)** - Docker/Podman compose configuration

---

## Support

If you encounter issues:

1. Check logs: `./start-toolkit.sh logs`
2. Verify credentials in `.env` and N8N
3. Consult [README.md](README.md) troubleshooting section
4. Check service health: `./start-toolkit.sh status`
5. Review [CORPORATE_FIREWALL.md](CORPORATE_FIREWALL.md) if behind firewall

---

**Security Reminder**: Change all default passwords in production!

**Happy Learning!** 🚀
