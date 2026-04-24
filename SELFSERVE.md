# DC-Masters Container Toolkit - Self-Service Manual Setup Guide

Complete manual setup guide with GUI-based configuration instructions. This guide is for users who prefer to configure everything through web interfaces or need to understand each step in detail.

**Looking for the automated quick start?** See [QUICKSTART.md](QUICKSTART.md) for script-based setup.

## Table of Contents

1. [Introduction](#introduction)
2. [Understanding Environment Variables](#understanding-environment-variables)
3. [Manual Certificate Setup](#manual-certificate-setup)
4. [Manual Service Startup](#manual-service-startup)
5. [Manual Database Fix](#manual-database-fix)
6. [GUI-Based Configuration](#gui-based-configuration)
7. [Manual Workflow Configuration](#manual-workflow-configuration)
8. [GUI-Based Testing and Verification](#gui-based-testing-and-verification)

---

## Introduction

This guide provides step-by-step manual instructions for setting up the DC-Masters Container Toolkit without using the automated scripts. This approach is useful for:

- **Learning**: Understanding what each component does
- **Corporate Environments**: Where scripts may be restricted
- **Debugging**: Troubleshooting specific configuration issues
- **Custom Deployments**: Adapting the setup to your specific needs

**Prerequisites**: Complete the prerequisites section in [QUICKSTART.md](QUICKSTART.md) before continuing.

---

## Understanding Environment Variables

Instead of using the automated `.env.example` → `.env` copy, here's a complete breakdown of all environment variables you need to configure.

### Database Credentials

```bash
POSTGRES_USER=dcmasters              # Choose any username
POSTGRES_PASSWORD=changeme123        # ⚠️ Change to strong password!
POSTGRES_DB=litellm                  # Default database name
```

**What these do:**
- Creates the PostgreSQL admin user
- Sets the password for database access
- Defines the default database (additional databases are created via init scripts)

### LiteLLM Settings

```bash
LITELLM_MASTER_KEY=sk-1234-changeme  # ⚠️ Generate strong key!
UI_USERNAME=admin@dcmasters.local    # LiteLLM UI username
UI_PASSWORD=changeme123              # ⚠️ Change to strong password!
```

**What these do:**
- `LITELLM_MASTER_KEY`: Master API key for LiteLLM (used to create virtual keys)
- `UI_USERNAME`: Username for the LiteLLM web UI
- `UI_PASSWORD`: Password for the LiteLLM web UI

**Security note:** These credentials protect access to your AI models and API keys.

### N8N Settings

```bash
N8N_OWNER_EMAIL=admin@dcmasters.local   # Your email for N8N
N8N_OWNER_PASSWORD=changeme123          # ⚠️ Change to strong password!
N8N_OWNER_FIRST_NAME=Admin              # Your first name
N8N_OWNER_LAST_NAME=User                # Your last name
```

**What these do:**
- Creates the N8N owner account automatically on first startup
- Owner account has full access to all workflows and credentials

### Google Cloud (Vertex AI) - REQUIRED

```bash
# Path to your service account JSON file
GOOGLE_APPLICATION_CREDENTIALS=/path/to/your/service-account.json

# Your Google Cloud project ID (from GCP Console)
GCP_PROJECT_ID=your-project-id

# Vertex AI region (choose closest to you)
GCP_REGION=us-central1
```

**How to obtain these:**

1. **Service Account JSON**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Navigate to "IAM & Admin" → "Service Accounts"
   - Click "Create Service Account"
   - Grant role: "Vertex AI User"
   - Create and download JSON key
   - Save to a secure location and update `GOOGLE_APPLICATION_CREDENTIALS`

2. **Project ID**:
   - Visible at top of GCP Console
   - Or run: `gcloud config get-value project`

3. **Region**:
   - Choose from: `us-central1`, `us-east1`, `us-west1`, `europe-west1`, `asia-southeast1`
   - Consider latency and data residency requirements

### Azure OpenAI (Optional)

```bash
AZURE_API_KEY=your-azure-api-key
AZURE_API_BASE=https://your-resource.openai.azure.com
AZURE_API_VERSION=2024-02-15-preview
```

**How to obtain these:**
1. Create Azure OpenAI resource in [Azure Portal](https://portal.azure.com/)
2. Navigate to your resource → "Keys and Endpoint"
3. Copy `KEY 1` → use as `AZURE_API_KEY`
4. Copy `Endpoint` → use as `AZURE_API_BASE`
5. API version: Use the latest from [Azure OpenAI docs](https://learn.microsoft.com/en-us/azure/ai-services/openai/reference)

### AWS Bedrock (Optional)

```bash
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION_NAME=us-east-1
```

**How to obtain these:**
1. Go to [AWS Console](https://console.aws.amazon.com/)
2. Navigate to IAM → Users → Your User
3. Security Credentials → Create Access Key
4. Download and save the Access Key ID and Secret Access Key
5. Enable Bedrock access in your account
6. Choose region: `us-east-1`, `us-west-2`, `ap-southeast-1`, etc.

### Corporate Proxy/Firewall Settings

```bash
# Disable SSL verification (only if behind corporate firewall)
NODE_TLS_REJECT_UNAUTHORIZED=0
SSL_VERIFY=false

# Proxy settings (if required)
HTTP_PROXY=http://proxy.company.com:8080
HTTPS_PROXY=http://proxy.company.com:8080
NO_PROXY=localhost,127.0.0.1,postgres,litellm,mcp-filesystem,mcp-duckduckgo,n8n
```

**When to use:**
- Corporate network with proxy server
- SSL inspection/MITM proxy
- Connection failures to external APIs

**How to obtain:**
- Contact IT department for proxy URL
- Check browser proxy settings
- Look for PAC files or system proxy configuration

---

## Manual Certificate Setup

If you're behind a corporate firewall with SSL inspection, you need to configure the corporate CA certificate.

### Step 1: Obtain Corporate CA Certificate

**Option 1: From IT Department** (most reliable)
- Request the root CA certificate in PEM format
- Save as `company-ca.pem`

**Option 2: Extract via OpenSSL**
```bash
# Test connection and extract certificate
openssl s_client -connect api.github.com:443 -showcerts < /dev/null 2>/dev/null | \
  awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' > company-ca.pem

# Verify certificate
openssl x509 -in company-ca.pem -text -noout
```

### Step 2: Place Certificate in Project

```bash
# Create certs directory
mkdir -p certs

# Copy certificate
cp /path/to/company-ca.pem certs/company-ca.pem

# Verify file exists and has content
cat certs/company-ca.pem
```

### Step 3: What Happens Next

When you start services (see next section), you need to:
1. Export environment variables pointing to the certificate
2. Mount the certificate into containers
3. Services will automatically use it for SSL verification

For detailed troubleshooting, see [CORPORATE_FIREWALL.md](CORPORATE_FIREWALL.md).

---

## Manual Service Startup

Instead of using `./start-toolkit.sh start`, here's the complete manual process:

### Step 1: Create Data Directories

```bash
# Create all required directories
mkdir -p data/{postgres,n8n,sandbox/{import,shared}}
mkdir -p credentials certs
```

**What these are for:**
- `data/postgres/` - PostgreSQL database files (persisted)
- `data/n8n/` - N8N workflow data (persisted)
- `data/sandbox/import/` - Files to be embedded by Workflow 2
- `data/sandbox/shared/` - Processed files after embedding
- `credentials/` - Service account JSON files
- `certs/` - Corporate CA certificates

### Step 2: Copy Google Cloud Credentials

```bash
# Copy service account JSON to credentials directory
# (Path from GOOGLE_APPLICATION_CREDENTIALS in .env)
cp /path/to/your/service-account.json credentials/google_credentials.json

# Set proper permissions
chmod 644 credentials/google_credentials.json

# Verify file content
cat credentials/google_credentials.json | jq '.' > /dev/null
# Should show no errors if valid JSON
```

### Step 3: Set Corporate CA Environment Variables (if applicable)

```bash
# Only if certs/company-ca.pem exists
if [ -f "certs/company-ca.pem" ]; then
  export REQUESTS_CA_BUNDLE=/app/certs/company-ca.pem
  export CURL_CA_BUNDLE=/app/certs/company-ca.pem
  export NODE_EXTRA_CA_CERTS=/app/certs/company-ca.pem
  export SSL_CERT_FILE=/app/certs/company-ca.pem
  
  echo "Corporate CA environment variables set"
fi
```

**Note:** These paths (`/app/certs/...`) are the paths INSIDE the container, not on your host.

### Step 4: Load Environment Variables

```bash
# Load .env file into shell
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo "Environment variables loaded from .env"
else
    echo "ERROR: .env file not found!"
    exit 1
fi
```

### Step 5: Start Services with Docker/Podman Compose

**For Docker:**
```bash
# Start all services in detached mode
docker compose up -d

# Verify services started
docker compose ps

# Should show:
# dc-masters-postgres   Up
# dc-masters-litellm    Up
# dc-masters-n8n        Up
```

**For Podman:**
```bash
# Start all services in detached mode
podman compose up -d

# Verify services started
podman compose ps
```

### Step 6: Wait for N8N to Be Ready

```bash
# Poll until N8N responds with HTTP 200, 401, or 403
echo "Waiting for N8N to be ready..."
until curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 | grep -q "200\|401\|403"; do
  echo "  Still waiting..."
  sleep 5
done
echo "✓ N8N is ready!"

# Wait a bit longer for full database initialization
echo "Waiting for database initialization..."
sleep 10
echo "✓ Database should be ready"
```

**What this does:**
- Polls N8N health endpoint
- HTTP 200 = ready and serving
- HTTP 401/403 = ready but needs authentication (also good)
- Waits for database schema to be created

### Step 7: Create N8N Owner Account

```bash
# For Docker:
docker exec -i dc-masters-postgres psql -U dcmasters -d n8n -f - < config/n8n/create-owner.sql

# For Podman:
podman exec -i dc-masters-postgres psql -U dcmasters -d n8n -f - < config/n8n/create-owner.sql

echo "✓ N8N owner account created"
```

**What this does:**
- Runs SQL script to create N8N owner account
- Uses credentials from `.env` (N8N_OWNER_EMAIL, N8N_OWNER_PASSWORD, etc.)
- Owner account allows you to login to N8N UI

### Step 8: Verify Services Are Running

```bash
# Check service status
# For Docker:
docker compose ps

# For Podman:
podman compose ps

# Expected output: All services should show "Up" status
```

**Access the UIs:**
- LiteLLM: http://localhost:4000
- N8N: http://localhost:5678
- PostgreSQL: `psql -h localhost -U dcmasters -d litellm`

---

## Manual Database Fix

Instead of running `./bug-fix-litellm-db.sh`, here's the manual process:

### Step 1: Wait for LiteLLM to Be Ready

```bash
# Poll LiteLLM health endpoint
echo "Waiting for LiteLLM to be ready..."
until curl -s http://localhost:4000/health/liveness | grep -q "OK\|healthy"; do
  echo "  Still waiting..."
  sleep 5
done
echo "✓ LiteLLM is ready!"
```

### Step 2: Apply Schema Fix

**For Docker:**
```bash
docker exec dc-masters-postgres psql -U dcmasters -d litellm \
  -c "ALTER TABLE \"LiteLLM_MCPServerTable\" ADD COLUMN IF NOT EXISTS \"source_url\" TEXT;"

echo "✓ Database schema fix applied"
```

**For Podman:**
```bash
podman exec dc-masters-postgres psql -U dcmasters -d litellm \
  -c "ALTER TABLE \"LiteLLM_MCPServerTable\" ADD COLUMN IF NOT EXISTS \"source_url\" TEXT;"

echo "✓ Database schema fix applied"
```

### Step 3: Verify Fix

```bash
# Check that column exists
docker exec dc-masters-postgres psql -U dcmasters -d litellm \
  -c "\d \"LiteLLM_MCPServerTable\"" | grep source_url

# Should show: source_url | text
```

**Why this is needed:**
- LiteLLM migration bug sometimes skips creating the `source_url` column
- Without this column, MCP server configuration fails
- This is a known issue in LiteLLM v1.x

---

## GUI-Based Configuration

This section covers configuring everything through the web UIs instead of using `./configure-toolkit.sh`.

### 6.1 - Verify Services Are Ready

1. **Open LiteLLM UI**: http://localhost:4000 in browser
   - Should show login page or dashboard
2. **Open N8N UI**: http://localhost:5678 in browser
   - Should show login page or workflows

**If either doesn't load:**
```bash
# Check logs
docker compose logs litellm
docker compose logs n8n

# Or for Podman:
podman compose logs litellm
podman compose logs n8n
```

Wait a few more minutes - LiteLLM can take 3-5 minutes to fully initialize.

### 6.2 - Configure LiteLLM Models via UI

#### Login to LiteLLM

1. Open http://localhost:4000
2. Click **Sign In** or **Login**
3. Enter credentials from `.env`:
   - **Username**: `admin@dcmasters.local` (or your `UI_USERNAME`)
   - **Password**: `changeme123` (or your `UI_PASSWORD`)
4. Click **Sign In**

#### Add Gemini Models (Google Cloud/Vertex AI)

1. **Navigate to Models** section in left sidebar
2. **Click "Add Model"** button

**Model 1: Gemini 2.5 Flash**
- **Model Name**: `gemini-2-5-flash`
- **LiteLLM Model**: `vertex_ai/gemini-2.5-flash`
- **Vertex Project**: (your `GCP_PROJECT_ID` from `.env`)
- **Vertex Location**: (your `GCP_REGION` from `.env`)
- **Vertex Credentials Path**: `/app/credentials/google_credentials.json`
- Click **Save** or **Create**

**Model 2: Gemini 2.0 Flash**
- **Model Name**: `gemini-2-0-flash`
- **LiteLLM Model**: `vertex_ai/gemini-2.0-flash`
- **Vertex Project**: (your `GCP_PROJECT_ID`)
- **Vertex Location**: (your `GCP_REGION`)
- **Vertex Credentials Path**: `/app/credentials/google_credentials.json`
- Click **Save**

**Model 3: Text Embedding 004**
- **Model Name**: `text-embedding-004`
- **LiteLLM Model**: `vertex_ai/text-embedding-004`
- **Vertex Project**: (your `GCP_PROJECT_ID`)
- **Vertex Location**: (your `GCP_REGION`)
- **Vertex Credentials Path**: `/app/credentials/google_credentials.json`
- Click **Save**

#### Add Azure OpenAI Models (Optional)

If you configured Azure credentials in `.env`:

**GPT-4:**
- **Model Name**: `gpt-4`
- **LiteLLM Model**: `azure/gpt-4`
- **API Base**: (your `AZURE_API_BASE`)
- **API Key**: (your `AZURE_API_KEY`)
- **API Version**: (your `AZURE_API_VERSION`)
- Click **Save**

**GPT-3.5 Turbo:**
- **Model Name**: `gpt-35-turbo`
- **LiteLLM Model**: `azure/gpt-35-turbo`
- **API Base**: (your `AZURE_API_BASE`)
- **API Key**: (your `AZURE_API_KEY`)
- **API Version**: (your `AZURE_API_VERSION`)
- Click **Save**

#### Add AWS Bedrock Models (Optional)

If you configured AWS credentials in `.env`:

**Claude 3.5 Sonnet:**
- **Model Name**: `claude-3-5-sonnet`
- **LiteLLM Model**: `bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0`
- **AWS Access Key ID**: (your `AWS_ACCESS_KEY_ID`)
- **AWS Secret Access Key**: (your `AWS_SECRET_ACCESS_KEY`)
- **AWS Region**: (your `AWS_REGION_NAME`)
- Click **Save**

**Claude 3 Opus:**
- **Model Name**: `claude-3-opus`
- **LiteLLM Model**: `bedrock/anthropic.claude-3-opus-20240229-v1:0`
- **AWS Access Key ID**: (your `AWS_ACCESS_KEY_ID`)
- **AWS Secret Access Key**: (your `AWS_SECRET_ACCESS_KEY`)
- **AWS Region**: (your `AWS_REGION_NAME`)
- Click **Save**

#### Verify Models

1. Navigate to **Models** section
2. Verify all models appear in the list
3. Click on each model to view details
4. Test in **Playground**: http://localhost:4000/ui/?page=llm-playground
   - Select a model from dropdown
   - Enter a test prompt: "Hello, how are you?"
   - Click **Send**
   - Should receive a response

### 6.3 - Configure MCP Servers via UI

MCP (Model Context Protocol) servers provide tools for AI models.

1. **Navigate to MCP Servers** in LiteLLM UI (left sidebar)
2. **Click "Add MCP Server"**

#### Brave Search MCP Server

**Configuration:**
- **Name**: `brave_search`
- **Transport**: `stdio`
- **Command**: `npx`
- **Arguments**: Add each argument separately:
  1. Click "Add Argument" → Enter: `-y`
  2. Click "Add Argument" → Enter: `@modelcontextprotocol/server-brave-search`
- **Environment Variables**:
  - Click "Add Environment Variable"
  - Key: `BRAVE_API_KEY`
  - Value: (your Brave API key - get from https://brave.com/search/api/)
  - If behind firewall, add another variable:
    - Key: `NODE_TLS_REJECT_UNAUTHORIZED`
    - Value: `0`
- Click **Save** or **Create**

**What this does:**
- Enables web search capability for AI models
- Uses Brave Search API (privacy-focused)
- Requires Brave API key (free tier available)

#### Filesystem MCP Server

**Configuration:**
- **Name**: `filesystem_stdio`
- **Transport**: `stdio`
- **Command**: `npx`
- **Arguments**: Add each argument separately:
  1. Click "Add Argument" → Enter: `-y`
  2. Click "Add Argument" → Enter: `@modelcontextprotocol/server-filesystem`
  3. Click "Add Argument" → Enter: `/projects`
- Click **Save** or **Create**

**What this does:**
- Allows AI models to read/write files
- Restricted to `/projects` directory inside container
- Useful for code analysis and file operations

### 6.4 - Create LiteLLM Virtual Key via UI

Virtual keys allow you to create limited-access API keys for specific models.

1. **Navigate to "API Keys"** or **"Virtual Keys"** in LiteLLM UI
2. **Click "Generate New Key"** or **"Create Key"**

**Configuration:**
- **Key Alias**: `n8n-workflows` (or any name)
- **Models**: Select the models to allow:
  - ✅ `gemini-2-5-flash`
  - ✅ `gemini-2-0-flash`
  - ✅ `text-embedding-004`
  - (Add more if you configured Azure/AWS)
- **Duration**: `30 days` (or select "Custom" for longer)
- **Budget** (optional): Set spending limits if desired
- **Metadata** (optional): Add tags or description

3. **Click "Generate"** or **"Create"**

4. **⚠️ CRITICAL**: Copy the generated key immediately!
   - Format: `sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - **This is shown only once!**
   - Save it somewhere secure

5. **Save to .env** (optional but recommended):
   ```bash
   # Add to .env file for reference
   echo "LITELLM_VIRTUAL_KEY=sk-your-key-here" >> .env
   ```

**What this is for:**
- N8N workflows will use this key to access LiteLLM
- Limits access to only the models you selected
- Can be revoked or regenerated if compromised

### 6.5 - Create N8N Credentials via UI

N8N needs credentials to connect to external services.

#### Login to N8N

1. **Open N8N UI**: http://localhost:5678
2. **Login** with credentials from `.env`:
   - **Email**: `admin@dcmasters.local` (or your `N8N_OWNER_EMAIL`)
   - **Password**: `changeme123` (or your `N8N_OWNER_PASSWORD`)
3. Click **Sign In**

#### Navigate to Credentials

1. Click **Settings** icon (gear) in left sidebar
2. Click **Credentials** in the settings menu

#### Credential 1: Google Cloud - Vertex AI

1. **Click "Add Credential"** button
2. **Search** for "Google" in the search box
3. **Select** "Google Cloud" from results
4. **Choose authentication method**: "Service Account"
5. **Configure**:
   - **Credential Name**: `Google Cloud - Vertex AI`
   - **Service Account Email**: (auto-filled from JSON)
   - **Private Key**: Click **"Upload File"** and select your `service-account.json`
     - Or paste JSON content directly
   - Path to JSON: Upload from `credentials/google_credentials.json` on your machine
6. **Click "Save"**

#### Credential 2: PostgreSQL - Embeddings DB

1. **Click "Add Credential"** button
2. **Search** for "Postgres" or "PostgreSQL"
3. **Select** "Postgres" from results
4. **Configure**:
   - **Credential Name**: `PostgreSQL - Embeddings DB`
   - **Host**: `postgres` (container name, not localhost!)
   - **Database**: `litellm`
   - **User**: `dcmasters` (or your `POSTGRES_USER` from `.env`)
   - **Password**: `changeme123` (or your `POSTGRES_PASSWORD`)
   - **Port**: `5432`
   - **SSL**: Select **"Disable"**
   - **Allow Unauthorized Certificates**: Unchecked
5. **Click "Test Connection"** button
   - Should show: ✅ "Connection successful"
6. **Click "Save"**

#### Credential 3: PostgreSQL - AIRS DB

1. **Click "Add Credential"** button
2. **Search** for "Postgres"
3. **Select** "Postgres"
4. **Configure**:
   - **Credential Name**: `PostgreSQL - AIRS DB`
   - **Host**: `postgres`
   - **Database**: `airs_embedding` (different from above!)
   - **User**: `dcmasters`
   - **Password**: `changeme123`
   - **Port**: `5432`
   - **SSL**: **"Disable"**
5. **Click "Test Connection"** → Should show ✅
6. **Click "Save"**

#### Credential 4: LiteLLM API

N8N needs to authenticate with LiteLLM using the virtual key you created.

**Option A: Using OpenAI API Credential Type** (recommended)

1. **Click "Add Credential"** button
2. **Search** for "OpenAI"
3. **Select** "OpenAI" from results
4. **Configure**:
   - **Credential Name**: `LiteLLM API`
   - **API Key**: (paste the virtual key from Step 6.4)
     - Format: `sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - **Base URL**: `http://litellm:4000` (container name!)
   - **Organization** (optional): Leave empty
5. **Click "Save"**

**Option B: Using HTTP Header Auth**

1. **Click "Add Credential"** button
2. **Search** for "HTTP Header"
3. **Select** "HTTP Header Auth"
4. **Configure**:
   - **Credential Name**: `LiteLLM API`
   - **Header Name**: `Authorization`
   - **Header Value**: `Bearer sk-your-virtual-key-here`
     - Make sure to include "Bearer " prefix!
5. **Click "Save"**

#### Verify All Credentials

1. **Navigate to Settings → Credentials**
2. **Verify 4 credentials** are listed:
   - ✅ Google Cloud - Vertex AI
   - ✅ PostgreSQL - Embeddings DB
   - ✅ PostgreSQL - AIRS DB
   - ✅ LiteLLM API
3. **Test each credential**:
   - Click on credential name
   - Click **"Test"** button
   - Should show success message

### 6.6 - Import N8N Workflows via UI

Now import the 5 pre-built workflows.

1. **Navigate to "Workflows"** tab in N8N UI (left sidebar)
2. **For each workflow file**, perform the following:

#### Import Process

1. **Click "Add Workflow"** button (top right)
2. **Select "Import from File"** from dropdown
3. **Navigate** to your toolkit directory on your local machine:
   - Path: `/path/to/dc-masters/workflows/`
4. **Select** the workflow JSON file
5. **Click "Open"** or **"Import"**
6. **Wait** for import to complete
7. **Workflow opens** with warning icons ⚠️ on nodes
   - This is expected - credentials not yet assigned

#### Workflow Files to Import

Import these files in order:

| Order | Filename | Workflow Name |
|-------|----------|---------------|
| 1 | `1-airs-pdf-downloader.json` | AIRS PDF Downloader |
| 2 | `2-embedding-agent.json` | Embedding Agent |
| 3 | `3-basic-ai-agent.json` | Basic AI Agent |
| 4 | `4-advanced-ai-agent.json` | Advanced AI Agent |
| 5 | `5-airs-chatbot.json` | AIRS Chatbot |

**After importing all 5 workflows:**
- Navigate to **Workflows** tab
- Should see 5 workflows listed
- Each will show "Inactive" status
- Each will have credential warnings ⚠️ (we'll fix next)

---

## Manual Workflow Configuration

Now assign credentials to each workflow and activate them.

### Workflow 1: AIRS PDF Downloader 📥

**Purpose**: One-time download and embedding of AIRS documentation

1. **Open Workflow 1** from Workflows list
2. **For each node with ⚠️ warning**:
   - Click on the node
   - In the right panel, find the **Credential** dropdown
   - Select the appropriate credential:
     - For Gemini/Vertex nodes → Select **"Google Cloud - Vertex AI"**
     - For PostgreSQL nodes → Select **"PostgreSQL - AIRS DB"**
   - Node warning should disappear
3. **Save the workflow** (Ctrl+S or click Save button)
4. **Do NOT activate** - this is a manual trigger workflow

**To execute:**
- Click **"Execute Workflow"** button (top right)
- Watch execution progress in real-time
- **Time**: 10-15 minutes to download and embed 5 PDFs
- When complete, check execution log for success

**What it does:**
- Downloads 5 AIRS PDF documents
- Extracts text and creates chunks
- Generates embeddings using Vertex AI
- Stores in `airs_embedding` database
- **This populates the RAG database for Workflow 5**

### Workflow 2: Embedding Agent 📥

**Purpose**: Auto-embed files from `/data/sandbox/import/` directory

1. **Open Workflow 2**
2. **Assign credentials** to nodes:
   - Vertex AI nodes → **"Google Cloud - Vertex AI"**
   - PostgreSQL nodes → **"PostgreSQL - Embeddings DB"** (different DB!)
3. **Save the workflow**
4. **Toggle "Active"** switch (top right)
   - Should change from red "Inactive" to green "Active"

**How it works:**
- Runs every 5 minutes (configurable in workflow)
- Checks `/data/sandbox/import/` for new files
- Creates embeddings using Vertex AI text-embedding-004
- Stores in `litellm.embeddings.documents` table
- Moves processed files to `/data/sandbox/shared/`

**Test it:**
```bash
# Create a test file
echo "Artificial intelligence is transforming cybersecurity with advanced threat detection and automated response capabilities." > data/sandbox/import/ai-security.txt

# Wait 5 minutes or manually execute the workflow
# Check that file moved:
ls data/sandbox/shared/
# Should show: ai-security.txt
```

### Workflow 3: Basic AI Agent 💬

**Purpose**: RAG chatbot using Vertex AI Gemini

**Prerequisites**: Workflow 2 must be active and have embedded some files

1. **Open Workflow 3**
2. **Assign credentials**:
   - Vertex AI nodes → **"Google Cloud - Vertex AI"**
   - PostgreSQL nodes → **"PostgreSQL - Embeddings DB"**
3. **Save the workflow**
4. **Toggle "Active"** switch

**Webhook URL**: `http://localhost:5678/webhook/basic-ai-agent`

**How it works:**
1. Receives question via webhook
2. Searches embeddings database for relevant documents
3. Constructs prompt with context
4. Sends to Gemini 2.5 Flash
5. Returns answer with sources

**Test** (see GUI testing section below)

### Workflow 4: Advanced AI Agent 💬

**Purpose**: Multi-model RAG chatbot with MCP tool integration

**Prerequisites**: Workflow 2 must be active and have embedded some files

1. **Open Workflow 4**
2. **Assign credentials**:
   - LiteLLM nodes → **"LiteLLM API"**
   - PostgreSQL nodes → **"PostgreSQL - Embeddings DB"**
3. **Save the workflow**
4. **Toggle "Active"** switch

**Webhook URL**: `http://localhost:5678/webhook/advanced-ai-agent`

**How it works:**
1. Receives question and optional model parameter
2. Searches embeddings database
3. Optionally uses MCP tools (web search, filesystem)
4. Sends to LiteLLM (can use Gemini, GPT, Claude)
5. Returns answer with sources

**Features:**
- Model selection via request parameter
- MCP tool integration (if configured)
- Multi-model support

### Workflow 5: AIRS Chatbot 💬

**Purpose**: Answer questions about AIRS documentation

**Prerequisites**: Workflow 1 must be executed first!

1. **Open Workflow 5**
2. **Assign credentials**:
   - Vertex AI nodes → **"Google Cloud - Vertex AI"**
   - PostgreSQL nodes → **"PostgreSQL - AIRS DB"**
   - LiteLLM nodes → **"LiteLLM API"**
3. **Save the workflow**
4. **Toggle "Active"** switch

**Webhook URL**: `http://localhost:5678/webhook/airs-chatbot`

**How it works:**
1. Receives question about AIRS
2. Searches `airs_embedding` database
3. Retrieves relevant documentation chunks
4. Sends to LiteLLM with context
5. Returns answer with PDF sources

**Example questions:**
- "What is AI Runtime Security?"
- "How does AIRS detect model poisoning?"
- "What are the key features of AIRS?"

---

## GUI-Based Testing and Verification

### Test RAG Workflows in N8N UI

The best way to verify everything is working is to test workflows in the N8N interface.

#### Test Workflow 3 (Basic AI Agent)

**Method 1: Manual Execution in N8N**

1. **Open N8N**: http://localhost:5678
2. **Navigate to Workflows** → **3. Basic AI Agent - RAG with Gemini**
3. **Click** on the workflow to open it
4. **Click "Execute Workflow"** button (top right)
5. **In the Webhook node** (first node):
   - Click on the node
   - In right panel, find **"Test Event"** or **"Manual Trigger"** section
   - Enter test data:
     ```json
     {
       "question": "What files have been embedded?"
     }
     ```
6. **Click "Execute"**
7. **Watch execution**:
   - Each node lights up as it executes
   - Click on nodes to see input/output data
8. **Check results**:
   - **Vector Similarity Search** node:
     - Should show retrieved documents
     - Look for document text and metadata
   - **Final response node**:
     - Should show AI-generated answer
     - Should include **Sources** section
     - ✅ **If you see sources, RAG is working!**

**Method 2: Browser Developer Console**

1. **Open N8N workflow** as above
2. **Open browser developer tools** (F12)
3. **Go to Console tab**
4. **Run this JavaScript**:
   ```javascript
   fetch('http://localhost:5678/webhook/basic-ai-agent', {
     method: 'POST',
     headers: {'Content-Type': 'application/json'},
     body: JSON.stringify({
       question: 'What files have been embedded?'
     })
   })
   .then(r => r.json())
   .then(data => {
     console.log('Response:', data);
   })
   .catch(err => {
     console.error('Error:', err);
   });
   ```
5. **Check console output**:
   - Should show response with answer and sources

**What to look for:**
- ✅ Execution completes without errors
- ✅ Vector search returns documents
- ✅ Response includes sources from your embedded files
- ❌ If no sources: Workflow 2 hasn't embedded files yet

#### Test Workflow 4 (Advanced AI Agent)

1. **Navigate to Workflow 4** in N8N
2. **Open the workflow**
3. **Click "Execute Workflow"**
4. **Enter test data** in Webhook node:
   ```json
   {
     "question": "What information do you have?",
     "model": "gemini-2-5-flash"
   }
   ```
5. **Click "Execute"**
6. **Check execution results**:
   - **Vector Similarity Search** node → should show embeddings
   - **LiteLLM node** → should show model response
   - **Final response** → should include sources

**Test different models:**
```json
{
  "question": "Explain AI security concepts",
  "model": "gpt-4"
}
```
(If you configured Azure OpenAI)

#### Test Workflow 5 (AIRS Chatbot)

**Prerequisites**: Workflow 1 must have been executed!

1. **Navigate to Workflow 5** in N8N
2. **Open the workflow**
3. **Click "Execute Workflow"**
4. **Enter test data**:
   ```json
   {
     "question": "What is AI Runtime Security?"
   }
   ```
5. **Click "Execute"**
6. **Check execution results**:
   - **Search AIRS Database** node:
     - Should show AIRS document chunks
     - Look for PDF filenames (e.g., "AIRS_Overview.pdf")
   - **Final response**:
     - Should include answer based on AIRS docs
     - **Sources** section should show AIRS PDFs
     - ✅ **If you see AIRS sources, RAG database is working!**

**If AIRS database is empty:**
- Go back to Workflow 1
- Execute it manually
- Wait 10-15 minutes for completion
- Check database:
  ```bash
  psql -h localhost -U dcmasters -d airs_embedding \
    -c "SELECT document_name, COUNT(*) FROM airs.documents GROUP BY document_name;"
  ```

### Verify Databases Directly

**Check Embeddings Database** (populated by Workflow 2):
```bash
psql -h localhost -U dcmasters -d litellm \
  -c "SELECT COUNT(*) FROM embeddings.documents;"

# Expected: Number > 0 after Workflow 2 runs

# See sample documents:
psql -h localhost -U dcmasters -d litellm \
  -c "SELECT document_name, content_snippet FROM embeddings.documents LIMIT 5;"
```

**Check AIRS Database** (populated by Workflow 1):
```bash
psql -h localhost -U dcmasters -d airs_embedding \
  -c "SELECT document_name, COUNT(*) as chunks FROM airs.documents GROUP BY document_name ORDER BY document_name;"

# Expected: 5 AIRS PDFs with chunk counts
# Example output:
#        document_name        | chunks
# ----------------------------+--------
#  AIRS_Overview.pdf          |    42
#  AIRS_Architecture.pdf      |    38
#  AIRS_Deployment_Guide.pdf  |    51
#  ...
```

### Verify LiteLLM Models

1. **Open LiteLLM Playground**: http://localhost:4000/ui/?page=llm-playground
2. **Select a model** from dropdown (e.g., "gemini-2-5-flash")
3. **Enter test prompt**: "Hello, how are you?"
4. **Click "Send"** or **"Generate"**
5. **Should receive response**:
   - ✅ Model is working
   - ❌ Error: Check model configuration or credentials

### Verify N8N Workflows Are Active

1. **Open N8N**: http://localhost:5678
2. **Navigate to Workflows**
3. **Check status badges**:
   - Workflow 1: ⚪ Inactive (manual trigger - expected)
   - Workflow 2: 🟢 Active
   - Workflow 3: 🟢 Active
   - Workflow 4: 🟢 Active
   - Workflow 5: 🟢 Active

4. **Check recent executions**:
   - Click on a workflow
   - Look at **Executions** tab (right panel)
   - Should show recent runs with success/failure status

---

## Summary

You've now completed the full manual setup! You should have:

✅ Configured all environment variables  
✅ Set up corporate certificates (if needed)  
✅ Manually started all services  
✅ Applied database fix  
✅ Configured LiteLLM models via GUI  
✅ Configured MCP servers via GUI  
✅ Created LiteLLM virtual key via GUI  
✅ Created N8N credentials via GUI  
✅ Imported all 5 workflows via GUI  
✅ Assigned credentials to workflows  
✅ Activated workflows  
✅ Tested RAG functionality via GUI  

For troubleshooting, see [QUICKSTART.md](QUICKSTART.md) or [README.md](README.md).

For automated setup, see [QUICKSTART.md](QUICKSTART.md).

**Happy Learning!** 🚀
