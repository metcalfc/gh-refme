#!/bin/bash
#
# Common test utilities for gh-refme test scripts
#

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters for tracking test results
TEST_PASSED=0
TEST_FAILED=0
TEST_SKIPPED=0

# Initialize test counters
init_test_counters() {
  TEST_PASSED=0
  TEST_FAILED=0
  TEST_SKIPPED=0
}

# Print section header
print_header() {
  local title="$1"
  echo -e "\n${BLUE}===============================================${NC}"
  echo -e "${BLUE}${title}...${NC}"
  echo -e "${BLUE}===============================================${NC}"
}

# Print sub-section header
print_sub_header() {
  local title="$1"
  echo -e "\n${CYAN}-------------------------------------------${NC}"
  echo -e "${CYAN}${title}...${NC}"
  echo -e "${CYAN}-------------------------------------------${NC}"
}

# Print a test result
print_result() {
  local test_name="$1"
  local result="$2"
  local message="$3"
  
  if [[ "$result" == "pass" ]]; then
    echo -e "${GREEN}✓ PASS${NC}: $test_name"
    TEST_PASSED=$((TEST_PASSED + 1))
  elif [[ "$result" == "fail" ]]; then
    echo -e "${RED}✗ FAIL${NC}: $test_name"
    if [[ -n "$message" ]]; then
      echo -e "  ${RED}$message${NC}"
    fi
    TEST_FAILED=$((TEST_FAILED + 1))
  elif [[ "$result" == "skip" ]]; then
    echo -e "${YELLOW}⚠ SKIP${NC}: $test_name"
    if [[ -n "$message" ]]; then
      echo -e "  ${YELLOW}$message${NC}"
    fi
    TEST_SKIPPED=$((TEST_SKIPPED + 1))
  fi
}

# Print a test summary
print_summary() {
  local test_type="$1"
  
  echo -e "\n${CYAN}==========================================${NC}"
  echo -e "${CYAN}           $test_type Summary           ${NC}"
  echo -e "${CYAN}==========================================${NC}"
  echo -e "${GREEN}PASSED: $TEST_PASSED${NC}"
  echo -e "${RED}FAILED: $TEST_FAILED${NC}"
  if [[ $TEST_SKIPPED -gt 0 ]]; then
    echo -e "${YELLOW}SKIPPED: $TEST_SKIPPED${NC}"
  fi
  echo -e "${CYAN}==========================================${NC}"
  
  if [[ $TEST_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All $test_type tests passed!${NC}"
    return 0
  else
    echo -e "${RED}Some $test_type tests failed.${NC}"
    return 1
  fi
}

# Run a test script and track results
run_test() {
  local test_script="$1"
  local test_name="$2"
  
  print_header "Running $test_name"
  
  if [[ -x "$test_script" ]]; then
    # Make it executable if it's not already
    chmod +x "$test_script"
  fi
  
  if "$test_script"; then
    echo -e "\n${GREEN}✓ ${test_name} PASSED${NC}"
    return 0
  else
    echo -e "\n${RED}✗ ${test_name} FAILED${NC}"
    return 1
  fi
}

# Print a debug message (for verbose mode)
debug_msg() {
  local message="$1"
  if [[ -n "$VERBOSE" && "$VERBOSE" == "true" ]]; then
    echo -e "${YELLOW}DEBUG: $message${NC}" >&2
  fi
}

# Print a warning message
warn_msg() {
  local message="$1"
  echo -e "${YELLOW}WARNING: $message${NC}" >&2
}

# Print an error message
error_msg() {
  local message="$1"
  echo -e "${RED}ERROR: $message${NC}" >&2
}

# Print an info message
info_msg() {
  local message="$1"
  echo -e "${BLUE}INFO: $message${NC}"
}

# Print a success message
success_msg() {
  local message="$1"
  echo -e "${GREEN}$message${NC}"
}

# Validate the gh-refme script exists and is executable
validate_refme_script() {
  local script_path="$1"
  
  if [[ ! -f "$script_path" ]]; then
    error_msg "gh-refme not found at $script_path"
    return 1
  fi
  
  chmod +x "$script_path"
  return 0
}
