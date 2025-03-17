import { AgentFunction, AgentFunctionInfo } from "graphai";
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
export declare const responseApiAgent: AgentFunction<ResponseAPIParams, ResponseAPIResult, {
    requestData: any;
}, ResponseAPIConfig>;
declare const responseApiAgentInfo: AgentFunctionInfo;
export default responseApiAgentInfo;
