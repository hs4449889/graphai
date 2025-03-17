"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.mistralOcrAgent = void 0;
const axios_1 = __importDefault(require("axios"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const form_data_1 = __importDefault(require("form-data"));
const mistralOcrAgent = async ({ namedInputs, params }) => {
    // Get parameters
    const { outputFormat = "text", saveImages = false, imagesDir = "output/images", markdownDir = "output/markdown", debug = false } = params;
    // Get API key
    const apiKey = params.apiKey || process.env.MISTRAL_API_KEY;
    if (!apiKey && !debug) {
        throw new Error("Mistral API key not provided and MISTRAL_API_KEY environment variable not set");
    }
    // Get inputs
    const { pdfPath, pdfContentBase64 } = namedInputs;
    if (!pdfPath && !pdfContentBase64 && !debug) {
        throw new Error("Either pdfPath or pdfContentBase64 must be provided");
    }
    // Debug mode
    if (debug) {
        return {
            text_content: "This is a sample OCR text content for testing purposes.",
            markdown_content: "# Sample Document\n\nThis is a **sample** document for testing purposes.",
            images: { "image_1": "base64_encoded_image_data" },
            metadata: {
                source: "Debug Mode",
                timestamp: new Date().toISOString(),
                pages: 1
            }
        };
    }
    try {
        // Read PDF file
        let pdfContent;
        if (pdfPath) {
            pdfContent = fs.readFileSync(pdfPath);
        }
        else if (pdfContentBase64) {
            pdfContent = Buffer.from(pdfContentBase64, 'base64');
        }
        else {
            throw new Error("Either pdfPath or pdfContentBase64 must be provided");
        }
        // Create form data
        const formData = new form_data_1.default();
        formData.append('file', pdfContent, {
            filename: pdfPath ? path.basename(pdfPath) : 'document.pdf',
            contentType: 'application/pdf'
        });
        // Upload file
        const uploadResponse = await axios_1.default.post('https://api.mistral.ai/v1/files', formData, {
            headers: Object.assign(Object.assign({}, formData.getHeaders()), { 'Authorization': `Bearer ${apiKey}` })
        });
        const fileId = uploadResponse.data.id;
        // Get signed URL
        const signedUrlResponse = await axios_1.default.get(`https://api.mistral.ai/v1/files/${fileId}/signed_url`, {
            headers: {
                'Authorization': `Bearer ${apiKey}`
            }
        });
        const signedUrl = signedUrlResponse.data.url;
        // Process OCR
        const ocrResponse = await axios_1.default.post('https://api.mistral.ai/v1/ocr/process', {
            model: "mistral-ocr-latest",
            document: {
                type: "document_url",
                document_url: signedUrl
            },
            include_image_base64: saveImages
        }, {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${apiKey}`
            }
        });
        const ocrResult = ocrResponse.data;
        // Process result based on output format
        let result = {
            text_content: "",
            metadata: {
                source: "Mistral OCR",
                timestamp: new Date().toISOString(),
                pages: ocrResult.pages.length
            }
        };
        // Extract text content
        result.text_content = ocrResult.pages
            .map((page) => {
            const blocks = page.blocks || [];
            return blocks
                .filter((block) => block.type === "text")
                .map((block) => block.text)
                .join("\n");
        })
            .join("\n\n");
        // Extract markdown content if requested
        if (outputFormat === "markdown" || outputFormat === "full") {
            result.markdown_content = ocrResult.pages
                .map((page) => page.markdown || "")
                .join("\n\n");
            // Save markdown files if requested
            if (saveImages && markdownDir && result.markdown_content) {
                const dirPath = markdownDir;
                if (!fs.existsSync(dirPath)) {
                    fs.mkdirSync(dirPath, { recursive: true });
                }
                const markdownPath = path.join(dirPath, `document.md`);
                fs.writeFileSync(markdownPath, result.markdown_content);
            }
        }
        // Extract images if requested
        if ((outputFormat === "images" || outputFormat === "full") && saveImages) {
            result.images = {};
            // Create images directory if it doesn't exist
            if (imagesDir && !fs.existsSync(imagesDir)) {
                fs.mkdirSync(imagesDir, { recursive: true });
            }
            // Process images from each page
            ocrResult.pages.forEach((page, pageIndex) => {
                const images = page.images || [];
                images.forEach((img, imgIndex) => {
                    const imgId = img.id;
                    const imgBase64 = img.image_base64;
                    if (imgBase64 && !imgBase64.endsWith("...")) {
                        // Extract base64 data
                        let base64Data = imgBase64;
                        if (base64Data.startsWith("data:")) {
                            base64Data = base64Data.split(",")[1];
                        }
                        // Save image if requested
                        if (saveImages && imagesDir) {
                            const imgPath = path.join(imagesDir, `page${pageIndex + 1}_image${imgIndex + 1}.png`);
                            fs.writeFileSync(imgPath, Buffer.from(base64Data, 'base64'));
                        }
                        // Add to result
                        if (result.images) {
                            result.images[imgId] = imgBase64;
                        }
                    }
                });
            });
        }
        // Include full result if requested
        if (outputFormat === "full") {
            result.full_result = ocrResult;
        }
        return result;
    }
    catch (error) {
        throw new Error(`Mistral OCR processing failed: ${error.message}`);
    }
};
exports.mistralOcrAgent = mistralOcrAgent;
const mistralOcrAgentInfo = {
    name: "mistralOcrAgent",
    agent: exports.mistralOcrAgent,
    mock: exports.mistralOcrAgent,
    inputs: {
        type: "object",
        properties: {
            pdfPath: {
                type: "string",
                description: "Path to the PDF file"
            },
            pdfContentBase64: {
                type: "string",
                description: "Base64-encoded PDF content"
            }
        }
    },
    output: {
        type: "object",
        properties: {
            text_content: {
                type: "string",
                description: "Extracted text content"
            },
            markdown_content: {
                type: "string",
                description: "Markdown representation of the document"
            },
            images: {
                type: "object",
                description: "Extracted images as base64 strings"
            },
            full_result: {
                type: "object",
                description: "Full OCR result"
            },
            metadata: {
                type: "object",
                properties: {
                    source: {
                        type: "string"
                    },
                    timestamp: {
                        type: "string"
                    },
                    pages: {
                        type: "number"
                    }
                }
            }
        },
        required: ["text_content"]
    },
    params: {
        type: "object",
        properties: {
            outputFormat: {
                type: "string",
                enum: ["full", "text", "markdown", "images"],
                description: "Output format"
            },
            saveImages: {
                type: "boolean",
                description: "Whether to save images to disk"
            },
            imagesDir: {
                type: "string",
                description: "Directory to save images"
            },
            markdownDir: {
                type: "string",
                description: "Directory to save markdown files"
            },
            apiKey: {
                type: "string",
                description: "Mistral API key"
            },
            debug: {
                type: "boolean",
                description: "Enable debug mode"
            }
        }
    },
    samples: [
        {
            inputs: {
                pdfPath: "/path/to/document.pdf"
            },
            params: {
                outputFormat: "text",
                saveImages: false
            },
            result: {
                text_content: "Sample document text content",
                metadata: {
                    source: "Mistral OCR",
                    timestamp: "2023-07-01T12:34:56.789Z",
                    pages: 1
                }
            }
        }
    ],
    description: "Processes PDF documents using Mistral OCR to extract text, markdown, and images",
    category: ["ai", "service", "document"],
    author: "Receptron Team",
    repository: "https://github.com/receptron/graphai",
    license: "MIT",
    environmentVariables: ["MISTRAL_API_KEY"],
    npms: ["axios", "form-data"]
};
exports.default = mistralOcrAgentInfo;
