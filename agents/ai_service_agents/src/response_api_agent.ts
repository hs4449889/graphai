import { AgentFunction, AgentFunctionInfo } from "graphai";
import axios from "axios";

type ResponseAPIInputs = {
  endpoint?: string;
  method?: string;
  maxRetries?: number;
  debug?: boolean;
};

type ResponseAPIConfig = {
  apiKey?: string;
  baseURL?: string;
};

type ResponseAPIParams = ResponseAPIInputs & ResponseAPIConfig;

type ResponseAPIResult = {
  text: string;
  research_urls: string[];
  metadata?: {
    source: string;
    timestamp: string;
  };
};

export const responseApiAgent: AgentFunction<
  ResponseAPIParams,
  ResponseAPIResult,
  { requestData: any },
  ResponseAPIConfig
> = async ({ namedInputs, params, config }) => {
  // Get parameters
  const { endpoint = "chat/completions", method = "POST", maxRetries = 3, debug = false } = params;
  const { requestData } = namedInputs;
  
  // Get configuration
  const apiKey = config?.apiKey || params.apiKey || process.env.RESPONSE_API_KEY;
  const baseURL = config?.baseURL || params.baseURL || process.env.RESPONSE_API_URL || "https://api.response.ai/v1";
  
  if (!apiKey) {
    throw new Error("Response API key not provided and RESPONSE_API_KEY environment variable not set");
  }
  
  if (!requestData) {
    throw new Error("Missing required inputs: requestData");
  }
  
  // Debug mode
  if (debug) {
    return {
      text: "Debug mode - no API call made",
      research_urls: ["https://example.com/debug"],
      metadata: {
        source: "Debug Mode",
        timestamp: new Date().toISOString()
      }
    };
  }
  
  // Make API request with retries
  let lastError: Error | null = null;
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const response = await axios({
        method: method,
        url: `${baseURL}/${endpoint}`,
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`
        },
        data: requestData
      });
      
      // Extract text and research URLs from response
      const responseData = response.data;
      const text = responseData.choices?.[0]?.message?.content || responseData.text || "";
      
      // Extract research URLs from the response
      // This assumes the Response API returns research URLs in a specific format
      // Adjust this based on the actual Response API response format
      const research_urls = responseData.research_urls || 
                          responseData.metadata?.research_urls || 
                          [];
      
      return {
        text,
        research_urls,
        metadata: {
          source: "Response API",
          timestamp: new Date().toISOString()
        }
      };
    } catch (error) {
      lastError = error as Error;
      // Wait before retrying
      await new Promise(resolve => setTimeout(resolve, 1000 * (attempt + 1)));
    }
  }
  
  throw new Error(`Request failed after ${maxRetries} retries: ${lastError?.message}`);
};

const responseApiAgentInfo: AgentFunctionInfo = {
  name: "responseApiAgent",
  agent: responseApiAgent,
  mock: responseApiAgent,
  inputs: {
    type: "object",
    properties: {
      requestData: {
        type: "object",
        description: "Request data to send to the Response API"
      }
    },
    required: ["requestData"]
  },
  output: {
    type: "object",
    properties: {
      text: {
        type: "string",
        description: "Generated text response"
      },
      research_urls: {
        type: "array",
        items: {
          type: "string"
        },
        description: "URLs to research sources"
      },
      metadata: {
        type: "object",
        properties: {
          source: {
            type: "string"
          },
          timestamp: {
            type: "string"
          }
        }
      }
    },
    required: ["text", "research_urls"]
  },
  params: {
    type: "object",
    properties: {
      endpoint: {
        type: "string",
        description: "API endpoint to call"
      },
      method: {
        type: "string",
        description: "HTTP method to use"
      },
      maxRetries: {
        type: "number",
        description: "Maximum number of retries"
      },
      debug: {
        type: "boolean",
        description: "Enable debug mode"
      },
      apiKey: {
        type: "string",
        description: "Response API key"
      },
      baseURL: {
        type: "string",
        description: "Response API base URL"
      }
    }
  },
  samples: [
    {
      inputs: {
        requestData: {
          model: "response-1",
          messages: [
            { role: "user", content: "Tell me about GraphAI" }
          ]
        }
      },
      params: {},
      result: {
        text: "GraphAI is an asynchronous dataflow execution engine for building AI agent workflows using declarative YAML/JSON graphs.",
        research_urls: [
          "https://github.com/receptron/graphai",
          "https://zenn.dev/singularity/articles/graphai-python-server"
        ],
        metadata: {
          source: "Response API",
          timestamp: "2023-07-01T12:34:56.789Z"
        }
      }
    }
  ],
  description: "Calls the Response API to generate text and research URLs",
  category: ["ai", "service"],
  author: "Receptron Team",
  repository: "https://github.com/receptron/graphai",
  license: "MIT",
  environmentVariables: ["RESPONSE_API_KEY", "RESPONSE_API_URL"],
  npms: ["axios"]
};

export default responseApiAgentInfo;
