import { AgentFunction, AgentFunctionInfo } from "graphai";
type MistralOCRInputs = {
    pdfPath?: string;
    pdfContentBase64?: string;
};
type MistralOCRParams = {
    outputFormat?: "full" | "text" | "markdown" | "images";
    saveImages?: boolean;
    imagesDir?: string;
    markdownDir?: string;
    apiKey?: string;
    debug?: boolean;
};
type MistralOCRResult = {
    text_content: string;
    markdown_content?: string;
    images?: Record<string, string>;
    full_result?: any;
    metadata?: {
        source: string;
        timestamp: string;
        pages: number;
    };
};
export declare const mistralOcrAgent: AgentFunction<MistralOCRParams, MistralOCRResult, MistralOCRInputs>;
declare const mistralOcrAgentInfo: AgentFunctionInfo;
export default mistralOcrAgentInfo;
