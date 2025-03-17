"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const response_api_agent_1 = __importDefault(require("./response_api_agent"));
const mistral_ocr_agent_1 = __importDefault(require("./mistral_ocr_agent"));
// Log agent info
console.log('Response API Agent Info:', response_api_agent_1.default.name);
console.log('Mistral OCR Agent Info:', mistral_ocr_agent_1.default.name);
console.log('Test completed successfully!');
