# Lemonade Dynamic Model Access for OpenCode

Automatically loads the model list from one or more remote
[Lemonade](https://lemonade-server.ai) servers into
[OpenCode](https://opencode.ai), so models never need to be hard-coded in
`opencode.json`.

## How it works

- `opencode.json` declares one provider entry per Lemonade server (using the
  `@ai-sdk/openai-compatible` adapter) with the server's base URL and an
  empty `models` map.
- `lemonade-models.js` is an OpenCode plugin. Its `config` hook runs at
  OpenCode startup, fetches `GET <baseURL>/models` from every provider named
  `lemonade` or `lemonade-*`, and injects the downloaded models into the
  config — including context window size and tool-calling / reasoning /
  vision capabilities derived from the server's model labels.

Restart OpenCode to pick up models added to or removed from the server.

## Quick start

Install against a single Lemonade server (default port is 13305, so
`--host=hal9k` means `hal9k:13305`):

```console
$ ./setup.sh --host=hal9k:13305
Setting up Lemonade dynamic model access for OpenCode...
Checking http://hal9k:13305/api/v1 ... ok, 11 models
Installed plugin to /home/joe/.config/opencode/plugins/lemonade-models.js
Backed up existing config to /home/joe/.config/opencode/opencode.json.bak.20260731221150
Wrote /home/joe/.config/opencode/opencode.json

Setup complete!
```

Then verify OpenCode sees the models:

```console
$ opencode models | grep lemonade
lemonade/DeepSeek-Qwen3-8B-GGUF
lemonade/Devstral-Small-2507-GGUF
lemonade/Qwen3-Coder-30B-A3B-Instruct-GGUF
...
```

And run a prompt against one of them:

```console
$ opencode run --model lemonade/Qwen3-Coder-30B-A3B-Instruct-GGUF "Reply with exactly one word: pong"
pong
```

Inside the OpenCode TUI, pick a model with `/models` — they appear under the
provider name, e.g. **Lemonade (hal9k)**.

## Installation examples

```bash
# Default: localhost:13305
./setup.sh

# One remote server
./setup.sh --host=hal9k:13305

# Several servers at once: the first becomes provider "lemonade",
# the others "lemonade-<hostname>"
./setup.sh --host=hal9k:13305 --host=deepthought:13305

# With an API key (Lemonade does not require one by default)
./setup.sh --host=hal9k:13305 --api-key="sk-..."
export LEMONADE_API_KEY="sk-..."   # add to ~/.bashrc so OpenCode can see it
```

`--host` writes a fresh config containing exactly the listed hosts. The
script installs the plugin to `~/.config/opencode/plugins/` and backs up any
existing `~/.config/opencode/opencode.json` first.

The generated config looks like this — note the empty `models` map, which the
plugin fills in at every OpenCode startup:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "lemonade": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Lemonade (hal9k)",
      "options": {
        "baseURL": "http://hal9k:13305/api/v1",
        "apiKey": "{env:LEMONADE_API_KEY}"
      },
      "models": {}
    }
  },
  "permission": {
    "read": "allow",
    "edit": "ask",
    "bash": "ask"
  }
}
```

## Adding and removing servers

`--add-host` and `--delete-host` edit the existing config in place — other
providers and settings are left untouched. Both are repeatable, deletions are
applied before additions, and the previous config is backed up before every
change.

```console
$ ./setup.sh --add-host=deepthought
Checking http://deepthought:13305/api/v1 ... ok, 4 models
...
Added provider "lemonade-deepthought" (deepthought:13305)

$ ./setup.sh --delete-host=deepthought
Deleted provider "lemonade-deepthought" (deepthought:13305)
```

Hosts are matched by `hostname:port` in the provider's `baseURL`, so the same
value used to add a host removes it — regardless of what the provider entry
ended up being named. Adding a host that is already configured is a no-op:

```console
$ ./setup.sh --add-host=hal9k
Provider "lemonade" already uses hal9k:13305; skipping
```

An unreachable host is added anyway (the plugin retries at every OpenCode
startup), so you can configure servers that are currently down:

```console
$ ./setup.sh --add-host=deepthought:13306
Checking http://deepthought:13306/api/v1 ... UNREACHABLE (continuing; the plugin will retry at OpenCode startup)
Added provider "lemonade-deepthought" (deepthought:13306)
```

Restart OpenCode after any change to refresh the model list.

## Troubleshooting

Check what the server itself reports — this is exactly what the plugin reads:

```console
$ curl -s http://hal9k:13305/api/v1/models | python3 -c \
    "import json,sys; [print(m['id']) for m in json.load(sys.stdin)['data']]"
DeepSeek-Qwen3-8B-GGUF
Devstral-Small-2507-GGUF
...
```

If models are missing from OpenCode but present in the curl output, run
OpenCode with debug logging and look for `lemonade-models:` errors printed by
the plugin (`opencode --print-logs`).

## Uninstall

```console
$ ./uninstall.sh
Removed Lemonade models plugin
Restored previous OpenCode configuration from opencode.json.bak.20260731221150
Uninstallation complete!
```

Removes the plugin and restores the most recent configuration backup made by
`setup.sh` (or removes the generated config if no backup exists).
