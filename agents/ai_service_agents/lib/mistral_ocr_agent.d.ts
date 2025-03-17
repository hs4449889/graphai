import { AgentFunction, AgentFunctionInfo } from "graphai";
type MistralOCRInputs = {
    outputFormat?: string;
    saveImages?: boolean;
    imagesDir?: string;
    markdownDir?: string;
};
type MistralOCRConfig = {
    apiKey?: string;
};
type MistralOCRParams = MistralOCRInputs & MistralOCRConfig;
type MistralOCRResult = {
    text_content: string;
    saved_images?: Record<number, Record<string, string>>;
    markdown_files?: Record<string, string>;
    ocr_result?: any;
};
export declare const mistralOcrAgent: AgentFunction<MistralOCRParams, MistralOCRResult, {
    pdfPath: string;
    pdfContentBase64?: string;
}, MistralOCRConfig>;
declare const mistralOcrAgentInfo: AgentFunctionInfo;
export default mistralOcrAgentInfo;
