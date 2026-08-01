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

## Installation

```bash
./setup.sh --host=hal9k:13305
```

- `--host=hostname[:port]` is repeatable for multiple servers (default port
  13305, default host `localhost:13305`). The first host becomes provider
  `lemonade`; additional hosts become `lemonade-<hostname>`.
- `--api-key=...` is optional; Lemonade does not require one by default. If
  used, also `export LEMONADE_API_KEY=...` in your shell profile so OpenCode
  can see it.

The script installs the plugin to `~/.config/opencode/plugins/`, backs up any
existing `~/.config/opencode/opencode.json`, and writes a new one.

## Usage

Start OpenCode and pick a model with `/models` — the Lemonade models appear
under the provider name (e.g. "Lemonade (hal9k)"). To verify from the shell:

```bash
opencode models | grep -i lemonade
```

## Uninstall

```bash
./uninstall.sh
```

Removes the plugin and restores the most recent configuration backup made by
`setup.sh` (or removes the generated config if no backup exists).
