# N8N Workflow Setup Guide

This guide walks you through configuring the 5 pre-imported N8N workflows in the DC-Masters Container Toolkit.

## Overview

The toolkit includes 5 workflows that are automatically imported on first startup:

1. **Embedding Agent** - Automatically embeds files from the import directory
2. **Basic AI Agent** - RAG chatbot using Vertex AI Gemini
3. **Advanced AI Agent** - Multi-model RAG chatbot using LiteLLM
4. **AIRS PDF Downloader** - Downloads and embeds Palo Alto AIRS documentation
5. **AIRS Chatbot** - Answers questions about AIRS documentation

⚠️ **Important**: All workflows are imported as **INACTIVE** and require credential configuration before use.

## Prerequisites

Before configuring workflows, ensure you have:

- ✅ Google Cloud service account JSON file (for Vertex AI)
- ✅ PostgreSQL credentials (from your `.env` file)
- ✅ LiteLLM master key (from your `.env` file)
- ✅ Optional: Azure OpenAI or AWS Bedrock credentials

## Step 1: Create Credentials in N8N

### 1.1 Access N8N

1. Navigate to http://localhost:5678
2. Log in with credentials from `.env` (default: admin / changeme123)

### 1.2 Create Google Cloud Credential

1. Go to **Settings** → **Credentials**
2. Click **Add Credential**
3. Select **Google Cloud**
4. Choose **Service Account**
5. Upload your service account JSON file
6. Name it: `Google Cloud - Vertex AI`
7. Click **Save**

### 1.3 Create PostgreSQL Credentials (Main Database)

1. Click **Add Credential** → **Postgres**
2. Fill in the details:
   - **Host**: `postgres`
   - **Database**: `litellm`
   - **User**: `dcmasters` (or your value from `.env`)
   - **Password**: (from `POSTGRES_PASSWORD` in `.env`)
   - **Port**: `5432`
   - **SSL**: Disabled
3. Name it: `PostgreSQL - Embeddings DB`
4. Test connection
5. Click **Save**

### 1.4 Create PostgreSQL Credentials (AIRS Database)

1. Click **Add Credential** → **Postgres**
2. Fill in the details:
   - **Host**: `postgres`
   - **Database**: `airs_embedding`
   - **User**: `dcmasters`
   - **Password**: (same as above)
   - **Port**: `5432`
   - **SSL**: Disabled
3. Name it: `PostgreSQL - AIRS DB`
4. Test connection
5. Click **Save**

### 1.5 Create LiteLLM API Credential

1. Click **Add Credential** → **HTTP Header Auth**
2. Fill in:
   - **Name**: `Authorization`
   - **Value**: `Bearer YOUR_LITELLM_MASTER_KEY` (from `.env`)
3. Name it: `LiteLLM API`
4. Click **Save**

## Step 2: Configure Each Workflow

### Workflow 1: Embedding Agent

**Purpose**: Automatically processes files from `/data/sandbox/import/` directory

**Credentials Needed**:
- Google Cloud - Vertex AI
- PostgreSQL - Embeddings DB

**Steps**:
1. Open workflow "1. Embedding Agent - Auto-embed Files"
2. Click on **"Generate Embedding (Vertex AI)"** node
3. Under **Credentials**, select `Google Cloud - Vertex AI`
4. Click on **"Check If Already Processed"** node
5. Under **Credentials**, select `PostgreSQL - Embeddings DB`
6. Click on **"Store in Database"** node
7. Under **Credentials**, select `PostgreSQL - Embeddings DB`
8. Click **Save** (top right)
9. Toggle **Active** (top right)

### Workflow 2: Basic AI Agent

**Purpose**: RAG chatbot using Vertex AI Gemini with web search

**Credentials Needed**:
- Google Cloud - Vertex AI
- PostgreSQL - Embeddings DB

**Webhook URL**: `http://localhost:5678/webhook/basic-ai-agent`

**Steps**:
1. Open workflow "2. Basic AI Agent - RAG with Gemini"
2. Configure credentials for:
   - **"Embed Query"** → `Google Cloud - Vertex AI`
   - **"Vector Similarity Search"** → `PostgreSQL - Embeddings DB`
   - **"Call Gemini 2.5"** → `Google Cloud - Vertex AI`
3. Click **Save**
4. Toggle **Active**

**Test**:
```bash
curl -X POST http://localhost:5678/webhook/basic-ai-agent \
  -H "Content-Type: application/json" \
  -d '{"question": "What are the key features of this toolkit?"}'
```

### Workflow 3: Advanced AI Agent

**Purpose**: Multi-model RAG chatbot with MCP tool integration

**Credentials Needed**:
- LiteLLM API
- PostgreSQL - Embeddings DB

**Webhook URL**: `http://localhost:5678/webhook/advanced-ai-agent`

**Steps**:
1. Open workflow "3. Advanced AI Agent - LiteLLM with MCP"
2. Configure credentials for:
   - **"Embed Query (via LiteLLM)"** → `LiteLLM API`
   - **"Vector Similarity Search"** → `PostgreSQL - Embeddings DB`
   - **"Call LiteLLM (with MCP Tools)"** → `LiteLLM API`
3. Click **Save**
4. Toggle **Active**

**Test with different models**:
```bash
# Using Gemini
curl -X POST http://localhost:5678/webhook/advanced-ai-agent \
  -H "Content-Type: application/json" \
  -d '{"question": "Search for AI safety information", "model": "gemini-2-5-flash"}'

# Using GPT-4 (requires Azure OpenAI configured)
curl -X POST http://localhost:5678/webhook/advanced-ai-agent \
  -H "Content-Type: application/json" \
  -d '{"question": "Search for AI safety information", "model": "gpt-4"}'
```

