#!/bin/bash

# GraphAI Sample Execution Script (Test Version)
# This script executes a few GraphAI samples for testing

# Set up variables
REPORT_FILE="sample_execution_report.md"
SAMPLES_DIR="$(pwd)/packages/samples"
GRAPH_DATA_DIR="${SAMPLES_DIR}/graph_data"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
MAX_EXECUTION_TIME=10  # Maximum execution time in seconds for testing

# Create .env file with dummy API keys if not exists
create_dummy_env() {
    if [ ! -f "${SAMPLES_DIR}/.env" ]; then
        echo "Creating dummy .env file for testing..."
        cat > "${SAMPLES_DIR}/.env" << EOE
# Dummy API keys for testing
# Replace with actual keys for real execution
OPENAI_API_KEY=dummy_openai_key
GROQ_API_KEY=dummy_groq_key
ANTHROPIC_API_KEY=dummy_anthropic_key
GOOGLE_API_KEY=dummy_google_key
EOE
    fi
}

# Create report header
cat > "${REPORT_FILE}" << EOH
# GraphAI Sample Execution Report (Test Run)
Generated: ${TIMESTAMP}

## Summary

This is a test run of the sample execution script.

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

# Execute only a few samples for testing
echo "Executing test samples..."
echo "## YAML Samples" >> "${REPORT_FILE}"

# Test with one sample from OpenAI
echo "### OpenAI Samples" >> "${REPORT_FILE}"
if [ -d "${GRAPH_DATA_DIR}/openai" ] && [ "$(ls -A ${GRAPH_DATA_DIR}/openai/*.yaml 2>/dev/null)" ]; then
    # Get the simple sample file
    sample="graph_data/openai/simple.yaml"
    if [ -f "${SAMPLES_DIR}/${sample}" ]; then
        sample_name=$(basename "${sample}" .yaml)
        execute_sample "${sample}" "${sample_name}" "yaml"
    fi
fi

# Test with one sample from Groq
echo "### Groq Samples" >> "${REPORT_FILE}"
if [ -d "${GRAPH_DATA_DIR}/groq" ] && [ "$(ls -A ${GRAPH_DATA_DIR}/groq/*.yaml 2>/dev/null)" ]; then
    # Get the simple sample file
    sample="graph_data/groq/simple.yaml"
    if [ -f "${SAMPLES_DIR}/${sample}" ]; then
        sample_name=$(basename "${sample}" .yaml)
        execute_sample "${sample}" "${sample_name}" "yaml"
    fi
fi

echo "Sample execution test completed. Report generated: ${REPORT_FILE}"

# Generate final report
if [ -f "scripts/generate_report.sh" ]; then
    echo "Generating final report..."
    bash scripts/generate_report.sh
fi
