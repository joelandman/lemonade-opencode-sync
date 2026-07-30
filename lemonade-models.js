// Lemonade Models Plugin
// This plugin dynamically configures OpenCode with Lemonade's available models
// without hardcoding each model in the configuration file

export const LemonadeModelsPlugin = async ({ project, client, $, directory, worktree }) => {
  // Store the list of available models
  let availableModels = [];
  
  // Function to fetch models from Lemonade API
  const fetchLemonadeModels = async (host = null) => {
    try {
      // In a real implementation, this would call Lemonade's API
      // For demonstration, using mock data
      const mockModels = [
        {
          id: "lemonade/gpt-4",
          name: "GPT-4",
          provider: "lemonade",
          enabled: true,
          description: "OpenAI GPT-4 model"
        },
        {
          id: "lemonade/claude-3",
          name: "Claude 3",
          provider: "lemonade",
          enabled: true,
          description: "Anthropic Claude 3 model"
        },
        {
          id: "lemonade/mixtral-8x7b",
          name: "Mixtral 8x7B",
          provider: "lemonade",
          enabled: true,
          description: "Mistral Mixtral 8x7B model"
        },
        {
          id: "lemonade/gemini-pro",
          name: "Gemini Pro",
          provider: "lemonade",
          enabled: true,
          description: "Google Gemini Pro model"
        }
      ];
      
      // In a real implementation, you would replace this with:
      // const baseUrl = host ? `http://${host}` : 'https://api.lemonade.ai/v1';
      // const response = await fetch(`${baseUrl}/models`, {
      //   headers: {
      //     'Authorization': `Bearer ${process.env.LEMONADE_API_KEY}`
      //   }
      // });
      // const models = await response.json();
      
      return mockModels;
    } catch (error) {
      console.error('Failed to fetch Lemonade models:', error);
      return [];
    }
  };
  
  // Function to refresh model list
  const refreshModels = async (host = null) => {
    try {
      const models = await fetchLemonadeModels(host);
      availableModels = models;
      return models;
    } catch (error) {
      console.error('Failed to refresh models:', error);
      return availableModels;
    }
  };
  
  // Initialize the plugin
  await refreshModels();
  
  return {
    // Tool to refresh model list
    "lemonade.refresh-models": {
      description: "Refresh available Lemonade models from the API",
      async execute(args, context) {
        try {
          let host = null;
          if (args && args.host) {
            host = args.host;
          }
          const models = await refreshModels(host);
          return `Model list refreshed. Found ${models.length} models.`;
        } catch (error) {
          return `Failed to refresh models: ${error.message}`;
        }
      }
    },
    
    // Tool to get available models
    "lemonade.list-models": {
      description: "List all available Lemonade models",
      async execute(args, context) {
        try {
          const models = availableModels;
          if (models.length === 0) {
            return "No models available. Please refresh the model list.";
          }
          
          let response = "Available Lemonade models:\n";
          for (const model of models) {
            response += `- ${model.name} (${model.id})\n`;
          }
          return response;
        } catch (error) {
          return `Failed to list models: ${error.message}`;
        }
      }
    },
    
    // Tool to get model information
    "lemonade.model-info": {
      description: "Get information about a specific Lemonade model",
      args: {
        modelId: {
          type: "string",
          description: "The model ID to get information about"
        }
      },
      async execute(args, context) {
        try {
          const model = availableModels.find(m => m.id === args.modelId);
          if (!model) {
            return `Model ${args.modelId} not found.`;
          }
          
          return `Model: ${model.name}\nID: ${model.id}\nProvider: ${model.provider}\nDescription: ${model.description}`;
        } catch (error) {
          return `Failed to get model info: ${error.message}`;
        }
      }
    }
  };
};