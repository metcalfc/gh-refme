#!/bin/bash
#
# Test that parse_github_ref properly sets global variables
# Regression test for: https://github.com/metcalfc/gh-refme/pull/10
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_utils.sh"
source "${SCRIPT_DIR}/../lib/gh-refme-lib.sh"

init_test_counters

print_header "parse_github_ref Global Variables Tests"

print_sub_header "Testing globals are set in caller's context"

# Clear any existing values
PARSED_OWNER=""
PARSED_REPO=""
PARSED_REFERENCE=""

# Call parse_github_ref directly (not in a subshell)
parse_github_ref "actions/checkout@v4"
parse_result=$?

# Verify the globals were set
if [[ "$parse_result" -eq 0 ]] && \
   [[ "$PARSED_OWNER" == "actions" ]] && \
   [[ "$PARSED_REPO" == "checkout" ]] && \
   [[ "$PARSED_REFERENCE" == "v4" ]]; then
  print_result "Globals set correctly after parse_github_ref" "pass"
else
  print_result "Globals set correctly after parse_github_ref" "fail" \
    "Expected: owner=actions, repo=checkout, ref=v4. Got: owner=$PARSED_OWNER, repo=$PARSED_REPO, ref=$PARSED_REFERENCE, result=$parse_result"
  exit 1
fi

# Test nested package detection (returns 1)
PARSED_OWNER=""
PARSED_REPO=""
PARSED_REFERENCE=""

parse_result=0
parse_github_ref "github/codeql-action/init@v3" || parse_result=$?

if [[ "$parse_result" -eq 1 ]]; then
  print_result "Nested package correctly returns 1" "pass"
else
  print_result "Nested package correctly returns 1" "fail" "Expected return code 1, got $parse_result"
  exit 1
fi

# Test invalid format (returns 2)
parse_result=0
parse_github_ref "invalid-format" || parse_result=$?

if [[ "$parse_result" -eq 2 ]]; then
  print_result "Invalid format correctly returns 2" "pass"
else
  print_result "Invalid format correctly returns 2" "fail" "Expected return code 2, got $parse_result"
  exit 1
fi

# Test that a subshell pattern would FAIL (documents the anti-pattern)
print_sub_header "Documenting subshell anti-pattern"

PARSED_OWNER=""
PARSED_REPO=""
PARSED_REFERENCE=""

# This is the WRONG way - subshell loses globals
# DO NOT use: result=$(parse_github_ref "..."; echo $?)
_=$(parse_github_ref "actions/checkout@v4")

if [[ -z "$PARSED_OWNER" ]]; then
  print_result "Subshell correctly loses globals (expected behavior)" "pass"
else
  print_result "Subshell correctly loses globals" "fail" "Globals should be empty in subshell pattern"
  exit 1
fi

print_summary "parse_github_ref Globals"
exit 0
