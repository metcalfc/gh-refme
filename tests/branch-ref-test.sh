#!/bin/bash
#
# Test script for branch reference support in gh-refme
#
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common test utilities
source "${SCRIPT_DIR}/test_utils.sh"

# Initialize test counters
init_test_counters

print_header "Branch Reference Tests"

# Get the path to the main script
REFME_SCRIPT="${SCRIPT_DIR}/../gh-refme"

# Validate the script exists and is executable
validate_refme_script "$REFME_SCRIPT" || exit 1

info_msg "Creating test workflow files..."
TEST_DIR=$(mktemp -d)
mkdir -p "$TEST_DIR/.github/workflows"

# Create test workflow with branch reference
cat > "$TEST_DIR/.github/workflows/branch-test.yml" << 'EOF'
name: Test Branch Reference

on:
  push:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@main
      - uses: actions/setup-node@master
      - name: Run tests
        run: npm test
EOF

# Create test workflow with ignore comment
cat > "$TEST_DIR/.github/workflows/ignore-test.yml" << 'EOF'
name: Test Refme Ignore

on:
  push:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      # refme: ignore
      - uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v3
      - name: Run tests
        run: npm test
EOF

# Create test workflow with mixed references
cat > "$TEST_DIR/.github/workflows/mixed-refs.yml" << 'EOF'
name: Test Mixed References

on:
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@f7e10e0  # Short hash format (7 characters)
      - uses: metcalfc/changelog-generator@main
      - uses: github/codeql-action/init@v3  # Nested package
      - name: Run tests
        run: npm test
EOF

info_msg "Testing branch reference conversion..."
# Run in dry-run mode to not modify files
output=$("$REFME_SCRIPT" convert "$TEST_DIR/.github/workflows/branch-test.yml" --dry-run 2>&1)

# Check if branch references are detected
if echo "$output" | grep -q "actions/checkout@main"; then
  print_result "Branch reference detection" "pass"
else
  print_result "Branch reference detection" "fail" "Failed to detect branch reference"
  debug_msg "Output was:\n$output"
  exit 1
fi

# Check if nested packages are handled correctly
info_msg "Testing nested package detection..."
output=$("$REFME_SCRIPT" convert "$TEST_DIR/.github/workflows/mixed-refs.yml" --dry-run 2>&1)

if echo "$output" | grep -q "Nested GitHub package detected: github/codeql-action/init@v3"; then
  print_result "Nested package detection" "pass"
else
  print_result "Nested package detection" "fail" "Failed to detect nested package format"
  debug_msg "Output was:\n$output"
  exit 1
fi

# Test refme: ignore functionality
info_msg "Testing refme: ignore functionality..."
output=$("$REFME_SCRIPT" "$TEST_DIR/.github/workflows/ignore-test.yml" --dry-run 2>&1)

# Check if the ignored reference was correctly skipped
if echo "$output" | grep -q "Skipping actions/checkout@v4 (refme: ignore)"; then
  print_result "refme: ignore feature" "pass"
else
  print_result "refme: ignore feature" "fail" "Failed to detect refme: ignore comment"
  debug_msg "Output was:\n$output"
  exit 1
fi

# Check if short hash is detected
info_msg "Testing short hash reference..."
output=$($REFME_SCRIPT convert "$TEST_DIR/.github/workflows/mixed-refs.yml" --dry-run 2>&1)
if echo "$output" | grep -q "actions/setup-node@f7e10e0"; then
  print_result "Short hash reference detection" "pass"
else
  print_result "Short hash reference detection" "fail" "Failed to detect short hash format"
  debug_msg "Output was:\n$output"
  exit 1
fi

# Test wildcard file handling
info_msg "Testing wildcard file handling..."
output=$("$REFME_SCRIPT" convert "$TEST_DIR/.github/workflows/*.yml" --dry-run 2>&1)

# Count using unique file paths, not 'Processing' lines
file_count=$(echo "$output" | grep -E "^Processing .*\.yml" | awk '{print $2}' | sort -u | wc -l | tr -d ' ')
if [ "$file_count" -eq 3 ]; then
  print_result "Wildcard file handling" "pass"
else
  print_result "Wildcard file handling" "fail" "Expected 3 files, got $file_count"
  debug_msg "Output was:\n$output"
  exit 1
fi

# Clean up
rm -rf "$TEST_DIR"

# Print test summary
print_summary "Branch Reference"
