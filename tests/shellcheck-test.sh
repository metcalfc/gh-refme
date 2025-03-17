#!/bin/bash
#
# Tests for shell script best practices using shellcheck
#
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The main script should be in the parent directory
MAIN_SCRIPT="${SCRIPT_DIR}/../gh-refme"

# Colors for better test output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Checking shell script best practices for gh-refme..."

# Check if shellcheck is available
if ! command -v shellcheck &> /dev/null; then
  echo -e "${YELLOW}WARNING: shellcheck not found. Skipping best practices check.${NC}"
  echo "You can install shellcheck with:"
  echo "  - On Ubuntu/Debian: sudo apt-get install shellcheck"
  echo "  - On macOS with Homebrew: brew install shellcheck"
  echo "  - On Windows with Chocolatey: choco install shellcheck"
  exit 0
fi

# Check if the script exists
if [[ ! -f "${MAIN_SCRIPT}" ]]; then
  echo -e "${RED}Error: gh-refme not found at ${MAIN_SCRIPT}${NC}"
  exit 1
fi

# Make sure the script is executable
chmod +x "${MAIN_SCRIPT}"

echo "Running shellcheck to identify potential issues..."

# Run shellcheck with common best practices
RESULT=$(shellcheck -x "${MAIN_SCRIPT}" 2>&1 || true)

if [[ -z "$RESULT" ]]; then
  echo -e "${GREEN}✓ No issues found!${NC}"
  exit 0
else
  # Count the number of issues by severity
  INFO_COUNT=0
  WARNING_COUNT=0
  ERROR_COUNT=0
  
  if echo "$RESULT" | grep -q "^In .* line .*: note:"; then
    INFO_COUNT=$(echo "$RESULT" | grep -c "^In .* line .*: note:")
  fi
  
  if echo "$RESULT" | grep -q "^In .* line .*: warning:"; then
    WARNING_COUNT=$(echo "$RESULT" | grep -c "^In .* line .*: warning:")
  fi
  
  if echo "$RESULT" | grep -q "^In .* line .*: error:"; then
    ERROR_COUNT=$(echo "$RESULT" | grep -c "^In .* line .*: error:")
  fi
  
  echo -e "${YELLOW}Found potential issues:${NC}"
  echo -e "  ${GREEN}Info: $INFO_COUNT${NC}"
  echo -e "  ${YELLOW}Warnings: $WARNING_COUNT${NC}"
  echo -e "  ${RED}Errors: $ERROR_COUNT${NC}"
  echo ""
  echo "$RESULT"
  
  if [[ "$ERROR_COUNT" -gt 0 ]]; then
    echo -e "\n${RED}Errors detected. These should be fixed.${NC}"
    exit 1
  else
    echo -e "\n${YELLOW}Only warnings and info messages found. The script is still usable, but could be improved.${NC}"
    exit 0
  fi
fi
