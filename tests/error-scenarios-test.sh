#!/bin/bash
#
# Comprehensive error scenario tests for gh-refme
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

print_header "Error Scenario Tests"

# Validate the script exists and is executable
validate_refme_script "${MAIN_SCRIPT}" || exit 1

# Create temporary test directory
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

print_sub_header "Testing GitHub API failure scenarios"

# Test 1: Non-existent repository - use a better test case
info_msg "Testing non-existent repository error handling..."
if timeout 10s "${MAIN_SCRIPT}" convert "definitely-does-not-exist-12345/nonexistent-repo-67890@v1" >/dev/null 2>&1; then
  print_result "Non-existent repository handling" "fail" "Expected command to fail but it succeeded"
  exit 1
else
  print_result "Non-existent repository handling" "pass"
fi

# Test 2: Invalid reference format - test file vs reference detection
info_msg "Testing invalid reference format error handling..."
OUTPUT=$("${MAIN_SCRIPT}" convert "not-a-file.txt" 2>&1 || true)

# Should handle as file (not found) rather than crashing
if [[ "$OUTPUT" =~ "File not found" ]] && [[ "$OUTPUT" =~ "skipping" ]]; then
  print_result "Invalid reference format handling" "pass"
else
  print_result "Invalid reference format handling" "fail" "Expected file not found message, got: $OUTPUT"
  exit 1
fi

# Test 3: Non-existent tag/branch
info_msg "Testing non-existent tag/branch error handling..."
if timeout 10s "${MAIN_SCRIPT}" convert "actions/checkout@nonexistent-tag-xyz-12345" >/dev/null 2>&1; then
  print_result "Non-existent tag handling" "fail" "Expected command to fail but it succeeded"
  exit 1
else
  print_result "Non-existent tag handling" "pass"
fi

print_sub_header "Testing file system error scenarios"

# Test 4: Non-existent file
info_msg "Testing non-existent file error handling..."
OUTPUT=$("${MAIN_SCRIPT}" "/nonexistent/path/file.yml" 2>&1 || true)

if [[ "$OUTPUT" =~ "File not found" ]] || [[ "$OUTPUT" =~ "skipping" ]]; then
  print_result "Non-existent file handling" "pass"
else
  print_result "Non-existent file handling" "fail" "Expected file not found message, got: $OUTPUT"
  exit 1
fi

# Test 5: Permission denied simulation (create read-only directory)
info_msg "Testing permission handling..."
READONLY_DIR="${TEST_DIR}/readonly"
mkdir -p "$READONLY_DIR"
echo "uses: actions/checkout@v4" > "${READONLY_DIR}/test.yml"
chmod 444 "${READONLY_DIR}/test.yml"  # Read-only file

# Try to process the read-only file
OUTPUT=$("${MAIN_SCRIPT}" "${READONLY_DIR}/test.yml" 2>&1 || true)

# This should either handle gracefully or show appropriate error
if [[ "$OUTPUT" =~ "Processing" ]] || [[ "$OUTPUT" =~ "permission" ]] || [[ "$OUTPUT" =~ "No changes made" ]]; then
  print_result "Permission handling" "pass"
else
  print_result "Permission handling" "fail" "Unexpected output: $OUTPUT"
  exit 1
fi

# Test 6: Non-YAML file extension
info_msg "Testing non-YAML file handling..."
echo "not yaml content" > "${TEST_DIR}/test.txt"
OUTPUT=$("${MAIN_SCRIPT}" "${TEST_DIR}/test.txt" 2>&1 || true)

if [[ "$OUTPUT" =~ "Not a YAML file" ]] || [[ "$OUTPUT" =~ "skipping" ]]; then
  print_result "Non-YAML file handling" "pass"
else
  print_result "Non-YAML file handling" "fail" "Expected YAML file message, got: $OUTPUT"
  exit 1
fi

print_sub_header "Testing malformed YAML scenarios"

# Test 7: Empty file
info_msg "Testing empty YAML file handling..."
touch "${TEST_DIR}/empty.yml"
OUTPUT=$("${MAIN_SCRIPT}" "${TEST_DIR}/empty.yml" 2>&1 || true)

if [[ "$OUTPUT" =~ "No GitHub references found" ]] || [[ "$OUTPUT" =~ "Processing" ]]; then
  print_result "Empty file handling" "pass"
else
  print_result "Empty file handling" "fail" "Unexpected output: $OUTPUT"
  exit 1
fi

# Test 8: YAML with no 'uses' statements
info_msg "Testing YAML without GitHub references..."
cat > "${TEST_DIR}/no-uses.yml" << 'EOF'
name: Test Workflow
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Test step
        run: echo "hello world"
EOF

OUTPUT=$("${MAIN_SCRIPT}" "${TEST_DIR}/no-uses.yml" 2>&1 || true)

if [[ "$OUTPUT" =~ "No GitHub references found" ]] || [[ "$OUTPUT" =~ "Processing" ]]; then
  print_result "No references file handling" "pass"
else
  print_result "No references file handling" "fail" "Unexpected output: $OUTPUT"
  exit 1
