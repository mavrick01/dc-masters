# SearXNG Configuration

This directory contains the configuration for SearXNG, a privacy-respecting metasearch engine.

## Files

- `settings.yml` - Main SearXNG configuration file

## Default Configuration

The default settings include:

- **DuckDuckGo** search engine enabled
- **Privacy-focused** settings (no tracking, no logging)
- **JSON API** enabled for programmatic access
- **Image proxy** enabled for privacy
- **Rate limiting** disabled (internal use)

## Accessing SearXNG

Once the services are running:

```bash
# Web UI
http://localhost:8080

# JSON API example
curl "http://localhost:8080/search?q=AI+security&format=json"
```

## Customization

### Enable Additional Search Engines

Edit `settings.yml` and uncomment the engines you want:

```yaml
engines:
  # Uncomment to enable Google
  - name: google
    engine: google
    shortcut: go
    disabled: false  # Change to false

  # Uncomment to enable Wikipedia
  - name: wikipedia
    engine: wikipedia
    shortcut: wp
    disabled: false
```

### Change Secret Key

For production deployments, change the secret key:

```yaml
server:
  secret_key: "your-random-string-here"
```

Generate a random key:
```bash
openssl rand -hex 32
```

### Configure Proxy (Corporate Firewall)

If behind a corporate firewall, uncomment and configure:

```yaml
outgoing:
  proxies:
    http: http://proxy.company.com:8080
    https: http://proxy.company.com:8080
```

## Using SearXNG in Workflows

SearXNG can be used as a search provider in N8N workflows or with MCP servers:

### N8N HTTP Request Node

```json
{
  "method": "GET",
  "url": "http://searxng:8080/search",
  "queryParameters": {
    "q": "{{ $json.query }}",
    "format": "json"
  }
}
```

### With LiteLLM MCP

SearXNG is configured as an MCP server in this toolkit, providing privacy-focused search without requiring commercial API keys (unlike Brave Search or Google Custom Search).

**MCP Server Configuration:**

The toolkit automatically configures the SearXNG MCP server in LiteLLM via `config/litellm/config.yaml`:

```yaml
mcp_servers:
  - name: searxng
    transport: stdio
    command: npx
    args:
      - "-y"
      - "mcp-searxng"
    env:
      SEARXNG_URL: "http://searxng:8080"
    allow_all_keys: true  # Virtual keys can access this MCP server
```

**Configuration Details:**

- `allow_all_keys: true` - Enables MCP server access for **virtual keys**, not just the master key
  - This means N8N workflows using a virtual key can invoke MCP tools
  - Provides better security than using the master key everywhere
  - Allows per-workflow access control via virtual keys

This allows AI models using LiteLLM to:
- Perform web searches through SearXNG
- Access search results programmatically
- Maintain privacy (no external API calls to commercial providers)
- Use any search engine configured in SearXNG
- **Work with virtual keys** (e.g., from N8N workflows)

**Usage in AI workflows:**

When AI models are configured to use tools/MCP, they can invoke the search function:
```
Tool: searxng_search
Query: "latest cybersecurity threats"
Results: [...]
```

## Documentation

- [SearXNG Official Docs](https://docs.searxng.org/)
- [Available Search Engines](https://docs.searxng.org/admin/engines/configured_engines.html)
- [Settings Reference](https://docs.searxng.org/admin/settings/index.html)

## Troubleshooting

### Container won't start

Check logs:
```bash
docker logs dc-masters-searxng
# or
podman logs dc-masters-searxng
```

### Search engines not working

1. Check internet connectivity from container
2. Verify DNS resolution
3. If behind firewall, configure proxy in `settings.yml`

### No results returned

- Ensure DuckDuckGo is not blocked by your network
- Try enabling additional search engines
- Check timeout settings in `settings.yml`
