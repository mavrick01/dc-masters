# Corporate Firewall Configuration Guide

This guide helps you configure the DC-Masters Container Toolkit to work behind corporate firewalls with SSL inspection and proxy requirements.

## Common Corporate Firewall Issues

### Symptoms

1. **SSL Certificate Errors**:
   ```
   [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: self-signed certificate in certificate chain
   ```

2. **Connection Timeouts**:
   - Unable to pull container images
   - Cannot connect to external APIs (Google Cloud, Azure, AWS)
   - PDF downloads fail in workflows

3. **Proxy Authentication Required**:
   - HTTP 407 Proxy Authentication Required errors

## Solution 1: Use Corporate CA Certificate (Recommended) ⚡ AUTOMATIC

✅ **This is the most secure and reliable method for corporate firewalls.**

✨ **NEW:** The toolkit automatically detects and configures corporate CA certificates - no manual configuration needed!

### Step 1: Get your corporate CA certificate

**Option A: From IT Department** (Most reliable)
- Request the root CA certificate in PEM format from your IT team

**Option B: Extract via OpenSSL** (Fastest)
```bash
openssl s_client -connect api.github.com:443 -showcerts < /dev/null 2>/dev/null | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' > certs/company-ca.pem
```

This captures the certificate chain presented by your corporate SSL inspection proxy. The command:
- Connects to any external HTTPS endpoint (github.com in this example)
- Captures all certificates in the chain
- Saves them to `certs/company-ca.pem`

**Note**: You can use any external HTTPS endpoint instead of `api.github.com` (e.g., `google.com`, `openai.azure.com`).

**Option C: Export from macOS Keychain**
1. Open **Keychain Access**
2. Find your corporate root certificate (usually under "System" keychain)
3. Right-click → **Export**
4. Save as PEM format

**Option D: Export from Windows**
1. Chrome → Settings → Privacy and security → Security → Manage certificates
2. Export root certificate as Base-64 encoded X.509 (.CER)
3. Rename to `.pem`

### Step 2: Place certificate in certs directory

```bash
# Copy your corporate CA certificate
cp /path/to/your-corporate-cert.pem certs/company-ca.pem
```

**Important**: The filename must be exactly `company-ca.pem`

### Step 3: Restart the toolkit

```bash
./start-toolkit.sh restart
```

You should see:
```
[INFO] Corporate CA certificate detected: certs/company-ca.pem
[INFO] Configuring SSL certificate trust for LiteLLM and N8N...
[INFO] ✓ Corporate CA certificate will be trusted by services
```

### What This Does (Automatically!)

The `start-toolkit.sh` script automatically:
- ✅ Detects `certs/company-ca.pem` on startup
- ✅ Mounts it into LiteLLM and N8N containers at `/app/certs/company-ca.pem`
- ✅ Configures certificate trust for Python (requests, urllib), curl, and Node.js
- ✅ Sets environment variables: `REQUESTS_CA_BUNDLE`, `CURL_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS`, `SSL_CERT_FILE`
- ✅ Services will trust your corporate SSL inspection certificates

**No manual environment variable configuration needed!** Just place the file and restart.

### Verification

Test LiteLLM connectivity:
```bash
curl http://localhost:4000/health
```

Check N8N can connect to external APIs via the UI at http://localhost:5678

## Solution 2: Disable SSL Verification (Quick Fix)

⚠️ **WARNING**: Only use this in trusted corporate environments. This reduces security.

### Step 1: Edit `.env` file

Add these lines to your `.env` file:

```bash
# Disable SSL verification for Node.js applications (N8N, MCP servers)
NODE_TLS_REJECT_UNAUTHORIZED=0

# Disable SSL verification for Python applications (LiteLLM)
SSL_VERIFY=false
```

### Step 2: Restart services

```bash
./start-toolkit.sh stop
./start-toolkit.sh start
```

### What This Does

- **LiteLLM**: Falls back to local model cost map (already does this automatically)
- **N8N**: Allows HTTPS requests to external APIs with self-signed certificates
- **MCP Servers**: Allows web searches and URL fetching through corporate proxy

### Verification

Check logs for SSL errors:

```bash
# LiteLLM should show "Falling back to local backup" (this is OK)
./start-toolkit.sh logs litellm | grep -i ssl

# N8N should not show certificate errors
./start-toolkit.sh logs n8n | grep -i certificate
```

