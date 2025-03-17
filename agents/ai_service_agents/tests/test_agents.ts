import axios from 'axios';
import * as fs from 'fs';
import * as path from 'path';
import responseApiAgentInfo from '../src/response_api_agent';
import mistralOcrAgentInfo from '../src/mistral_ocr_agent';

// Get the actual agent functions
const responseApiAgentFn = responseApiAgentInfo.agent;
const mistralOcrAgentFn = mistralOcrAgentInfo.agent;

// API keys from environment variables
const RESPONSE_API_KEY = process.env.RESPONSE_API_KEY;
const MISTRAL_API_KEY = process.env.MISTRAL_API_KEY;

// Test Response API agent
async function testResponseApiAgent() {
  console.log('Testing Response API agent...');
  
  try {
    const result = await responseApiAgentFn({
      params: {
        endpoint: 'chat/completions',
        method: 'POST',
        maxRetries: 3,
        apiKey: RESPONSE_API_KEY
      },
      namedInputs: {
        requestData: {
          model: 'response-1',
          messages: [
            { role: 'user', content: 'What is GraphAI?' }
          ]
        }
      },
      config: {}
    });
    
    console.log('Response API agent result:');
    console.log('Text:', result.text);
    console.log('Research URLs:', result.research_urls);
    console.log('✅ Response API agent test passed');
    return true;
  } catch (error) {
    console.error('❌ Response API agent test failed:', error.message);
    return false;
  }
}

// Test Mistral OCR agent
async function testMistralOcrAgent(pdfPath?: string) {
  console.log('Testing Mistral OCR agent...');
  
  try {
    // Create a simple PDF if no path provided
    let testPdfPath = pdfPath;
    let tempPdfCreated = false;
    
    if (!testPdfPath) {
      testPdfPath = path.join(__dirname, 'test.pdf');
      fs.writeFileSync(testPdfPath, '%PDF-1.5\n%Test PDF');
      tempPdfCreated = true;
    }
    
    const result = await mistralOcrAgentFn({
      params: {
        outputFormat: 'text',
        saveImages: false,
        apiKey: MISTRAL_API_KEY
      },
      namedInputs: {
        pdfPath: testPdfPath
      },
      config: {}
    });
    
    // Clean up temp file if created
    if (tempPdfCreated && fs.existsSync(testPdfPath)) {
      fs.unlinkSync(testPdfPath);
    }
    
    console.log('Mistral OCR agent result:');
    console.log('Text content:', result.text_content);
    console.log('✅ Mistral OCR agent test passed');
    return true;
  } catch (error) {
    console.error('❌ Mistral OCR agent test failed:', error.message);
    return false;
  }
}

// Test error handling
async function testErrorHandling() {
  console.log('Testing error handling...');
  
  try {
    // Test missing required inputs
    try {
      await responseApiAgentFn({
        params: {},
        namedInputs: {},
        config: {}
      });
      console.error('❌ Error handling test failed: Expected error for missing inputs');
      return false;
    } catch (error) {
      console.log('✅ Error handling test passed: Correctly caught missing inputs');
    }
    
    // Test invalid API key
    try {
      await responseApiAgentFn({
        params: {
          endpoint: 'chat/completions',
          method: 'POST',
          apiKey: 'invalid-key'
        },
        namedInputs: {
          requestData: {
            model: 'response-1',
            messages: [
              { role: 'user', content: 'Hello' }
            ]
          }
        },
        config: {}
      });
      console.error('❌ Error handling test failed: Expected error for invalid API key');
      return false;
    } catch (error) {
      console.log('✅ Error handling test passed: Correctly caught invalid API key');
    }
    
    return true;
  } catch (error) {
    console.error('❌ Error handling test failed:', error.message);
    return false;
  }
}

// Run all tests
async function runTests() {
  console.log('Running tests for GraphAI AI Service Agents...');
  
  // Import agents
  const { responseApiAgent, mistralOcrAgent } = await import('../src');
  
  // Run tests
  const responseApiTest = await testResponseApiAgent();
  const mistralOcrTest = await testMistralOcrAgent();
  const errorHandlingTest = await testErrorHandling();
  
  // Report results
  console.log('\nTest Results:');
  console.log('Response API Agent:', responseApiTest ? '✅ PASSED' : '❌ FAILED');
  console.log('Mistral OCR Agent:', mistralOcrTest ? '✅ PASSED' : '❌ FAILED');
  console.log('Error Handling:', errorHandlingTest ? '✅ PASSED' : '❌ FAILED');
  
  if (responseApiTest && mistralOcrTest && errorHandlingTest) {
    console.log('\n✅ All tests passed!');
    return 0;
  } else {
    console.log('\n❌ Some tests failed!');
    return 1;
  }
}

// Run tests if this file is executed directly
if (require.main === module) {
  runTests().then(exitCode => {
    process.exit(exitCode);
  });
}
