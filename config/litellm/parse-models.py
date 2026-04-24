#!/usr/bin/env python3
"""
Parse LiteLLM config.yaml and output model configurations as JSON
for configure-toolkit.sh to add via API
"""

import yaml
import json
import sys
import os
import re

def expand_env_var(value):
    """Expand environment variable references like os.environ/VAR_NAME"""
    if isinstance(value, str) and value.startswith("os.environ/"):
        var_name = value.replace("os.environ/", "")
        return os.environ.get(var_name, "")
    return value

def process_litellm_params(params):
    """Process litellm_params and expand environment variables"""
    result = {}
    for key, value in params.items():
        expanded = expand_env_var(value)
        # Only include if env var is set (not empty)
        if expanded or not isinstance(value, str) or not value.startswith("os.environ/"):
            result[key] = expanded if expanded else value
    return result

def main():
    config_file = sys.argv[1] if len(sys.argv) > 1 else "config/litellm/config.yaml"

    try:
        with open(config_file, 'r') as f:
            config = yaml.safe_load(f)

        if 'model_list' not in config:
            print("[]", file=sys.stderr)
            sys.exit(1)

        models = []
        for model in config['model_list']:
            model_name = model.get('model_name')
            litellm_params = model.get('litellm_params', {})

            # Process params and expand env vars
            processed_params = process_litellm_params(litellm_params)

            # Check if required credentials are available
            # Skip models with missing required credentials
            skip = False
            for key, value in processed_params.items():
                if key in ['api_key', 'api_base', 'aws_access_key_id', 'aws_secret_access_key']:
                    if not value:
                        skip = True
                        break

            if skip:
                continue

            model_config = {
                "model_name": model_name,
                "litellm_params": processed_params
            }

            models.append(model_config)

        print(json.dumps(models, indent=2))

    except Exception as e:
        print(f"Error parsing config: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
