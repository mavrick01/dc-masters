FROM node:20-alpine

WORKDIR /app

# Install system dependencies (wget for healthcheck, bash for entrypoint, ca-certificates, su-exec for user switching)
RUN apk add --no-cache wget bash ca-certificates su-exec

# Install dependencies
RUN npm install -g express body-parser

# Copy server implementation and entrypoint (from build context root)
COPY mcp-servers/filesystem/server.js mcp-servers/filesystem/package.json ./
COPY mcp-servers/filesystem/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Install project dependencies
RUN npm install

# Create non-root user
RUN addgroup -S mcpuser && adduser -S mcpuser -G mcpuser
RUN chown -R mcpuser:mcpuser /app

# Expose HTTP port
EXPOSE 8000

# Set environment variable for Node.js CA certificates
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# Use entrypoint to handle certificate setup, then switch to non-root user
ENTRYPOINT ["/entrypoint.sh"]

# Start server
CMD ["node", "server.js"]
