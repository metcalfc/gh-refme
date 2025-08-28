#!/bin/bash
#
# Run all tests for gh-refme
#
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="${SCRIPT_DIR}/../gh-refme"

# Source common test utilities
source "${SCRIPT_DIR}/test_utils.sh"

# Result tracking
PASSED=0
FAILED=0

# Welcome message
print_header "GitHub RefMe Test Suite"

# Ensure the main script exists
validate_refme_script "${MAIN_SCRIPT}" || exit 1

# Make sure scripts are executable
chmod +x "${SCRIPT_DIR}"/*.sh

# Run each test script
run_test "${SCRIPT_DIR}/test.sh" "Basic Tests"
run_test "${SCRIPT_DIR}/security-test.sh" "Security Tests"
run_test "${SCRIPT_DIR}/branch-ref-test.sh" "Branch Reference Tests"
run_test "${SCRIPT_DIR}/constants-test.sh" "Constants Tests"
run_test "${SCRIPT_DIR}/validation-test.sh" "Input Validation Tests"
run_test "${SCRIPT_DIR}/error-scenarios-test.sh" "Error Scenario Tests"
run_test "${SCRIPT_DIR}/security-enhancements-test.sh" "Security Enhancement Tests"

# Run shellcheck if available (optional)
if command -v shellcheck &> /dev/null; then
  run_test "${SCRIPT_DIR}/shellcheck-test.sh" "ShellCheck Analysis"
else
  warn_msg "ShellCheck not available - skipping best practices check"
fi

# Summary report
print_header "Test Summary"
echo -e "${GREEN}PASSED: $PASSED${NC}"
echo -e "${RED}FAILED: $FAILED${NC}"

if [[ $FAILED -eq 0 ]]; then
  success_msg "All tests passed successfully!"
  exit 0
else
  error_msg "Some tests failed. Please check the output above for details."
  exit 1
fi