### Workflow 4: AIRS PDF Downloader

**Purpose**: One-time download and embedding of AIRS documentation

**Credentials Needed**:
- Google Cloud - Vertex AI
- PostgreSQL - AIRS DB

**Steps**:
1. Open workflow "4. AIRS PDF Downloader - Embed Documentation"
2. Configure credentials for:
   - **"Generate Embedding"** → `Google Cloud - Vertex AI`
   - **"Store in AIRS Database"** → `PostgreSQL - AIRS DB`
3. Click **Save**
4. Click **Execute Workflow** (manual trigger)

⚠️ **Note**: This workflow takes 10-15 minutes to complete as it downloads and processes 5 PDFs.

**Monitor Progress**:
1. Watch the execution in N8N UI
2. Check database: 
   ```bash
   psql -h localhost -U dcmasters -d airs_embedding -c "SELECT document_name, COUNT(*) FROM airs.documents GROUP BY document_name;"
   ```

### Workflow 5: AIRS Chatbot

**Purpose**: Answer questions about AIRS documentation

**Credentials Needed**:
- Google Cloud - Vertex AI
- PostgreSQL - AIRS DB
- LiteLLM API

**Webhook URL**: `http://localhost:5678/webhook/airs-chatbot`

**Prerequisites**: Workflow 4 must be executed first to populate the database

**Steps**:
1. Open workflow "5. AIRS Chatbot - Query Documentation"
2. Configure credentials for:
   - **"Embed Question"** → `Google Cloud - Vertex AI`
   - **"Search AIRS Database"** → `PostgreSQL - AIRS DB`
   - **"Call LLM"** → `LiteLLM API`
3. Click **Save**
4. Toggle **Active**

**Test**:
```bash
curl -X POST http://localhost:5678/webhook/airs-chatbot \
  -H "Content-Type: application/json" \
  -d '{"question": "How do I activate AI Runtime Security?"}'
```

## Step 3: Verify Setup

### Test Workflow 1: Embedding Agent

1. Create a test file:
   ```bash
   echo "This is a test document about AI security." > data/sandbox/import/test.txt
   ```
2. Wait 5 minutes (or manually execute the workflow)
3. Check database:
   ```bash
   psql -h localhost -U dcmasters -d litellm -c "SELECT COUNT(*) FROM embeddings.documents;"
   ```
4. File should be moved to `data/sandbox/shared/`

### Test Workflow 2 & 3: AI Agents

Send test queries and verify responses include:
- Answer from LLM
- Source citations
- Web search results (if applicable)

### Test Workflow 5: AIRS Chatbot

After running Workflow 4, test with AIRS-specific questions:
- "What is AI Runtime Security?"
- "How do I configure AI model security?"
- "What are the red teaming features?"

## Troubleshooting

### Workflow Execution Fails

1. **Check Credentials**: Ensure all credentials are configured correctly
2. **Check Logs**: View execution logs in N8N UI
3. **Test Connections**: Use "Test" button on credential configuration

### "Credential not found" Error

1. Open the workflow
2. For each node with a credential error:
   - Click the node
   - Remove the old credential reference
   - Select the correct credential from the dropdown
3. Save the workflow

### Google Cloud API Errors

1. Verify Vertex AI API is enabled in your GCP project
2. Check service account has `Vertex AI User` role
3. Verify `GCP_PROJECT_ID` and `GCP_REGION` in `.env` are correct

### PostgreSQL Connection Errors

1. Verify PostgreSQL container is running: `./start-toolkit.sh status`
2. Check credentials match `.env` file
3. Ensure database exists: `psql -h localhost -U dcmasters -l`

### PDF Parsing Errors (Workflow 4)

1. Ensure `pdf-parse` is installed in N8N container:
   ```bash
   docker exec -it dc-masters-n8n npm list pdf-parse
   ```
2. If not installed:
   ```bash
   docker exec -it dc-masters-n8n npm install pdf-parse
   ```
3. Restart N8N: `./start-toolkit.sh restart n8n`

### LiteLLM Connection Errors

1. Verify LiteLLM is running: `curl http://localhost:4000/health`
2. Check master key in credential matches `.env`
3. Verify model is configured in `config/litellm/config.yaml`

## Advanced Configuration

### Custom Models in Workflow 3

Edit the workflow to use different models:
1. Open "3. Advanced AI Agent"
2. In the webhook payload, add `"model": "your-model-name"`
3. Supported models (if configured):
   - `gpt-4` (Azure OpenAI)
   - `gpt-35-turbo` (Azure OpenAI)
   - `claude-3-5-sonnet` (AWS Bedrock)
   - `gemini-2-5-flash` (Vertex AI)

### Custom Embedding Schedules

Change Workflow 1 schedule:
1. Open workflow
2. Click "Every 5 Minutes" node
3. Change interval (e.g., every 10 minutes, hourly)
4. Save

### Add More PDF Documents

Modify Workflow 4 to include additional PDFs:
1. Open "4. AIRS PDF Downloader"
2. Edit "Define PDF URLs" code node
3. Add new PDF entries to the array
4. Save and re-execute

## Next Steps

Once all workflows are configured and tested:

1. **Build Your Own Workflows**: Use these as templates
2. **Integrate with Applications**: Use the webhook URLs in your apps
3. **Customize Prompts**: Modify system prompts for different use cases
4. **Monitor Performance**: Track token usage via LiteLLM UI (http://localhost:4000)

## Support

- **Documentation**: See [README.md](README.md)
- **Logs**: `./start-toolkit.sh logs n8n`
- **Database**: Use `psql` to inspect data
- **LiteLLM**: Check http://localhost:4000 for API status

---

**Remember**: Change all default passwords in production environments!
