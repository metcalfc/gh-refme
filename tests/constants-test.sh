#!/bin/bash
#
# Test constants functionality for gh-refme
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

print_header "Constants Tests"

# Validate the script exists and is executable
validate_refme_script "${MAIN_SCRIPT}" || exit 1

print_sub_header "Testing constant values"

# Test 1: Verify constants are defined and have expected values
info_msg "Testing constant definitions..."

# Extract constant values from the script
MAX_OWNER_REPO=$(grep "readonly MAX_OWNER_REPO_LENGTH=" "$MAIN_SCRIPT" | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' ')
MAX_REFERENCE=$(grep "readonly MAX_REFERENCE_LENGTH=" "$MAIN_SCRIPT" | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' ')
MAX_TOTAL_REF=$(grep "readonly MAX_TOTAL_REF_LENGTH=" "$MAIN_SCRIPT" | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' ')

if [[ "$MAX_OWNER_REPO" == "50" && "$MAX_REFERENCE" == "100" && "$MAX_TOTAL_REF" == "150" ]]; then
  print_result "Constant values" "pass"
else
  print_result "Constant values" "fail" "Expected 50, 100, 150 but got $MAX_OWNER_REPO, $MAX_REFERENCE, $MAX_TOTAL_REF"
  exit 1
fi

# Test 2: Test length validation using constants
info_msg "Testing length validation with constants..."

# Test owner name too long (51 characters)
LONG_OWNER=$(printf 'a%.0s' {1..51})
OUTPUT=$("${MAIN_SCRIPT}" convert "${LONG_OWNER}/repo@v1" 2>&1 || true)

if [[ "$OUTPUT" =~ "Input too long" ]] && [[ "$OUTPUT" =~ "50 characters" ]]; then
  print_result "Owner length validation" "pass"
else
  print_result "Owner length validation" "fail" "Output was: $OUTPUT"
  exit 1
fi

# Test repo name too long (51 characters)
LONG_REPO=$(printf 'b%.0s' {1..51})
OUTPUT=$("${MAIN_SCRIPT}" convert "owner/${LONG_REPO}@v1" 2>&1 || true)

if [[ "$OUTPUT" =~ "Input too long" ]] && [[ "$OUTPUT" =~ "50 characters" ]]; then
  print_result "Repo length validation" "pass"
else
  print_result "Repo length validation" "fail" "Output was: $OUTPUT"
  exit 1
fi

# Test reference too long (101 characters)
LONG_REF=$(printf 'c%.0s' {1..101})
OUTPUT=$("${MAIN_SCRIPT}" convert "owner/repo@${LONG_REF}" 2>&1 || true)

if [[ "$OUTPUT" =~ "Input too long" ]] && [[ "$OUTPUT" =~ "100 characters" ]]; then
  print_result "Reference length validation" "pass"
else
  print_result "Reference length validation" "fail" "Output was: $OUTPUT"
  exit 1
fi

# Test total reference too long (152 characters total)  
# Create: 45-char owner + "/" + 45-char repo + "@" + 60-char ref = 152 total
# Each component is within limits but total exceeds 150
LONG_OWNER=$(printf 'o%.0s' {1..45})
LONG_REPO=$(printf 'r%.0s' {1..45}) 
LONG_REF=$(printf 'v%.0s' {1..60})
FULL_REF="${LONG_OWNER}/${LONG_REPO}@${LONG_REF}"
OUTPUT=$("${MAIN_SCRIPT}" convert "${FULL_REF}" 2>&1 || true)

if [[ "$OUTPUT" =~ "Reference too long" ]] && [[ "$OUTPUT" =~ "152" ]] && [[ "$OUTPUT" =~ "150" ]]; then
  print_result "Total reference length validation" "pass"
else
  print_result "Total reference length validation" "fail" "Output was: $OUTPUT"
  exit 1
fi

# Test 3: Test that valid lengths still work
info_msg "Testing valid lengths still work..."

# Test valid lengths (within limits)
OUTPUT=$("${MAIN_SCRIPT}" convert "actions/checkout@v4" 2>&1 || true)

if [[ "$OUTPUT" =~ "Converting actions/checkout@v4" ]]; then
  print_result "Valid reference processing" "pass"
else
  print_result "Valid reference processing" "fail" "Output was: $OUTPUT"
  exit 1
fi

# Print test summary
print_summary "Constants"

exit 0