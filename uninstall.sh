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

# Remove the configuration file, restoring the most recent pre-setup backup if one exists
if [ -f ~/.config/opencode/opencode.json ]; then
    BACKUP=$(ls -1t ~/.config/opencode/opencode.json.bak.* 2>/dev/null | head -1)
    if [ -n "$BACKUP" ]; then
        mv "$BACKUP" ~/.config/opencode/opencode.json
        echo "Restored previous OpenCode configuration from $(basename "$BACKUP")"
    else
        rm ~/.config/opencode/opencode.json
        echo "Removed OpenCode configuration"
    fi
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