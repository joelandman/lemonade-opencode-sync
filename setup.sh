#!/bin/bash

# Lemonade OpenCode Dynamic Model Setup Script
#
# Installs the lemonade-models plugin and writes an OpenCode config with one
# provider entry per Lemonade server. The plugin fetches each server's model
# list at OpenCode startup, so models are never hard-coded here.

set -euo pipefail

CONFIG_DIR="${HOME}/.config/opencode"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

HOSTS=()
API_KEY="${LEMONADE_API_KEY:-}"

usage() {
    echo "Usage: ./setup.sh [--host=hostname[:port]] [--host=...] [--api-key=key]"
    echo ""
    echo "  --host     Lemonade server (repeatable). Default port 13305."
    echo "             Defaults to localhost:13305 if not given."
    echo "  --api-key  Optional API key (Lemonade does not require one by default)."
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --host=*)
            HOSTS+=("${1#*=}")
            shift
            ;;
        --api-key=*)
            API_KEY="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

[[ ${#HOSTS[@]} -eq 0 ]] && HOSTS=("localhost:13305")

echo "Setting up Lemonade dynamic model access for OpenCode..."

# Verify each server is reachable and report its model count
declare -A BASE_URLS
for HOST in "${HOSTS[@]}"; do
    [[ "$HOST" == *:* ]] || HOST="${HOST}:13305"
    BASE_URL="http://${HOST}/api/v1"
    echo -n "Checking ${BASE_URL} ... "
    COUNT=$(curl -sf --connect-timeout 5 "${BASE_URL}/models" \
        | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["data"]))' 2>/dev/null) \
        || { echo "UNREACHABLE (continuing; the plugin will retry at OpenCode startup)"; COUNT="?"; }
    [[ "$COUNT" != "?" ]] && echo "ok, ${COUNT} models"
    BASE_URLS["$HOST"]="$BASE_URL"
done

# Install the plugin (OpenCode auto-loads *.js from this directory)
mkdir -p "${CONFIG_DIR}/plugins"
cp "${SCRIPT_DIR}/lemonade-models.js" "${CONFIG_DIR}/plugins/"
echo "Installed plugin to ${CONFIG_DIR}/plugins/lemonade-models.js"

# Back up any existing config before overwriting
if [[ -f "${CONFIG_DIR}/opencode.json" ]]; then
    BACKUP="${CONFIG_DIR}/opencode.json.bak.$(date +%Y%m%d%H%M%S)"
    cp "${CONFIG_DIR}/opencode.json" "$BACKUP"
    echo "Backed up existing config to ${BACKUP}"
fi

# Write the config: first host becomes provider "lemonade", extras "lemonade-<host>"
python3 - "${CONFIG_DIR}/opencode.json" "${HOSTS[@]}" <<'PYEOF'
import json, sys

config_path, hosts = sys.argv[1], sys.argv[2:]
providers = {}
for i, host in enumerate(hosts):
    if ":" not in host:
        host += ":13305"
    name = host.split(":")[0]
    key = "lemonade" if i == 0 else "lemonade-" + name.replace(".", "-")
    providers[key] = {
        "npm": "@ai-sdk/openai-compatible",
        "name": f"Lemonade ({name})",
        "options": {
            "baseURL": f"http://{host}/api/v1",
            "apiKey": "{env:LEMONADE_API_KEY}",
        },
        "models": {},
    }

config = {
    "$schema": "https://opencode.ai/config.json",
    "provider": providers,
    "permission": {
        "read": "allow",
        "edit": "ask",
        "bash": "ask",
    },
}
with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PYEOF
echo "Wrote ${CONFIG_DIR}/opencode.json"

echo ""
echo "Setup complete!"
echo ""
echo "Notes:"
echo "  - Restart OpenCode; the plugin fetches the model list at startup."
echo "  - Select a model inside OpenCode with /models, or verify from the"
echo "    shell with: opencode models | grep lemonade"
if [[ -n "$API_KEY" ]]; then
    echo "  - Export LEMONADE_API_KEY in your shell profile so OpenCode can see it:"
    echo "      export LEMONADE_API_KEY=\"...\""
else
    echo "  - No API key configured (Lemonade does not require one by default)."
fi
