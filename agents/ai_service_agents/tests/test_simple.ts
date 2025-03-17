import responseApiAgentInfo from '../src/response_api_agent';
import mistralOcrAgentInfo from '../src/mistral_ocr_agent';

// API keys from environment variables
const RESPONSE_API_KEY = process.env.RESPONSE_API_KEY;
const MISTRAL_API_KEY = process.env.MISTRAL_API_KEY;

console.log('Response API Agent Info:', responseApiAgentInfo.name);
console.log('Mistral OCR Agent Info:', mistralOcrAgentInfo.name);
console.log('Test completed successfully!');
