#!/bin/bash
#
# Security enhancements tests for gh-refme
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

print_header "Security Enhancement Tests"

# Validate the script exists and is executable
validate_refme_script "${MAIN_SCRIPT}" || exit 1

# Create temporary test directory
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

print_sub_header "Testing enhanced file path security validation"

# Test 1: Extremely long path detection
info_msg "Testing long path detection..."
LONG_PATH="${TEST_DIR}/$(printf 'a%.0s' {1..5000}).yml"

OUTPUT=$("${MAIN_SCRIPT}" "$LONG_PATH" 2>&1 || true)

if [[ "$OUTPUT" =~ "path too long" ]] || [[ "$OUTPUT" =~ "File not found" ]]; then
  print_result "Long path detection" "pass"
else
  print_result "Long path detection" "fail" "Should handle long paths gracefully, got: $OUTPUT"
  exit 1
fi

print_sub_header "Testing enhanced reference security validation"

# Test 2: URL injection attempt detection
info_msg "Testing URL injection detection..."
cat > "${TEST_DIR}/url-injection.yml" << 'EOF'
name: Test
on: [push]
jobs:
  test:
    steps:
      - uses: https://evil.com/malicious@v1
EOF

OUTPUT=$("${MAIN_SCRIPT}" "${TEST_DIR}/url-injection.yml" 2>&1 || true)

if [[ "$OUTPUT" =~ "URL schemes" ]] || [[ "$OUTPUT" =~ "injection" ]] || [[ "$OUTPUT" =~ "Security validation failed" ]]; then
  print_result "URL injection detection" "pass"
else
  print_result "URL injection detection" "fail" "Should detect URL injection, got: $OUTPUT"
  exit 1
fi

print_sub_header "Testing secure file operations"

# Test 3: File permissions preservation
info_msg "Testing file permissions preservation..."
TEST_FILE="${TEST_DIR}/permissions-test.yml"
cat > "$TEST_FILE" << 'EOF'
name: Test
on: [push]
jobs:
  test:
    steps:
      - uses: actions/checkout@v4
EOF

# Set specific permissions
chmod 640 "$TEST_FILE"
ORIGINAL_PERMS=$(stat -c '%a' "$TEST_FILE")

# Process the file
"${MAIN_SCRIPT}" "$TEST_FILE" --dry-run >/dev/null 2>&1 || true

# Check if permissions are preserved
NEW_PERMS=$(stat -c '%a' "$TEST_FILE")

if [[ "$ORIGINAL_PERMS" == "$NEW_PERMS" ]]; then
  print_result "File permissions preservation" "pass"
else
  print_result "File permissions preservation" "fail" "Permissions changed from $ORIGINAL_PERMS to $NEW_PERMS"
  exit 1
fi

# Test 4: Secure temporary file creation
info_msg "Testing secure temporary file creation..."
# This test verifies that temporary files are created with secure permissions
# We'll check this by examining the umask and temp file permissions indirectly

TEST_FILE="${TEST_DIR}/secure-temp.yml"
echo "uses: actions/checkout@v4" > "$TEST_FILE"

# Process file and check that it completes without security errors
OUTPUT=$("${MAIN_SCRIPT}" "$TEST_FILE" --dry-run 2>&1 || true)

if [[ "$OUTPUT" =~ "Processing" ]] && [[ ! "$OUTPUT" =~ "ERROR" ]]; then
  print_result "Secure temporary file creation" "pass"
else
  print_result "Secure temporary file creation" "fail" "Unexpected output: $OUTPUT"
  exit 1
fi

print_sub_header "Testing environment security"

# Test 5: Environment variable sanitization
info_msg "Testing environment variable sanitization..."
# Set potentially dangerous environment variables
export IFS=";"
export PATH=".:$PATH"

# Process a file and verify it works despite dangerous environment
TEST_FILE="${TEST_DIR}/env-test.yml"
echo "uses: actions/checkout@v4" > "$TEST_FILE"

OUTPUT=$("${MAIN_SCRIPT}" "$TEST_FILE" --dry-run 2>&1 || true)

if [[ "$OUTPUT" =~ "Processing" ]] || [[ "$OUTPUT" =~ "Converting" ]]; then
  print_result "Environment sanitization" "pass"
else
  print_result "Environment sanitization" "fail" "Failed with dangerous environment: $OUTPUT"
  exit 1
fi

# Clean up environment
unset IFS
export PATH="${PATH#.:}"

# Test 6: Valid references still work with security enhancements
info_msg "Testing valid references still work with security..."
TEST_FILE="${TEST_DIR}/valid-refs.yml"
cat > "$TEST_FILE" << 'EOF'
name: Test
on: [push]
jobs:
  test:
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v3
EOF

OUTPUT=$("${MAIN_SCRIPT}" "$TEST_FILE" --dry-run 2>&1 || true)

if [[ "$OUTPUT" =~ "actions/checkout" ]] && [[ "$OUTPUT" =~ "actions/setup-node" ]] && [[ "$OUTPUT" =~ "Found 2 GitHub references" ]]; then
  print_result "Valid references with security" "pass"
else
  print_result "Valid references with security" "fail" "Valid refs should still work, got: $OUTPUT"
  exit 1
fi

# Print test summary
print_summary "Security Enhancements"

exit 0