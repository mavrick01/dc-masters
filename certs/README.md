# Corporate CA Certificates

This directory is for corporate CA (Certificate Authority) certificates when running behind a corporate firewall with SSL inspection.

## Setup

If your organization uses SSL inspection, place your corporate CA certificate here:

```bash
certs/company-ca.pem
```

The startup script will automatically:
1. Detect the presence of `company-ca.pem`
2. Mount it into LiteLLM and N8N containers
3. Configure the following environment variables:
   - `REQUESTS_CA_BUNDLE=/app/certs/company-ca.pem`
   - `CURL_CA_BUNDLE=/app/certs/company-ca.pem`
   - `NODE_EXTRA_CA_CERTS=/app/certs/company-ca.pem`
   - `SSL_CERT_FILE=/app/certs/company-ca.pem`

## Getting Your CA Certificate

### Method 1: Extract via OpenSSL (Fastest)

```bash
openssl s_client -connect api.github.com:443 -showcerts < /dev/null 2>/dev/null | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' > certs/company-ca.pem
```

This automatically extracts the certificate chain from your corporate SSL inspection proxy. You can use any external HTTPS endpoint (github.com, google.com, azure.com, etc.).

### Method 2: From Your IT Department (Most Reliable)

Ask your IT department for the corporate root CA certificate in PEM format.

### Method 3: Export from Browser (macOS)

1. Open **Keychain Access**
2. Find your corporate root certificate
3. Right-click → **Export**
4. Save as `.pem` format
5. Copy to `certs/company-ca.pem`

### Method 4: Export from Browser (Windows)

1. Open Chrome → Settings → Privacy and security → Security → Manage certificates
2. Find your corporate root certificate
3. Export as **Base-64 encoded X.509 (.CER)**
4. Rename to `.pem` and copy to `certs/company-ca.pem`

## Verification

After placing the certificate and restarting:

```bash
./start-toolkit.sh restart
```

You should see:
```
[INFO] Corporate CA certificate detected: certs/company-ca.pem
[INFO] Configuring SSL certificate trust for LiteLLM and N8N...
[INFO] ✓ Corporate CA certificate will be trusted by services
```

## Troubleshooting

If you still see SSL errors after adding the certificate:

1. Verify the certificate is in PEM format (text file starting with `-----BEGIN CERTIFICATE-----`)
2. Ensure the filename is exactly `company-ca.pem` (lowercase)
3. Restart the toolkit: `./start-toolkit.sh restart`
4. Check logs: `./start-toolkit.sh logs litellm` or `./start-toolkit.sh logs n8n`

**For detailed troubleshooting and alternative solutions**, see [CORPORATE_FIREWALL.md](../CORPORATE_FIREWALL.md)

## Security Note

**This directory is gitignored** to prevent accidentally committing sensitive certificates.