## Solution 3: Configure Corporate Proxy

If your network requires an HTTP proxy:

### Step 1: Get proxy details from IT

You need:
- Proxy host and port (e.g., `proxy.company.com:8080`)
- Authentication credentials (if required)

### Step 2: Update `.env` file

```bash
# Without authentication
HTTP_PROXY=http://proxy.company.com:8080
HTTPS_PROXY=http://proxy.company.com:8080

# With authentication (URL-encode special characters)
# HTTP_PROXY=http://username:password@proxy.company.com:8080
# HTTPS_PROXY=http://username:password@proxy.company.com:8080

# Bypass proxy for internal services
NO_PROXY=localhost,127.0.0.1,postgres,litellm,mcp-filesystem,mcp-duckduckgo,n8n
```

### Step 3: Configure container runtime to use proxy

**For Docker:**

Create or edit `~/.docker/config.json`:

```json
{
  "proxies": {
    "default": {
      "httpProxy": "http://proxy.company.com:8080",
      "httpsProxy": "http://proxy.company.com:8080",
      "noProxy": "localhost,127.0.0.1"
    }
  }
}
```

**For Podman:**

Edit `/etc/containers/containers.conf` (may need sudo):

```ini
[engine]
http_proxy = "http://proxy.company.com:8080"
https_proxy = "http://proxy.company.com:8080"
no_proxy = "localhost,127.0.0.1"
```

Or set environment variables before running podman:

```bash
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
./start-toolkit.sh start
```

### Step 4: Restart services

```bash
./start-toolkit.sh stop
./start-toolkit.sh start
```

## Solution 4: Combined Approach (Most Common)

For typical corporate environments, combine CA certificate + proxy:

### Step 1: Place your corporate CA certificate

```bash
cp /path/to/your-cert.pem certs/company-ca.pem
```

### Step 2: Configure proxy in `.env`:

```bash
# Corporate proxy
HTTP_PROXY=http://proxy.company.com:8080
HTTPS_PROXY=http://proxy.company.com:8080
NO_PROXY=localhost,127.0.0.1,postgres,litellm,mcp-filesystem,mcp-duckduckgo,n8n

# Only if CA certificate alone doesn't work:
# REQUESTS_CA_BUNDLE=/app/certs/corporate-ca-bundle.crt
# CURL_CA_BUNDLE=/app/certs/corporate-ca-bundle.crt
# NODE_EXTRA_CA_CERTS=/app/certs/corporate-ca-bundle.crt
```

## Troubleshooting Specific Issues

### Issue: Container Images Won't Pull

**Error**: `Error response from daemon: Get https://registry...`

**Solution**:
1. Configure your container runtime (Docker/Podman) to use the corporate proxy
2. May need to add corporate CA cert to container runtime trust store

**For Docker**:
```bash
# Add CA cert to Docker
sudo mkdir -p /etc/docker/certs.d/registry-1.docker.io
sudo cp corporate-ca-bundle.crt /etc/docker/certs.d/registry-1.docker.io/ca.crt
sudo systemctl restart docker
```

