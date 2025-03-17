#!/bin/bash

# GraphAI Sample Execution Script
# This script executes all GraphAI samples and generates a Markdown report

# Set up variables
REPORT_FILE="sample_execution_report.md"
SAMPLES_DIR="$(pwd)/packages/samples"
GRAPH_DATA_DIR="${SAMPLES_DIR}/graph_data"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
MAX_EXECUTION_TIME=30  # Maximum execution time in seconds

# Create .env file with dummy API keys if not exists
create_dummy_env() {
    if [ ! -f "${SAMPLES_DIR}/.env" ]; then
        echo "Creating dummy .env file for testing..."
        cat > "${SAMPLES_DIR}/.env" << EOE
# Dummy API keys for testing
# Replace with actual keys for real execution
RESPONSE_API_KEY=dummy_response_key
MISTRAL_API_KEY=dummy_mistral_key
OPENAI_API_KEY=dummy_openai_key
GROQ_API_KEY=dummy_groq_key
ANTHROPIC_API_KEY=dummy_anthropic_key
GOOGLE_API_KEY=dummy_google_key
EOE
    fi
}

# Create report header
cat > "${REPORT_FILE}" << EOH
# GraphAI Sample Execution Report
Generated: ${TIMESTAMP}

## Summary

This report contains the execution results of GraphAI samples.

## Sample Execution Results

EOH

# Function to execute a sample with timeout and append results to report
execute_sample() {
    local sample_path="$1"
    local sample_name="$2"
    local sample_type="$3"
    
    echo "Executing sample: ${sample_name} (${sample_type})"
    
    # Append sample header to report
    cat >> "${REPORT_FILE}" << EOS

### ${sample_name} (${sample_type})

\`\`\`
Sample path: ${sample_path}
\`\`\`

#### Execution Output:

\`\`\`
EOS
    
    # Execute sample with timeout and capture output
    if [ "${sample_type}" == "yaml" ]; then
        # Execute YAML sample
        cd "${SAMPLES_DIR}" && timeout ${MAX_EXECUTION_TIME}s graphai "${sample_path}" 2>&1 | tee -a "${REPORT_FILE}"
        EXEC_STATUS=${PIPESTATUS[0]}
    elif [ "${sample_type}" == "ts" ]; then
        # Execute TypeScript sample
        cd "${SAMPLES_DIR}" && timeout ${MAX_EXECUTION_TIME}s npx ts-node "${sample_path}" 2>&1 | tee -a "${REPORT_FILE}"
        EXEC_STATUS=${PIPESTATUS[0]}
    fi
    
    # Close code block in report
    echo "\`\`\`" >> "${REPORT_FILE}"
    
    # Add execution status
    if [ "${EXEC_STATUS}" -eq 0 ]; then
        echo -e "\n**Status**: ✅ Success\n" >> "${REPORT_FILE}"
    elif [ "${EXEC_STATUS}" -eq 124 ]; then
        echo -e "\n**Status**: ⚠️ Timeout (exceeded ${MAX_EXECUTION_TIME} seconds)\n" >> "${REPORT_FILE}"
    else
        echo -e "\n**Status**: ❌ Failed (exit code: ${EXEC_STATUS})\n" >> "${REPORT_FILE}"
    fi
}

# Create dummy environment variables for testing
create_dummy_env

# Execute YAML samples
echo "Executing YAML samples..."
echo "## YAML Samples" >> "${REPORT_FILE}"

# Function to execute samples in a directory
execute_samples_in_dir() {
    local dir="$1"
    local provider="$2"
    
    echo "### ${provider} Samples" >> "${REPORT_FILE}"
    
    # Check if directory exists and has YAML files
    if [ -d "${dir}" ] && [ "$(ls -A ${dir}/*.yaml 2>/dev/null)" ]; then
        for sample in "${dir}"/*.yaml; do
            sample_name=$(basename "${sample}" .yaml)
            sample_rel_path=$(realpath --relative-to="${SAMPLES_DIR}" "${sample}")
            execute_sample "${sample_rel_path}" "${sample_name}" "yaml"
        done
    else
        echo "No YAML samples found in ${dir}" >> "${REPORT_FILE}"
    fi
}

# Execute samples for each provider
execute_samples_in_dir "${GRAPH_DATA_DIR}/openai" "OpenAI"
execute_samples_in_dir "${GRAPH_DATA_DIR}/groq" "Groq"
execute_samples_in_dir "${GRAPH_DATA_DIR}/anthropic" "Anthropic"
execute_samples_in_dir "${GRAPH_DATA_DIR}/google" "Google"
execute_samples_in_dir "${GRAPH_DATA_DIR}/ollama" "Ollama"
execute_samples_in_dir "${GRAPH_DATA_DIR}" "Root" # For Response API and Mistral OCR samples
execute_samples_in_dir "${GRAPH_DATA_DIR}/test" "Test"

# Execute TypeScript samples
echo "Executing TypeScript samples..."
echo "## TypeScript Samples" >> "${REPORT_FILE}"

# Function to execute TypeScript samples in a directory
execute_ts_samples_in_dir() {
    local dir="$1"
    local category="$2"
    
    echo "### ${category} Samples" >> "${REPORT_FILE}"
    
    # Check if directory exists and has TypeScript files
    if [ -d "${dir}" ] && [ "$(ls -A ${dir}/*.ts 2>/dev/null)" ]; then
        for sample in "${dir}"/*.ts; do
            # Skip index files and utility files
            if [[ "$(basename "${sample}")" == "index.ts" || "$(basename "${sample}")" == *".d.ts" ]]; then
                continue
            fi
            
            sample_name=$(basename "${sample}" .ts)
            sample_rel_path=$(realpath --relative-to="${SAMPLES_DIR}" "${sample}")
            execute_sample "${sample_rel_path}" "${sample_name}" "ts"
        done
    else
        echo "No TypeScript samples found in ${dir}" >> "${REPORT_FILE}"
    fi
}

# Execute TypeScript samples for each category
execute_ts_samples_in_dir "${SAMPLES_DIR}/src/llm" "LLM"
execute_ts_samples_in_dir "${SAMPLES_DIR}/src/interaction" "Interaction"
execute_ts_samples_in_dir "${SAMPLES_DIR}/src/net" "Network"
execute_ts_samples_in_dir "${SAMPLES_DIR}/src/embeddings" "Embeddings"
execute_ts_samples_in_dir "${SAMPLES_DIR}/src/streaming" "Streaming"
execute_ts_samples_in_dir "${SAMPLES_DIR}/src/test" "Test"
execute_ts_samples_in_dir "${SAMPLES_DIR}/src/tools" "Tools"
execute_ts_samples_in_dir "${SAMPLES_DIR}/src/ai_services" "AI Services" # For Response API and Mistral OCR samples

echo "Sample execution completed. Report generated: ${REPORT_FILE}"

# Generate final report
if [ -f "scripts/generate_report.sh" ]; then
    echo "Generating final report..."
    bash scripts/generate_report.sh
fi
