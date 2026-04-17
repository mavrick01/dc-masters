const express = require('express');
const bodyParser = require('body-parser');
const fs = require('fs').promises;
const path = require('path');

const app = express();
const PORT = process.env.MCP_PORT || 8000;
const BASE_DIR = '/projects';

app.use(bodyParser.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'mcp-filesystem' });
});

// MCP endpoint
app.post('/mcp', async (req, res) => {
  const { jsonrpc, method, params, id } = req.body;

  if (jsonrpc !== '2.0') {
    return res.status(400).json({
      jsonrpc: '2.0',
      error: { code: -32600, message: 'Invalid Request' },
      id: id || null
    });
  }

  try {
    let result;

    switch (method) {
      case 'tools/list':
        result = {
          tools: [
            {
              name: 'read_file',
              description: 'Read contents of a file',
              inputSchema: {
                type: 'object',
                properties: {
                  path: { type: 'string', description: 'File path relative to /projects' }
                },
                required: ['path']
              }
            },
            {
              name: 'write_file',
              description: 'Write content to a file',
              inputSchema: {
                type: 'object',
                properties: {
                  path: { type: 'string', description: 'File path relative to /projects' },
                  content: { type: 'string', description: 'Content to write' }
                },
                required: ['path', 'content']
              }
            },
            {
              name: 'list_directory',
              description: 'List contents of a directory',
              inputSchema: {
                type: 'object',
                properties: {
                  path: { type: 'string', description: 'Directory path relative to /projects', default: '/' }
                }
              }
            }
          ]
        };
        break;

      case 'tools/call':
        result = await handleToolCall(params);
        break;

      default:
        return res.status(400).json({
          jsonrpc: '2.0',
          error: { code: -32601, message: 'Method not found' },
          id
        });
    }

    res.json({ jsonrpc: '2.0', result, id });
  } catch (error) {
    console.error('Error handling request:', error);
    res.status(500).json({
      jsonrpc: '2.0',
      error: { code: -32603, message: error.message },
      id
    });
  }
});

async function handleToolCall(params) {
  const { name, arguments: args } = params;

  // Security: validate and sanitize path
  const sanitizePath = (userPath) => {
    const normalizedPath = path.normalize(userPath || '/').replace(/^(\.\.(\/|\\|$))+/, '');
    return path.join(BASE_DIR, normalizedPath);
  };

  switch (name) {
    case 'read_file': {
      const filePath = sanitizePath(args.path);
      const content = await fs.readFile(filePath, 'utf-8');
      return { content, path: args.path };
    }

    case 'write_file': {
      const filePath = sanitizePath(args.path);
      await fs.writeFile(filePath, args.content, 'utf-8');
      return { success: true, path: args.path };
    }

    case 'list_directory': {
      const dirPath = sanitizePath(args.path || '/');
      const entries = await fs.readdir(dirPath, { withFileTypes: true });
      return {
        path: args.path || '/',
        entries: entries.map(entry => ({
          name: entry.name,
          type: entry.isDirectory() ? 'directory' : 'file'
        }))
      };
    }

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

app.listen(PORT, '0.0.0.0', () => {
  console.log(`MCP Filesystem Server listening on port ${PORT}`);
  console.log(`Base directory: ${BASE_DIR}`);
});
