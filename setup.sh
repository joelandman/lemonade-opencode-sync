#!/bin/bash

# Lemonade OpenCode Dynamic Model Setup Script
#
# Installs the lemonade-models plugin and manages OpenCode provider entries
# for Lemonade servers. The plugin fetches each server's model list at
# OpenCode startup, so models are never hard-coded here.
#
# Two modes:
#   install (--host):                writes a fresh config with the given hosts
#   modify  (--add-host/--delete-host): edits the existing config in place,
#                                    leaving all other settings untouched

set -euo pipefail

CONFIG_DIR="${HOME}/.config/opencode"
CONFIG_FILE="${CONFIG_DIR}/opencode.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

HOSTS=()
ADD_HOSTS=()
DELETE_HOSTS=()
API_KEY="${LEMONADE_API_KEY:-}"

usage() {
    echo "Usage: ./setup.sh [--host=hostname[:port]] [--api-key=key]"
    echo "       ./setup.sh [--add-host=hostname[:port]] [--delete-host=hostname[:port]]"
    echo ""
    echo "  --host         Lemonade server (repeatable). Writes a fresh config"
    echo "                 containing exactly these hosts. Defaults to"
    echo "                 localhost:13305 if no other option is given."
    echo "  --add-host     Add a server to the existing config (repeatable),"
    echo "                 keeping current providers and settings."
    echo "  --delete-host  Remove a server and its models from the existing"
    echo "                 config (repeatable)."
    echo "  --api-key      Optional API key (Lemonade does not require one)."
    echo ""
    echo "  Default port is 13305 when omitted."
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --host=*)
            HOSTS+=("${1#*=}")
            shift
            ;;
        --add-host=*)
            ADD_HOSTS+=("${1#*=}")
            shift
            ;;
        --delete-host=*)
            DELETE_HOSTS+=("${1#*=}")
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

if [[ ${#HOSTS[@]} -gt 0 && ( ${#ADD_HOSTS[@]} -gt 0 || ${#DELETE_HOSTS[@]} -gt 0 ) ]]; then
    echo "Error: --host replaces the whole config and cannot be combined with --add-host/--delete-host."
    exit 1
fi

if [[ ${#ADD_HOSTS[@]} -gt 0 || ${#DELETE_HOSTS[@]} -gt 0 ]]; then
    MODE="modify"
else
    MODE="install"
    [[ ${#HOSTS[@]} -eq 0 ]] && HOSTS=("localhost:13305")
fi

echo "Setting up Lemonade dynamic model access for OpenCode..."

# Verify each new server is reachable and report its model count
for HOST in "${HOSTS[@]:-}" "${ADD_HOSTS[@]:-}"; do
    [[ -z "$HOST" ]] && continue
    [[ "$HOST" == *:* ]] || HOST="${HOST}:13305"
    BASE_URL="http://${HOST}/api/v1"
    echo -n "Checking ${BASE_URL} ... "
    COUNT=$(curl -sf --connect-timeout 5 "${BASE_URL}/models" \
        | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["data"]))' 2>/dev/null) \
        || { echo "UNREACHABLE (continuing; the plugin will retry at OpenCode startup)"; COUNT="?"; }
    [[ "$COUNT" != "?" ]] && echo "ok, ${COUNT} models"
done

# Install the plugin (OpenCode auto-loads *.js from this directory)
mkdir -p "${CONFIG_DIR}/plugins"
cp "${SCRIPT_DIR}/lemonade-models.js" "${CONFIG_DIR}/plugins/"
echo "Installed plugin to ${CONFIG_DIR}/plugins/lemonade-models.js"

# Back up any existing config before touching it
if [[ -f "$CONFIG_FILE" ]]; then
    BACKUP="${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP"
    echo "Backed up existing config to ${BACKUP}"
fi

# install mode: fresh config, first host becomes provider "lemonade", extras
#   "lemonade-<host>".
# modify mode: load the existing config (or a scaffold), delete providers whose
#   baseURL matches a --delete-host, then add entries for each --add-host.
PYARGS=("$MODE" "$CONFIG_FILE")
for H in "${HOSTS[@]}";        do PYARGS+=("host=$H");   done
for H in "${ADD_HOSTS[@]}";    do PYARGS+=("add=$H");    done
for H in "${DELETE_HOSTS[@]}"; do PYARGS+=("delete=$H"); done

python3 - "${PYARGS[@]}" <<'PYEOF'
import json, os, sys
from urllib.parse import urlparse

mode, config_path = sys.argv[1], sys.argv[2]
hosts, add_hosts, delete_hosts = [], [], []
buckets = {"host": hosts, "add": add_hosts, "delete": delete_hosts}
for arg in sys.argv[3:]:
    kind, _, value = arg.partition("=")
    buckets[kind].append(value)

def normalize(host):
    return host if ":" in host else host + ":13305"

def provider_entry(host):
    name = host.split(":")[0]
    return name, {
        "npm": "@ai-sdk/openai-compatible",
        "name": f"Lemonade ({name})",
        "options": {
            "baseURL": f"http://{host}/api/v1",
            "apiKey": "{env:LEMONADE_API_KEY}",
        },
        "models": {},
    }

def netloc(provider):
    return urlparse(provider.get("options", {}).get("baseURL", "")).netloc

scaffold = {
    "$schema": "https://opencode.ai/config.json",
    "provider": {},
    "permission": {"read": "allow", "edit": "ask", "bash": "ask"},
}

if mode == "install":
    config = scaffold
    for i, host in enumerate(normalize(h) for h in hosts):
        name, entry = provider_entry(host)
        key = "lemonade" if i == 0 else "lemonade-" + name.replace(".", "-")
        config["provider"][key] = entry
else:
    if os.path.exists(config_path):
        try:
            with open(config_path) as f:
                config = json.load(f)
        except json.JSONDecodeError as e:
            sys.exit(f"Error: {config_path} is not valid JSON ({e}); not modifying it.")
    else:
        config = scaffold
    providers = config.setdefault("provider", {})

    for host in (normalize(h) for h in delete_hosts):
        matches = [k for k, p in providers.items() if netloc(p) == host]
        if not matches:
            print(f"No provider found for {host}; nothing to delete")
        for key in matches:
            del providers[key]
            print(f"Deleted provider \"{key}\" ({host})")

    for host in (normalize(h) for h in add_hosts):
        existing = [k for k, p in providers.items() if netloc(p) == host]
        if existing:
            print(f"Provider \"{existing[0]}\" already uses {host}; skipping")
            continue
        name, entry = provider_entry(host)
        key = "lemonade" if "lemonade" not in providers else "lemonade-" + name.replace(".", "-")
        if key in providers:
            key += "-" + host.split(":")[1]
        providers[key] = entry
        print(f"Added provider \"{key}\" ({host})")

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PYEOF
echo "Wrote ${CONFIG_FILE}"

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
