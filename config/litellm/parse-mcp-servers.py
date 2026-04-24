#!/usr/bin/env python3
"""
Parse MCP servers from YAML config and output as JSON for shell scripts.
Performs environment variable substitution.
"""

import sys
import yaml
import json
import os
import re

def substitute_env_vars(text):
    """Replace ${VAR_NAME} or ${VAR_NAME:-default} with environment variable values."""
    if not isinstance(text, str):
        return text

    def replacer(match):
        var_expr = match.group(1)
        # Handle ${VAR:-default} syntax
        if ':-' in var_expr:
            var_name, default = var_expr.split(':-', 1)
            return os.environ.get(var_name.strip(), default.strip())
        else:
            var_name = var_expr
            return os.environ.get(var_name, match.group(0))

    return re.sub(r'\$\{([^}]+)\}', replacer, text)

def process_value(value):
    """Recursively process values to substitute environment variables."""
    if isinstance(value, str):
        return substitute_env_vars(value)
    elif isinstance(value, dict):
        return {k: process_value(v) for k, v in value.items()}
    elif isinstance(value, list):
        return [process_value(item) for item in value]
    else:
        return value

def main():
    if len(sys.argv) != 2:
        print("Usage: parse-mcp-servers.py <config.yaml>", file=sys.stderr)
        sys.exit(1)

    config_file = sys.argv[1]

    try:
        with open(config_file, 'r') as f:
            config = yaml.safe_load(f)

        servers = config.get('mcp_servers', [])

        if not servers:
            print("Warning: No MCP servers found in configuration", file=sys.stderr)
            servers = []

        # Process each server to substitute environment variables
        processed_servers = []
        for server in servers:
            processed_server = process_value(server)

            # Skip servers with missing required env vars (shown as ${VAR})
            skip = False
            if 'env' in processed_server:
                # Remove empty env vars
                processed_server['env'] = {k: v for k, v in processed_server['env'].items() if v}

                for key, value in list(processed_server['env'].items()):
                    if isinstance(value, str) and value.startswith('${') and value.endswith('}'):
                        print(f"Warning: Skipping {processed_server.get('name', 'unknown')} - missing required env var {key}", file=sys.stderr)
                        skip = True
                        break

            if not skip:
                processed_servers.append(processed_server)

        # Output as JSON
        print(json.dumps(processed_servers, indent=2))

    except FileNotFoundError:
        print(f"Error: Config file not found: {config_file}", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"Error parsing YAML: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
