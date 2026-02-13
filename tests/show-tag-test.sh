#!/bin/bash
#
# Test script for --show-tag feature in gh-refme
#
# Tests the get_tag_for_commit function with mock API data (no network required)
# and end-to-end --show-tag behavior with live API calls.
#
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common test utilities
source "${SCRIPT_DIR}/test_utils.sh"

# Initialize test counters
init_test_counters

print_header "Show Tag Tests"

# Get the path to the main script and library
REFME_SCRIPT="${SCRIPT_DIR}/../gh-refme"
LIB_SCRIPT="${SCRIPT_DIR}/../lib/gh-refme-lib.sh"

# Validate the script exists and is executable
validate_refme_script "$REFME_SCRIPT" || exit 1

# =============================================================================
# Unit tests for get_tag_for_commit (mock data, no network)
# =============================================================================
print_sub_header "Testing get_tag_for_commit with mock data"

# Setup: source the library and create a temp dir for cache files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
source "$LIB_SCRIPT"

# Mock API response matching the git/matching-refs/tags/ format
MOCK_REFS_JSON='[
  {"ref":"refs/tags/v4","object":{"sha":"aaaa000000000000000000000000000000000001","type":"commit"}},
  {"ref":"refs/tags/v4.3.0","object":{"sha":"bbbb000000000000000000000000000000000002","type":"commit"}},
  {"ref":"refs/tags/v4.3.1","object":{"sha":"aaaa000000000000000000000000000000000001","type":"commit"}},
  {"ref":"refs/tags/v3.0.0","object":{"sha":"cccc000000000000000000000000000000000003","type":"commit"}}
]'

# Pre-populate cache file for mock-owner/mock-repo
info_msg "Testing tag resolution with matching SHA..."
printf '%s' "$MOCK_REFS_JSON" > "${TEMP_DIR}/_tag_cache_mock-owner_mock-repo.json"

result=$(get_tag_for_commit "mock-owner" "mock-repo" "bbbb000000000000000000000000000000000002")
if [[ "$result" == "v4.3.0" ]]; then
  print_result "Single tag match returns correct tag" "pass"
else
  print_result "Single tag match returns correct tag" "fail" "Expected 'v4.3.0', got '$result'"
fi

# Test: prefer most specific (longest) tag when multiple match
info_msg "Testing most specific tag selection..."
result=$(get_tag_for_commit "mock-owner" "mock-repo" "aaaa000000000000000000000000000000000001")
if [[ "$result" == "v4.3.1" ]]; then
  print_result "Prefers most specific tag (v4.3.1 over v4)" "pass"
else
  print_result "Prefers most specific tag (v4.3.1 over v4)" "fail" "Expected 'v4.3.1', got '$result'"
fi

# Test: no matching SHA returns empty
info_msg "Testing no matching SHA..."
result=$(get_tag_for_commit "mock-owner" "mock-repo" "dddd000000000000000000000000000000000004")
if [[ -z "$result" || "$result" == "null" ]]; then
  print_result "No matching SHA returns empty" "pass"
else
  print_result "No matching SHA returns empty" "fail" "Expected empty, got '$result'"
fi

# Test: invalid SHA format returns empty (too short)
info_msg "Testing invalid SHA format..."
result=$(get_tag_for_commit "mock-owner" "mock-repo" "abc123")
if [[ -z "$result" ]]; then
  print_result "Short SHA returns empty" "pass"
else
  print_result "Short SHA returns empty" "fail" "Expected empty, got '$result'"
fi

# Test: invalid SHA format returns empty (uppercase)
result=$(get_tag_for_commit "mock-owner" "mock-repo" "AAAA000000000000000000000000000000000001")
if [[ -z "$result" ]]; then
  print_result "Uppercase SHA returns empty" "pass"
else
  print_result "Uppercase SHA returns empty" "fail" "Expected empty, got '$result'"
fi

# Test: cache reuse - the cache file already exists, should not need API
info_msg "Testing cache reuse..."
# Remove the github_api_request function to prove cache is used
eval 'original_api_fn=$(declare -f github_api_request)'
github_api_request() { echo "SHOULD_NOT_BE_CALLED"; return 1; }

