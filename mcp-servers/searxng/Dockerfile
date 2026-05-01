# MCP SearXNG Server - HTTP Transport
FROM node:22-alpine

WORKDIR /app

# Install ca-certificates package and bash for entrypoint script
RUN apk add --no-cache ca-certificates bash wget

# Set default environment variables
ENV SEARXNG_URL=http://searxng:8080
ENV MCP_HTTP_PORT=8081
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# Copy entrypoint script (from build context root)
COPY mcp-servers/searxng/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose HTTP port
EXPOSE 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8081/health || exit 1

# Use entrypoint to handle certificate setup
ENTRYPOINT ["/entrypoint.sh"]

# Run the MCP server via npx (downloads on first run)
CMD ["npx", "-y", "mcp-searxng"]
