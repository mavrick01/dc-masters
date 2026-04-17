FROM node:20-alpine

WORKDIR /app

# Install dependencies
RUN npm install -g express body-parser

# Copy server implementation
COPY server.js package.json ./

# Install project dependencies
RUN npm install

# Create non-root user
RUN addgroup -S mcpuser && adduser -S mcpuser -G mcpuser
RUN chown -R mcpuser:mcpuser /app

# Switch to non-root user
USER mcpuser

# Expose HTTP port
EXPOSE 8001

# Start server
CMD ["node", "server.js"]
