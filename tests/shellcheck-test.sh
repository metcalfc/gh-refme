#!/bin/bash
#
# Tests for shell script best practices using shellcheck
#
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The main script should be in the parent directory
MAIN_SCRIPT="${SCRIPT_DIR}/../gh-refme"

# Source common test utilities
source "${SCRIPT_DIR}/test_utils.sh"

# Initialize test counters
init_test_counters

print_header "ShellCheck Analysis"

# Check if shellcheck is available
if ! command -v shellcheck &> /dev/null; then
  warn_msg "shellcheck not found. Skipping best practices check."
  info_msg "You can install shellcheck with:"
  info_msg "  - On Ubuntu/Debian: sudo apt-get install shellcheck"
  info_msg "  - On macOS with Homebrew: brew install shellcheck"
  info_msg "  - On Windows with Chocolatey: choco install shellcheck"
  exit 0
fi

# Validate the script exists and is executable
validate_refme_script "${MAIN_SCRIPT}" || exit 1

info_msg "Running shellcheck to identify potential issues..."

# Run shellcheck with common best practices
RESULT=$(shellcheck -x "${MAIN_SCRIPT}" 2>&1 || true)

if [[ -z "$RESULT" ]]; then
  print_result "ShellCheck Analysis" "pass" "No issues found!"
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
  
  info_msg "Found potential issues:"
  info_msg "  Info: $INFO_COUNT"
  info_msg "  Warnings: $WARNING_COUNT"
  info_msg "  Errors: $ERROR_COUNT"
  
  echo "$RESULT"
  
  if [[ "$ERROR_COUNT" -gt 0 ]]; then
    print_result "ShellCheck Analysis" "fail" "Errors detected. These should be fixed."
    exit 1
  else
    print_result "ShellCheck Analysis" "pass" "Only warnings and info messages found. The script is still usable."
    exit 0
  fi
fi
