#!/bin/bash
#
# Test script for branch reference support in gh-refme
#
set -e

# Set colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running tests for branch reference support...${NC}"

# Find the location of the gh-refme script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFME_SCRIPT="${SCRIPT_DIR}/../gh-refme"

if [ ! -f "$REFME_SCRIPT" ]; then
  echo -e "${RED}Error: gh-refme script not found at $REFME_SCRIPT${NC}"
  exit 1
fi

# Make sure the script is executable
chmod +x "$REFME_SCRIPT"

echo -e "${YELLOW}Creating test workflow files...${NC}"
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

echo -e "${YELLOW}Testing branch reference conversion...${NC}"
# Run in dry-run mode to not modify files
output=$("$REFME_SCRIPT" convert "$TEST_DIR/.github/workflows/branch-test.yml" --dry-run 2>&1)

# Check if branch references are detected
if echo "$output" | grep -q "actions/checkout@main"; then
  echo -e "${GREEN}✓ Branch reference detected${NC}"
else
  echo -e "${RED}✗ Failed to detect branch reference${NC}"
  echo "$output"
  exit 1
fi

# Check if nested packages are handled correctly
output=$("$REFME_SCRIPT" convert "$TEST_DIR/.github/workflows/mixed-refs.yml" --dry-run 2>&1)

if echo "$output" | grep -q "Nested GitHub package detected: github/codeql-action/init@v3"; then
  echo -e "${GREEN}✓ Nested package detection works correctly${NC}"
else
  echo -e "${RED}✗ Failed to detect nested package${NC}"
  echo "$output"
  exit 1
fi

# Check if short hash is detected
if echo "$output" | grep -q "actions/setup-node@f7e10e0"; then
  echo -e "${GREEN}✓ Short hash reference detected${NC}"
else
  echo -e "${RED}✗ Failed to detect short hash reference${NC}"
  echo "$output"
  exit 1
fi

# Test wildcard file handling
output=$("$REFME_SCRIPT" convert "$TEST_DIR/.github/workflows/*.yml" --dry-run 2>&1)

# Count using unique file paths, not 'Processing' lines
file_count=$(echo "$output" | grep -E "^Processing .*\.yml" | awk '{print $2}' | sort -u | wc -l | tr -d ' ')
if [ "$file_count" -eq 2 ]; then
  echo -e "${GREEN}✓ Wildcard file handling works correctly${NC}"
else
  echo -e "${RED}✗ Failed in wildcard file handling, expected 2 files, got $file_count${NC}"
  echo "$output"
  exit 1
fi

# Clean up
rm -rf "$TEST_DIR"

echo -e "${GREEN}All branch reference tests passed!${NC}"
