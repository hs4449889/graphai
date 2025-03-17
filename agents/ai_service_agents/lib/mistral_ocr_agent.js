"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.mistralOcrAgent = void 0;
const axios_1 = __importDefault(require("axios"));
const form_data_1 = __importDefault(require("form-data"));
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const mistralOcrAgent = async ({ namedInputs, params, config }) => {
    // Get parameters
    const { outputFormat = "text", saveImages = false, imagesDir = "output/images", markdownDir = "output/markdown" } = params;
    // Get inputs
    const { pdfPath, pdfContentBase64 } = namedInputs;
    // Get API key
    const apiKey = (config === null || config === void 0 ? void 0 : config.apiKey) || params.apiKey || process.env.MISTRAL_API_KEY;
    if (!apiKey) {
        throw new Error("Mistral API key not provided and MISTRAL_API_KEY environment variable not set");
    }
    if (!pdfPath && !pdfContentBase64) {
        throw new Error("Either pdfPath or pdfContentBase64 must be provided");
    }
    // Create API client
    const client = axios_1.default.create({
        baseURL: "https://api.mistral.ai/v1",
        headers: {
            "Authorization": `Bearer ${apiKey}`,
            "Content-Type": "application/json"
        }
    });
    // Process PDF
    let fileContent;
    let fileName;
    if (pdfPath) {
        fileContent = fs_1.default.readFileSync(pdfPath);
        fileName = path_1.default.basename(pdfPath);
    }
    else if (pdfContentBase64) {
        fileContent = Buffer.from(pdfContentBase64, 'base64');
        fileName = "document.pdf";
    }
    else {
        throw new Error("Either pdfPath or pdfContentBase64 must be provided");
    }
    // Upload PDF
    const formData = new form_data_1.default();
    formData.append("file", fileContent, { filename: fileName });
    formData.append("purpose", "ocr");
    const uploadResponse = await client.post("/files", formData, {
        headers: Object.assign({}, formData.getHeaders())
    });
    const fileId = uploadResponse.data.id;
    // Get signed URL
    const signedUrlResponse = await client.get(`/files/${fileId}/signed_url`);
    const signedUrl = signedUrlResponse.data.url;
    // Process OCR
    const ocrResponse = await client.post("/ocr/process", {
        model: "mistral-ocr-latest",
        document: {
            type: "document_url",
            document_url: signedUrl
        },
        include_image_base64: saveImages
    });
    const ocrResult = ocrResponse.data;
    // Process results based on output format
    const result = {
        text_content: ""
    };
    // Extract text content
    const textContent = extractTextContent(ocrResult);
    result.text_content = textContent;
    if (outputFormat === "full") {
        result.ocr_result = ocrResult;
    }
    if ((outputFormat === "full" || outputFormat === "images") && saveImages) {
        // Create directories
        if (!fs_1.default.existsSync(imagesDir)) {
            fs_1.default.mkdirSync(imagesDir, { recursive: true });
        }
        // Extract images
        const savedImagesDict = extractImages(ocrResult, imagesDir);
        result.saved_images = savedImagesDict;
    }
    if ((outputFormat === "full" || outputFormat === "markdown") && saveImages) {
        // Create directories for markdown
        if (!fs_1.default.existsSync(markdownDir)) {
            fs_1.default.mkdirSync(markdownDir, { recursive: true });
        }
        // Save markdown files
        const savedImagesDict = result.saved_images || {};
        const markdownFiles = saveMarkdownFiles(ocrResult, markdownDir, savedImagesDict);
        result.markdown_files = markdownFiles;
    }
    return result;
};
exports.mistralOcrAgent = mistralOcrAgent;
// Helper functions
function extractTextContent(ocrResult) {
    const textContent = [];
    for (const page of ocrResult.pages) {
        for (const block of page.blocks || []) {
            if (block.type === "text") {
                textContent.push(block.text || "");
            }
        }
    }
    return textContent.join("\n");
}
function extractImages(ocrResult, imagesDir) {
    const allSavedImages = {};
    for (const page of ocrResult.pages) {
        const pageIndex = page.index;
        const pageImages = page.images || [];
        const savedImages = {};
        for (const img of pageImages) {
            const imgId = img.id;
            const imgBase64 = img.image_base64;
            if (!imgBase64 || imgBase64 === "..." || imgBase64.endsWith("...")) {
                continue;
            }
            try {
                let base64Data = imgBase64;
                if (imgBase64.startsWith("data:")) {
                    base64Data = imgBase64.split(",", 2)[1];
                }
                const imgData = Buffer.from(base64Data, 'base64');
                let imgExtension = ".jpg";
                if (imgBase64.startsWith("data:image/")) {
                    const formatPart = imgBase64.split(";", 1)[0];
                    imgExtension = "." + formatPart.split("/", 2)[1];
                }
                let imgPath;
                if (imgId.toLowerCase().endsWith(".jpg") || imgId.toLowerCase().endsWith(".jpeg") ||
                    imgId.toLowerCase().endsWith(".png") || imgId.toLowerCase().endsWith(".gif") ||
                    imgId.toLowerCase().endsWith(".bmp") || imgId.toLowerCase().endsWith(".webp")) {
                    imgPath = path_1.default.join(imagesDir, imgId);
                }
                else {
                    imgPath = path_1.default.join(imagesDir, `${imgId}${imgExtension}`);
                }
                fs_1.default.writeFileSync(imgPath, imgData);
                savedImages[imgId] = imgPath;
            }
            catch (error) {
                console.error(`Failed to save image ${imgId}: ${error}`);
            }
        }
        allSavedImages[pageIndex] = savedImages;
    }
    return allSavedImages;
}
function saveMarkdownFiles(ocrResult, markdownDir, savedImagesDict) {
    const resultFiles = {};
    // Save individual pages
    for (const page of ocrResult.pages) {
        const pageIndex = page.index;
        let markdownText = page.markdown;
        const savedImages = savedImagesDict[pageIndex] || {};
        const imageIds = Object.keys(savedImages);
        if (imageIds.length > 0) {
            markdownText = fixImageReferences(markdownText, imageIds);
        }
        const outputFile = path_1.default.join(markdownDir, `page_${pageIndex}.md`);
        fs_1.default.writeFileSync(outputFile, markdownText, 'utf8');
        resultFiles[`page_${pageIndex}`] = outputFile;
    }
    // Save combined markdown
    const combinedFile = path_1.default.join(markdownDir, "combined.md");
    const combinedContent = [];
    const allImageIds = [];
    for (const pageImages of Object.values(savedImagesDict)) {
        allImageIds.push(...Object.keys(pageImages));
    }
    const uniqueImageIds = [...new Set(allImageIds)];
    for (const page of ocrResult.pages.sort((a, b) => a.index - b.index)) {
        let pageMarkdown = page.markdown;
        if (uniqueImageIds.length > 0) {
            pageMarkdown = fixImageReferences(pageMarkdown, uniqueImageIds);
        }
        combinedContent.push(pageMarkdown);
        combinedContent.push("\n\n");
    }
    fs_1.default.writeFileSync(combinedFile, combinedContent.join(""), 'utf8');
    resultFiles["combined"] = combinedFile;
    return resultFiles;
}
function fixImageReferences(markdownText, imageIds) {
    let result = markdownText;
    for (const imgId of imageIds) {
        const correctPath = `../images/${imgId}`;
        // Pattern 1: double bracket pattern
        result = result.replace(new RegExp(`!\\[(.*?)\\]\\([^)]*${escapeRegExp(imgId)}[^)]*\\)(?:\\([^)]*${escapeRegExp(imgId)}[^)]*\\))+`, 'g'), `![${imgId}](${correctPath})`);
        // Pattern 2: single bracket pattern
        result = result.replace(new RegExp(`!\\[(.*?)\\]\\([^)]*${escapeRegExp(imgId)}[^)]*\\)`, 'g'), `![${imgId}](${correctPath})`);
        // Pattern 3: no bracket pattern
        result = result.replace(new RegExp(`!\\[${escapeRegExp(imgId)}\\](?!\\()`, 'g'), `![${imgId}](${correctPath})`);
    }
    return result;
}
function escapeRegExp(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
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
        },
        oneOf: [
            { required: ["pdfPath"] },
            { required: ["pdfContentBase64"] }
        ]
    },
    output: {
        type: "object",
        properties: {
            text_content: {
                type: "string",
                description: "Extracted text content"
            },
            saved_images: {
                type: "object",
                description: "Dictionary of saved images"
            },
            markdown_files: {
                type: "object",
                description: "Dictionary of saved markdown files"
            },
            ocr_result: {
                type: "object",
                description: "Full OCR result"
            }
        },
        required: ["text_content"]
    },
    params: {
        type: "object",
        properties: {
            outputFormat: {
                type: "string",
                description: "Output format (text, markdown, images, full)"
            },
            saveImages: {
                type: "boolean",
                description: "Whether to save images"
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
            }
        }
    },
    samples: [
        {
            inputs: {
                pdfPath: "/path/to/document.pdf"
            },
            params: {
                outputFormat: "text"
            },
            result: {
                text_content: "Sample extracted text from the PDF document."
            }
        }
    ],
    description: "Extracts text and images from PDF documents using Mistral OCR",
    category: ["ai", "service"],
    author: "Receptron Team",
    repository: "https://github.com/receptron/graphai",
    license: "MIT",
    environmentVariables: ["MISTRAL_API_KEY"],
    npms: ["axios", "form-data"]
};
exports.default = mistralOcrAgentInfo;
