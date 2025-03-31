#!/bin/bash

# GraphAI Sample Fix Script
# This script generates a fix proposal for a broken sample using OpenAI API

# Set up variables
SAMPLE_PATH=""
OPENAI_API_KEY=""
PR_DIFF_FILE=""
PR_DESCRIPTION_FILE=""
OUTPUT_FILE="fix_proposal.md"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --sample)
      SAMPLE_PATH="$2"
      shift 2
      ;;
    --openai-api-key)
      OPENAI_API_KEY="$2"
      shift 2
      ;;
    --pr-diff)
      PR_DIFF_FILE="$2"
      shift 2
      ;;
    --pr-description)
      PR_DESCRIPTION_FILE="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check required parameters
if [ -z "${SAMPLE_PATH}" ] || [ -z "${OPENAI_API_KEY}" ]; then
    echo "Error: Missing required parameters."
    echo "Usage: $0 --sample <SAMPLE_PATH> --openai-api-key <OPENAI_API_KEY> [--pr-diff <PR_DIFF_FILE>] [--pr-description <PR_DESCRIPTION_FILE>] [--output <OUTPUT_FILE>]"
    exit 1
fi

# Check if sample file exists
if [ ! -f "${SAMPLE_PATH}" ]; then
    echo "Error: Sample file not found: ${SAMPLE_PATH}"
    exit 1
fi

# Get sample file extension
EXTENSION="${SAMPLE_PATH##*.}"

# Determine language based on extension
LANGUAGE=""
case "${EXTENSION}" in
    ts|js)
        LANGUAGE="TypeScript/JavaScript"
        ;;
    yaml|yml)
        LANGUAGE="YAML"
        ;;
    *)
        LANGUAGE="Unknown"
        ;;
esac

# Execute sample to get error message
echo "Executing sample to get error message..."
ERROR_FILE="error_output.txt"

if [ "${EXTENSION}" == "ts" ] || [ "${EXTENSION}" == "js" ]; then
    # Execute TypeScript/JavaScript sample
    cd "$(dirname "${SAMPLE_PATH}")" && npx ts-node "$(basename "${SAMPLE_PATH}")" 2>&1 > "${ERROR_FILE}" || true
elif [ "${EXTENSION}" == "yaml" ] || [ "${EXTENSION}" == "yml" ]; then
    # Execute YAML sample
    graphai "${SAMPLE_PATH}" 2>&1 > "${ERROR_FILE}" || true
else
    echo "Error: Unsupported file extension: ${EXTENSION}"
    exit 1
fi

# Create fix proposal file header
cat > "${OUTPUT_FILE}" << EOH
# GraphAI Sample Fix Proposal
Generated: $(date +"%Y-%m-%d %H:%M:%S")

## ${SAMPLE_PATH}

### Original Code (${LANGUAGE})

\`\`\`${EXTENSION}
$(cat "${SAMPLE_PATH}")
\`\`\`

### Error

\`\`\`
$(cat "${ERROR_FILE}")
\`\`\`

EOH

# Add PR diff if available
if [ -n "${PR_DIFF_FILE}" ] && [ -f "${PR_DIFF_FILE}" ]; then
    cat >> "${OUTPUT_FILE}" << EOD
### PR Diff

\`\`\`diff
$(cat "${PR_DIFF_FILE}")
\`\`\`

EOD
fi

# Add PR description if available
if [ -n "${PR_DESCRIPTION_FILE}" ] && [ -f "${PR_DESCRIPTION_FILE}" ]; then
    cat >> "${OUTPUT_FILE}" << EOD
### PR Description

\`\`\`
$(cat "${PR_DESCRIPTION_FILE}")
\`\`\`

EOD
fi

# Generate fix proposal using OpenAI API
echo "Generating fix proposal using OpenAI API..."
cat >> "${OUTPUT_FILE}" << EOD
### Fix Proposal

EOD

# Prepare prompt for OpenAI API
PROMPT="I need to fix a GraphAI sample that is failing. Here is the relevant information:

Sample code (${LANGUAGE}):
$(cat "${SAMPLE_PATH}")

Error message:
$(cat "${ERROR_FILE}")"

# Add PR diff if available
if [ -n "${PR_DIFF_FILE}" ] && [ -f "${PR_DIFF_FILE}" ]; then
    PROMPT="${PROMPT}

PR diff:
$(cat "${PR_DIFF_FILE}")"
fi

# Add PR description if available
if [ -n "${PR_DESCRIPTION_FILE}" ] && [ -f "${PR_DESCRIPTION_FILE}" ]; then
    PROMPT="${PROMPT}

PR description (may contain release notes):
$(cat "${PR_DESCRIPTION_FILE}")"
fi

PROMPT="${PROMPT}

Please provide a fixed version of the sample code with an explanation of what was changed and why."

# Call OpenAI API
curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -d "{
    \"model\": \"gpt-4\",
    \"messages\": [
      {
        \"role\": \"system\",
        \"content\": \"You are a helpful assistant that fixes GraphAI sample code that has broken due to specification changes. Analyze the code, error message, PR diff, and PR description to propose a fix.\"
      },
      {
        \"role\": \"user\",
        \"content\": \"${PROMPT}\"
      }
    ],
    \"temperature\": 0.7,
    \"max_tokens\": 2000
  }" | jq -r '.choices[0].message.content' >> "${OUTPUT_FILE}"

echo "Fix proposal generated: ${OUTPUT_FILE}"
rm "${ERROR_FILE}"
