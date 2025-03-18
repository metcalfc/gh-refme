#!/bin/bash
#
# Run all tests for gh-refme
#
set -e

# Colors for better output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="${SCRIPT_DIR}/../gh-refme"

# Result tracking
PASSED=0
FAILED=0

# Test runner function
run_test() {
  local test_script="$1"
  local test_name="$2"
  
  echo -e "\n${BLUE}===============================================${NC}"
  echo -e "${BLUE}Running ${test_name}...${NC}"
  echo -e "${BLUE}===============================================${NC}"
  
  if [[ -x "$test_script" ]]; then
    # Make it executable if it's not already
    chmod +x "$test_script"
  fi
  
  if "$test_script"; then
    echo -e "\n${GREEN}✓ ${test_name} PASSED${NC}"
    PASSED=$((PASSED + 1))
  else
    echo -e "\n${RED}✗ ${test_name} FAILED${NC}"
    FAILED=$((FAILED + 1))
  fi
}

# Welcome message
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}   GitHub RefMe Test Suite   ${NC}"
echo -e "${CYAN}==========================================${NC}"

# Ensure the main script exists
if [[ ! -f "${MAIN_SCRIPT}" ]]; then
  echo -e "${RED}Error: gh-refme not found at ${MAIN_SCRIPT}${NC}"
  exit 1
fi

# Make sure scripts are executable
chmod +x "${MAIN_SCRIPT}"
chmod +x "${SCRIPT_DIR}"/*.sh

# Run each test script
run_test "${SCRIPT_DIR}/test.sh" "Basic Tests"
run_test "${SCRIPT_DIR}/security-test.sh" "Security Tests"
run_test "${SCRIPT_DIR}/comprehensive-test.sh" "Comprehensive Tests"
run_test "${SCRIPT_DIR}/branch-ref-test.sh" "Branch Reference Tests"

# Run shellcheck if available (optional)
if command -v shellcheck &> /dev/null; then
  run_test "${SCRIPT_DIR}/shellcheck-test.sh" "ShellCheck Analysis"
else
  echo -e "\n${YELLOW}⚠ ShellCheck not available - skipping best practices check${NC}"
fi

# Summary report
echo -e "\n${CYAN}==========================================${NC}"
echo -e "${CYAN}           Test Summary           ${NC}"
echo -e "${CYAN}==========================================${NC}"
echo -e "${GREEN}PASSED: $PASSED${NC}"
echo -e "${RED}FAILED: $FAILED${NC}"
echo -e "${CYAN}==========================================${NC}"

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}All tests passed successfully!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed. Please check the output above for details.${NC}"
  exit 1
fi
