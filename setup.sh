#!/bin/bash

# Lemonade OpenCode Dynamic Model Setup Script

echo "Setting up Lemonade dynamic model access for OpenCode..."

# Parse command line arguments
HOSTS=""
API_KEY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --host=*)
            HOSTS="${HOSTS} ${1#*=}"
            shift
            ;;
        --api-key=*)
            API_KEY="${1#*=}"
            shift
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

# Check if Lemonade API key is set
if [ -z "$API_KEY" ] && [ -z "$LEMONADE_API_KEY" ]; then
    echo "Please provide your Lemonade API key:"
    echo "Option 1: Set environment variable"
    echo "  export LEMONADE_API_KEY=\"your-api-key-here\""
    echo ""
    echo "Option 2: Use --api-key argument"
    echo "  ./setup.sh --api-key=\"your-api-key-here\" [--host=hostname:port] [--host=hostname2:port2]"
    echo ""
    echo "You can add this to your ~/.bashrc or ~/.zshrc file to make it permanent."
    exit 1
fi

# Set API key
if [ -n "$API_KEY" ]; then
    export LEMONADE_API_KEY="$API_KEY"
fi

# Create plugins directory if it doesn't exist
mkdir -p ~/.config/opencode/plugins

# Copy the plugin file
cp lemonade-models.js ~/.config/opencode/plugins/

# Create configuration
echo "Creating OpenCode configuration..."
mkdir -p ~/.config/opencode
cat > ~/.config/opencode/opencode.json << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "plugin": ["lemonade-models"],
  "provider": {
    "lemonade": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Lemonade Models",
      "options": {
        "baseURL": "https://api.lemonade.ai/v1",
        "apiKey": "{env:LEMONADE_API_KEY}"
      }
    }
  },
  "permission": {
    "read": "allow",
    "edit": "ask",
    "bash": "ask"
  }
}
EOF

echo "Setup complete!"
echo ""
echo "To use the Lemonade models plugin:"
echo "1. Ensure your LEMONADE_API_KEY is set in your environment"
echo "2. Restart OpenCode"
echo "3. Use the following commands:"
echo "   - /lemonade.refresh-models (refresh model list)"
echo "   - /lemonade.list-models (list available models)"
echo "   - /lemonade.model-info --modelId [model-id] (get model info)"
echo ""
echo "Configuration details:"
if [ -n "$HOSTS" ]; then
    echo "Connected to hosts:"
    IFS=' ' read -ra HOST_ARRAY <<< "$HOSTS"
    for HOST in "${HOST_ARRAY[@]}"; do
        echo "  - $HOST"
    done
fi
echo "API Key: $(echo $LEMONADE_API_KEY | sed 's/./X/g' | sed 's/XXX.*/XXXX/')..."