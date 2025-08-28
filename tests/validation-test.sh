#!/bin/bash
#
# Test input validation functionality for gh-refme
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

print_header "Input Validation Tests"

# Validate the script exists and is executable
validate_refme_script "${MAIN_SCRIPT}" || exit 1

print_sub_header "Testing validation function consistency"

# Test 1: Verify both functions now use the same validation 
info_msg "Testing consistent error messages between functions..."

# Test length validation - owner too long (this will reach our validation function)
LONG_OWNER=$(printf 'a%.0s' {1..51})
OUTPUT1=$("${MAIN_SCRIPT}" convert "${LONG_OWNER}/repo@v1" 2>&1 || true)

if [[ "$OUTPUT1" =~ "Input too long" ]] && [[ "$OUTPUT1" =~ "50 characters" ]]; then
  print_result "Consistent owner length validation" "pass"
else
  print_result "Consistent owner length validation" "fail" "convert_reference output: $OUTPUT1"
  exit 1
fi

# Test repo too long
LONG_REPO=$(printf 'b%.0s' {1..51})
OUTPUT2=$("${MAIN_SCRIPT}" convert "owner/${LONG_REPO}@v1" 2>&1 || true)

if [[ "$OUTPUT2" =~ "Input too long" ]] && [[ "$OUTPUT2" =~ "50 characters" ]]; then
  print_result "Consistent repo length validation" "pass"
else
  print_result "Consistent repo length validation" "fail" "convert_reference output: $OUTPUT2"
  exit 1
fi

# Test reference too long
LONG_REF=$(printf 'c%.0s' {1..101})
OUTPUT3=$("${MAIN_SCRIPT}" convert "owner/repo@${LONG_REF}" 2>&1 || true)

if [[ "$OUTPUT3" =~ "Input too long" ]] && [[ "$OUTPUT3" =~ "100 characters" ]]; then
  print_result "Consistent reference length validation" "pass"
else
  print_result "Consistent reference length validation" "fail" "convert_reference output: $OUTPUT3"
  exit 1
fi


print_sub_header "Testing edge cases"

# Test 2: Valid inputs should still work
info_msg "Testing valid inputs still work..."

OUTPUT5=$("${MAIN_SCRIPT}" convert "actions/checkout@v4" 2>&1 || true)

if [[ "$OUTPUT5" =~ "Converting actions/checkout@v4" ]]; then
  print_result "Valid input processing" "pass"
else
  print_result "Valid input processing" "fail" "Output: $OUTPUT5"
  exit 1
fi

# Test 3: Boundary conditions
info_msg "Testing boundary conditions..."

# Test exactly at the limits (should pass)
OWNER_50=$(printf 'o%.0s' {1..50})
REPO_50=$(printf 'r%.0s' {1..50})
REF_100=$(printf 'v%.0s' {1..100})

OUTPUT6=$("${MAIN_SCRIPT}" convert "${OWNER_50}/${REPO_50}@${REF_100}" 2>&1 || true)

# This should NOT fail for length (but may fail for other reasons like repo not found)
if [[ ! "$OUTPUT6" =~ "Input too long" ]]; then
  print_result "Boundary length validation" "pass"
else
  print_result "Boundary length validation" "fail" "Should not fail length check: $OUTPUT6"
  exit 1
fi

# Print test summary
print_summary "Input Validation"

exit 0