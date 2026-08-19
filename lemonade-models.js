// Lemonade Models Plugin for OpenCode
//
// At startup, fetches the model list from each Lemonade server declared in
// opencode.json (any provider whose key is "lemonade" or starts with
// "lemonade-") and injects the models into that provider's config. Models
// therefore never need to be hard-coded; restart OpenCode to pick up changes.

const FETCH_TIMEOUT_MS = 5000

// Lemonade caps generation independently of context; keep a sane default so
// OpenCode doesn't request the full context window as output.
const MAX_OUTPUT_TOKENS = 32768

const resolveApiKey = (options) => {
  const key = options?.apiKey
  // "{env:VAR}" placeholders are normally substituted before plugins run, but
  // fall back to the environment if one survives unresolved.
  if (key && !key.startsWith("{env:")) return key
  return process.env.LEMONADE_API_KEY
}

const fetchModels = async (baseURL, apiKey) => {
  const headers = { Accept: "application/json" }
  if (apiKey) headers.Authorization = `Bearer ${apiKey}`
  const url = `${baseURL.replace(/\/+$/, "")}/models`
  const res = await fetch(url, { headers, signal: AbortSignal.timeout(FETCH_TIMEOUT_MS) })
  if (!res.ok) throw new Error(`GET ${url} returned HTTP ${res.status}`)
  const body = await res.json()
  if (!Array.isArray(body?.data)) throw new Error(`GET ${url} returned no model list`)
  return body.data
}

const toModelConfig = (model) => {
  const labels = model.labels ?? []
  const entry = {
    name: model.id,
    tool_call: labels.includes("tool-calling"),
    reasoning: labels.includes("reasoning"),
    attachment: labels.includes("vision"),
    temperature: true,
    cost: { input: 0, output: 0 },
  }

  const contextWindow =
    typeof model.recipe_options?.ctx_size === "number"
      ? model.recipe_options.ctx_size
      : model.max_context_window

  if (typeof contextWindow === "number") {
    entry.limit = {
      context: contextWindow,
      output: Math.min(contextWindow, MAX_OUTPUT_TOKENS),
    }
  }

  return entry
}

export const LemonadeModelsPlugin = async () => {
  return {
    config: async (config) => {
      for (const [providerID, provider] of Object.entries(config.provider ?? {})) {
        if (providerID !== "lemonade" && !providerID.startsWith("lemonade-")) continue
        const baseURL = provider.options?.baseURL
        if (!baseURL) continue

        try {
          const list = await fetchModels(baseURL, resolveApiKey(provider.options))
          const models = {}
          for (const model of list) {
            if (model.downloaded === false) continue
            models[model.id] = toModelConfig(model)
          }
          // Models declared explicitly in opencode.json win over fetched ones.
          provider.models = { ...models, ...(provider.models ?? {}) }
        } catch (error) {
          console.error(`lemonade-models: could not fetch models for provider "${providerID}" from ${baseURL}: ${error.message}`)
        }
      }
    },
  }
}