fi

# Test 9: Corrupted/invalid YAML structure
info_msg "Testing corrupted YAML handling..."
cat > "${TEST_DIR}/corrupted.yml" << 'EOF'
name: Test Workflow
on: [push
jobs:
  test:
    runs-on: ubuntu-latest
    steps
      - uses: actions/checkout@v4
      - name: Broken
        run: echo "test"
EOF

OUTPUT=$("${MAIN_SCRIPT}" "${TEST_DIR}/corrupted.yml" 2>&1 || true)

# Should still process the 'uses:' line even if YAML is malformed
if [[ "$OUTPUT" =~ "Processing" ]] || [[ "$OUTPUT" =~ "Converting" ]] || [[ "$OUTPUT" =~ "actions/checkout" ]]; then
  print_result "Corrupted YAML handling" "pass"
else
  print_result "Corrupted YAML handling" "fail" "Should still process uses: lines, got: $OUTPUT"
  exit 1
fi

print_sub_header "Testing edge cases and boundary conditions"

# Test 10: File with only comments
info_msg "Testing file with only comments..."
cat > "${TEST_DIR}/comments-only.yml" << 'EOF'
# This is a comment file
# uses: actions/checkout@v4  (this is in a comment)
# More comments
EOF

OUTPUT=$("${MAIN_SCRIPT}" "${TEST_DIR}/comments-only.yml" 2>&1 || true)

if [[ "$OUTPUT" =~ "No GitHub references found" ]] || [[ "$OUTPUT" =~ "Processing" ]]; then
  print_result "Comments-only file handling" "pass"
else
  print_result "Comments-only file handling" "fail" "Should ignore commented uses:, got: $OUTPUT"
  exit 1
fi

# Test 11: Mixed valid and invalid references in same file
info_msg "Testing mixed valid/invalid references..."
cat > "${TEST_DIR}/mixed.yml" << 'EOF'
name: Mixed Test
on: [push]
jobs:
  test:
    steps:
      - uses: actions/checkout@v4           # Valid
      - uses: invalid-format                # Invalid
      - uses: nonexistent/repo@v1          # Valid format, but repo doesn't exist
      - uses: actions/setup-node@v3        # Valid
EOF

OUTPUT=$("${MAIN_SCRIPT}" "${TEST_DIR}/mixed.yml" --dry-run 2>&1 || true)

# Should process valid ones and skip/error on invalid ones
if [[ "$OUTPUT" =~ "actions/checkout" ]] && [[ "$OUTPUT" =~ "actions/setup-node" ]]; then
  print_result "Mixed references handling" "pass"
else
  print_result "Mixed references handling" "fail" "Should process valid refs, got: $OUTPUT"
  exit 1
fi

# Test 12: Very large file (stress test)
info_msg "Testing large file handling..."
LARGE_FILE="${TEST_DIR}/large.yml"
echo "name: Large Test" > "$LARGE_FILE"
echo "on: [push]" >> "$LARGE_FILE"
echo "jobs:" >> "$LARGE_FILE"
echo "  test:" >> "$LARGE_FILE"
echo "    steps:" >> "$LARGE_FILE"

# Add 100 uses statements
for i in {1..100}; do
  echo "      - uses: actions/checkout@v4  # Entry $i" >> "$LARGE_FILE"
done

OUTPUT=$("${MAIN_SCRIPT}" "$LARGE_FILE" --dry-run 2>&1 || true)

if [[ "$OUTPUT" =~ "Found 100 GitHub references" ]] && [[ "$OUTPUT" =~ "Processing" ]]; then
  print_result "Large file handling" "pass"
else
  print_result "Large file handling" "fail" "Should handle 100 references, got: $OUTPUT"
  exit 1
fi

# Test 13: Directory without .github/workflows
info_msg "Testing directory without workflows..."
EMPTY_DIR="${TEST_DIR}/empty-dir"
mkdir -p "$EMPTY_DIR"

OUTPUT=$("${MAIN_SCRIPT}" "$EMPTY_DIR" 2>&1 || true)

if [[ "$OUTPUT" =~ "No GitHub" ]] || [[ "$OUTPUT" =~ "workflows directory" ]] || [[ "$OUTPUT" =~ "ERROR" ]]; then
  print_result "Empty directory handling" "pass"
else
  print_result "Empty directory handling" "fail" "Should error on no workflows dir, got: $OUTPUT"
  exit 1
fi

# Test 14: Wildcard with no matching files
info_msg "Testing wildcard with no matches..."
OUTPUT=$("${MAIN_SCRIPT}" "${TEST_DIR}/nonexistent*.yml" 2>&1 || true)

# Should handle gracefully when wildcard matches nothing
if ! [[ "$OUTPUT" =~ "ERROR" ]]; then
  print_result "Empty wildcard handling" "pass"
else
  print_result "Empty wildcard handling" "fail" "Should handle empty wildcard gracefully, got: $OUTPUT"
  exit 1
fi

# Print test summary
print_summary "Error Scenarios"

exit 0