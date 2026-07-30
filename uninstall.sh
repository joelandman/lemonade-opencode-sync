#!/bin/bash

# Lemonade OpenCode Dynamic Model Uninstall Script

echo "Uninstalling Lemonade dynamic model access for OpenCode..."

# Remove the plugin file
if [ -f ~/.config/opencode/plugins/lemonade-models.js ]; then
    rm ~/.config/opencode/plugins/lemonade-models.js
    echo "Removed Lemonade models plugin"
else
    echo "Lemonade models plugin not found"
fi

# Remove the configuration file
if [ -f ~/.config/opencode/opencode.json ]; then
    rm ~/.config/opencode/opencode.json
    echo "Removed OpenCode configuration"
else
    echo "OpenCode configuration not found"
fi

# Remove plugins directory if it's empty
if [ -d ~/.config/opencode/plugins ] && [ -z "$(ls -A ~/.config/opencode/plugins)" ]; then
    rmdir ~/.config/opencode/plugins 2>/dev/null || true
    echo "Removed empty plugins directory"
fi

# Remove the configuration directory if it's empty
if [ -d ~/.config/opencode ] && [ -z "$(ls -A ~/.config/opencode)" ]; then
    rmdir ~/.config/opencode 2>/dev/null || true
    echo "Removed empty config directory"
fi

echo "Uninstallation complete!"
echo ""
echo "Note: This script only removes files created by the setup script."
echo "It does not modify any other OpenCode configuration or settings."