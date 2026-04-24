const express = require('express');
const bodyParser = require('body-parser');
const fetch = require('node-fetch');
const cheerio = require('cheerio');

const app = express();
const PORT = process.env.MCP_PORT || 8001;

app.use(bodyParser.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'mcp-duckduckgo' });
});

// MCP SSE endpoint (for streaming/session)
app.get('/mcp', (req, res) => {
  // Set SSE headers
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Access-Control-Allow-Origin': '*'
  });

  // Send initial connection event
  res.write('event: open\n');
  res.write('data: {"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n\n');

  // Keep connection alive with heartbeat
  const heartbeat = setInterval(() => {
    res.write(': heartbeat\n\n');
  }, 30000);

  req.on('close', () => {
    clearInterval(heartbeat);
  });
});

// MCP POST endpoint (for request-response)
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
              name: 'search',
              description: 'Search the web using DuckDuckGo',
              inputSchema: {
                type: 'object',
                properties: {
                  query: { type: 'string', description: 'Search query' },
                  max_results: { type: 'number', description: 'Maximum number of results', default: 5 }
                },
                required: ['query']
              }
            },
            {
              name: 'fetch_url',
              description: 'Fetch and extract content from a URL',
              inputSchema: {
                type: 'object',
                properties: {
                  url: { type: 'string', description: 'URL to fetch' }
                },
                required: ['url']
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

  switch (name) {
    case 'search':
      return await performSearch(args.query, args.max_results || 5);

    case 'fetch_url':
      return await fetchUrl(args.url);

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

async function performSearch(query, maxResults) {
  try {
    // Use DuckDuckGo Instant Answer API (HTML scraping as fallback)
    const searchUrl = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`;
    const response = await fetch(searchUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; MCP-DuckDuckGo/1.0)'
      },
      timeout: 10000
    });

    if (!response.ok) {
      throw new Error(`Search failed: ${response.statusText}`);
    }

    const html = await response.text();
    const $ = cheerio.load(html);

    const results = [];
    $('.result').slice(0, maxResults).each((i, elem) => {
      const title = $(elem).find('.result__title').text().trim();
      const snippet = $(elem).find('.result__snippet').text().trim();
      const url = $(elem).find('.result__url').attr('href');

      if (title && url) {
        results.push({ title, snippet, url });
      }
    });

    return {
      query,
      results,
      count: results.length
    };
  } catch (error) {
    console.error('Search error:', error);
    throw new Error(`Search failed: ${error.message}`);
  }
}

async function fetchUrl(url) {
  try {
    // Validate URL
    new URL(url);

    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; MCP-DuckDuckGo/1.0)'
      },
      timeout: 10000
    });

    if (!response.ok) {
      throw new Error(`Fetch failed: ${response.statusText}`);
    }

    const contentType = response.headers.get('content-type');

    if (contentType && contentType.includes('text/html')) {
      const html = await response.text();
      const $ = cheerio.load(html);

      // Remove script and style elements
      $('script, style, nav, footer, aside').remove();

      // Extract main content
      const title = $('title').text().trim();
      const content = $('body').text().trim().replace(/\s+/g, ' ');

      return {
        url,
        title,
        content: content.substring(0, 5000), // Limit to 5000 chars
        contentType: 'text/html'
      };
    } else {
      const text = await response.text();
      return {
        url,
        content: text.substring(0, 5000),
        contentType: contentType || 'text/plain'
      };
    }
  } catch (error) {
    console.error('Fetch error:', error);
    throw new Error(`Fetch failed: ${error.message}`);
  }
}

app.listen(PORT, '0.0.0.0', () => {
  console.log(`MCP DuckDuckGo Server listening on port ${PORT}`);
});
