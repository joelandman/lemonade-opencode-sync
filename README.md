# Lemonade Dynamic Model Access for OpenCode

This plugin enables dynamic access to Lemonade's models in OpenCode without hard-coding each model in the configuration file.

## Features

- Dynamic model discovery from Lemonade's API
- Automatic model refresh capability
- Command-line interface for model management
- Integration with OpenCode's permission system

## Installation

1. Create the plugin directory:
   ```bash
   mkdir -p ~/.config/opencode/plugins
   ```

2. Copy the plugin file to the plugins directory:
   ```bash
   cp /path/to/lemonade-models.js ~/.config/opencode/plugins/
   ```

3. Set your Lemonade API key:
   ```bash
   export LEMONADE_API_KEY="your-api-key-here"
   ```

4. Configure OpenCode to use the plugin by adding to your opencode.json:
   ```json
   {
     "plugin": ["lemonade-models"]
   }
   ```

## Usage

### Refresh Models
To refresh the model list from Lemonade's API:
```
/lemonade.refresh-models
```

### List Available Models
To see all available models:
```
/lemonade.list-models
```

### Get Model Information
To get information about a specific model:
```
/lemonade.model-info --modelId lemonade/gpt-4
```

## Configuration

Set your Lemonade API key in an environment variable:
```bash
export LEMONADE_API_KEY="your-api-key-here"
```

## Security

This plugin respects OpenCode's permission system. By default, it requires approval for file operations and bash commands.