**For Podman**:
```bash
# Copy to system trust store
sudo cp corporate-ca-bundle.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

### Issue: Google Cloud API Fails

**Error**: `certificate verify failed` when calling Vertex AI

**Solutions**:

**Option A**: Disable SSL verification (quick but less secure)
```bash
NODE_TLS_REJECT_UNAUTHORIZED=0
```

**Option B**: Use corporate CA bundle
```bash
REQUESTS_CA_BUNDLE=/app/certs/corporate-ca-bundle.crt
```

**Option C**: Use proxy that doesn't inspect Google API traffic
```bash
# Add Google domains to NO_PROXY
NO_PROXY=localhost,127.0.0.1,*.googleapis.com,*.google.com,postgres,litellm,mcp-filesystem,mcp-duckduckgo
```

### Issue: Azure OpenAI Connection Fails

**Error**: SSL errors when connecting to Azure OpenAI endpoint

**Solution**: Same as Google Cloud - use one of the three options above.

### Issue: PDF Downloads Fail (Workflow 4)

**Error**: Certificate errors when downloading AIRS PDFs

**Solution**:

1. Add SSL bypass to the workflow's HTTP Request node in N8N:
   - Open Workflow 4
   - Edit "Download PDF" node
   - Add option: `Ignore SSL Issues: true`

2. Or, update environment:
```bash
NODE_TLS_REJECT_UNAUTHORIZED=0
```

### Issue: MCP DuckDuckGo Search Fails

**Error**: SSL errors or timeouts when searching

**Solution**:

1. Ensure proxy is configured:
```bash
HTTP_PROXY=http://proxy.company.com:8080
HTTPS_PROXY=http://proxy.company.com:8080
```

2. Disable SSL verification:
```bash
NODE_TLS_REJECT_UNAUTHORIZED=0
```

3. Verify DuckDuckGo isn't blocked by your firewall:
```bash
curl -I https://duckduckgo.com
```

## Testing Your Configuration

### Test 1: LiteLLM Startup

```bash
./start-toolkit.sh logs litellm | head -50
```

**Expected**: Should see "Falling back to local backup" message (this is OK), but no other SSL errors.

### Test 2: N8N External Request

1. Create a simple N8N workflow
2. Add HTTP Request node
3. Test request to: `https://www.google.com`
4. Should succeed without certificate errors

### Test 3: MCP DuckDuckGo

```bash
curl -X POST http://localhost:8001/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"search","arguments":{"query":"test"}},"id":1}'
```

**Expected**: Search results without SSL errors.

### Test 4: Google Cloud API (Vertex AI)

Run Workflow 1 (Embedding Agent) with a test file. Should complete without SSL errors.

## Security Considerations

### When to Disable SSL Verification

✅ **Safe**:
- Educational/training environment
- Behind trusted corporate firewall
- Temporary for testing

❌ **Unsafe**:
- Production environments
- Public networks
- Untrusted proxies

### Best Practices

1. **Prefer CA bundle over disabling SSL**
   - Request corporate CA certificate from IT
   - Mount as volume in containers
   - Configure via environment variables

2. **Use selective SSL bypass**
   - Only disable for specific services that need it
   - Keep SSL enabled for production APIs

3. **Document your configuration**
   - Note why SSL is disabled
   - Document proxy settings for team members
   - Include corporate IT contact for CA cert updates

4. **Monitor and audit**
   - Review logs for unexpected SSL warnings
   - Test with SSL enabled periodically
   - Update CA bundle when corporate certs rotate

## Getting Help from IT

When requesting help from your corporate IT team, provide:

1. **What you need**:
   - Corporate root CA certificate (`.crt` or `.pem` format)
   - Proxy server address and port
   - Proxy authentication credentials (if required)
   - Whitelist for external APIs (googleapis.com, azure.com, amazonaws.com)

2. **Why you need it**:
   - Educational container-based AI toolkit
   - Needs to access cloud AI APIs (Google Vertex AI, Azure OpenAI, AWS Bedrock)
   - Requires downloading container images from Docker Hub / GitHub Container Registry

3. **Ports required**:
   - Outbound HTTPS (443) to: googleapis.com, openai.azure.com, bedrock.amazonaws.com
   - Container registry access: registry-1.docker.io, ghcr.io

## Summary

**🚀 Recommended approach (easiest and most secure):**

1. Get corporate CA certificate from IT (see Step 1 above)
2. Copy to toolkit: `cp /path/to/cert.pem certs/company-ca.pem`
3. Start toolkit: `./start-toolkit.sh start`

**That's it!** The toolkit automatically detects and configures the certificate.

---

**⚡ Quick fix if you can't get CA certificate:**

1. Copy `.env.example` to `.env`
2. Add these lines:
   ```bash
   NODE_TLS_REJECT_UNAUTHORIZED=0
   SSL_VERIFY=false
   HTTP_PROXY=http://proxy.company.com:8080  # if using proxy
   HTTPS_PROXY=http://proxy.company.com:8080  # if using proxy
   NO_PROXY=localhost,127.0.0.1,postgres,litellm,mcp-filesystem,mcp-duckduckgo
   ```
3. Restart: `./start-toolkit.sh restart`

This should resolve 90% of corporate firewall issues, but CA certificate is preferred.

---

**Still having issues?** Check the main [README.md](README.md) troubleshooting section or contact your IT department.