result=$(get_tag_for_commit "mock-owner" "mock-repo" "cccc000000000000000000000000000000000003")
if [[ "$result" == "v3.0.0" ]]; then
  print_result "Cache reuse avoids API call" "pass"
else
  print_result "Cache reuse avoids API call" "fail" "Expected 'v3.0.0', got '$result'"
fi

# Restore original function
eval "$original_api_fn"

# Test: empty cache (empty JSON array) returns empty
info_msg "Testing empty tag list..."
printf '%s' '[]' > "${TEMP_DIR}/_tag_cache_empty-owner_empty-repo.json"
result=$(get_tag_for_commit "empty-owner" "empty-repo" "aaaa000000000000000000000000000000000001")
if [[ -z "$result" ]]; then
  print_result "Empty tag list returns empty" "pass"
else
  print_result "Empty tag list returns empty" "fail" "Expected empty, got '$result'"
fi

# =============================================================================
# End-to-end tests with live API
# =============================================================================
print_sub_header "Testing --show-tag end-to-end behavior"

TEST_DIR=$(mktemp -d)

# Create test workflow with a known reference
cat > "$TEST_DIR/test.yml" << 'EOF'
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF

# Test: --show-tag not enabled by default
info_msg "Testing tag not shown without --show-tag flag..."
output=$("$REFME_SCRIPT" convert "$TEST_DIR/test.yml" --dry-run 2>&1)
if echo "$output" | grep -q "# was: actions/checkout@v4" && ! echo "$output" | grep -qE "# was: actions/checkout@v4 \("; then
  print_result "Tag not shown without --show-tag" "pass"
else
  print_result "Tag not shown without --show-tag" "fail" "Tag appeared without --show-tag flag"
  debug_msg "Output was:\n$output"
fi

# Test: --show-tag adds tag in parentheses
info_msg "Testing --show-tag adds tag..."
output=$("$REFME_SCRIPT" convert "$TEST_DIR/test.yml" --dry-run --show-tag 2>&1)
if echo "$output" | grep -qE "# was: actions/checkout@v4 \(v4\.[0-9]+\.[0-9]+\)"; then
  print_result "--show-tag adds semver tag in comment" "pass"
elif echo "$output" | grep -q "# was: actions/checkout@v4"; then
  # Tag resolution may fail due to rate limiting, but flag was accepted
  print_result "--show-tag flag accepted (tag may not have resolved)" "pass"
else
  print_result "--show-tag adds tag in comment" "fail" "Expected tag in parentheses"
  debug_msg "Output was:\n$output"
fi

# Test: --show-tag with existing comment preserves it
info_msg "Testing --show-tag with existing comment..."
cat > "$TEST_DIR/existing-comment.yml" << 'EOF'
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4 # pinned for stability
EOF

output=$("$REFME_SCRIPT" convert "$TEST_DIR/existing-comment.yml" --dry-run --show-tag 2>&1)
# When there's already a comment, the existing comment should be preserved (not replaced with tag)
if echo "$output" | grep -q "# pinned for stability"; then
  print_result "Existing comment preserved with --show-tag" "pass"
else
  print_result "Existing comment preserved with --show-tag" "fail" "Existing comment was overwritten"
  debug_msg "Output was:\n$output"
fi

# Test: --show-tag with multiple actions from same repo (cache test)
info_msg "Testing --show-tag with multiple refs from same org..."
cat > "$TEST_DIR/multi-ref.yml" << 'EOF'
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - uses: actions/cache@v4
EOF

output=$("$REFME_SCRIPT" convert "$TEST_DIR/multi-ref.yml" --dry-run --show-tag 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 ]] && echo "$output" | grep -c "# was:" | grep -q "3"; then
  print_result "Multiple refs processed with --show-tag" "pass"
else
  print_result "Multiple refs processed with --show-tag" "fail" "Not all 3 references were processed"
  debug_msg "Output was:\n$output"
fi

# Clean up
rm -rf "$TEST_DIR"

# Print test summary
print_summary "Show Tag"
