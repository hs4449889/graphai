"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.responseApiAgent = void 0;
const axios_1 = __importDefault(require("axios"));
const responseApiAgent = async ({ namedInputs, params, config }) => {
    var _a, _b, _c, _d;
    // Get parameters
    const { endpoint = "chat/completions", method = "POST", maxRetries = 3, debug = false } = params;
    const { requestData } = namedInputs;
    // Get configuration
    const apiKey = (config === null || config === void 0 ? void 0 : config.apiKey) || params.apiKey || process.env.RESPONSE_API_KEY;
    const baseURL = (config === null || config === void 0 ? void 0 : config.baseURL) || params.baseURL || process.env.RESPONSE_API_URL || "https://api.response.ai/v1";
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
    let lastError = null;
    for (let attempt = 0; attempt < maxRetries; attempt++) {
        try {
            const response = await (0, axios_1.default)({
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
            const text = ((_c = (_b = (_a = responseData.choices) === null || _a === void 0 ? void 0 : _a[0]) === null || _b === void 0 ? void 0 : _b.message) === null || _c === void 0 ? void 0 : _c.content) || responseData.text || "";
            // Extract research URLs from the response
            // This assumes the Response API returns research URLs in a specific format
            // Adjust this based on the actual Response API response format
            const research_urls = responseData.research_urls ||
                ((_d = responseData.metadata) === null || _d === void 0 ? void 0 : _d.research_urls) ||
                [];
            return {
                text,
                research_urls,
                metadata: {
                    source: "Response API",
                    timestamp: new Date().toISOString()
                }
            };
        }
        catch (error) {
            lastError = error;
            // Wait before retrying
            await new Promise(resolve => setTimeout(resolve, 1000 * (attempt + 1)));
        }
    }
    throw new Error(`Request failed after ${maxRetries} retries: ${lastError === null || lastError === void 0 ? void 0 : lastError.message}`);
};
exports.responseApiAgent = responseApiAgent;
const responseApiAgentInfo = {
    name: "responseApiAgent",
    agent: exports.responseApiAgent,
    mock: exports.responseApiAgent,
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
exports.default = responseApiAgentInfo;
