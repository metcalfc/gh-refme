#!/bin/bash
#
# gh-refme-lib.sh - Shared library functions for gh-refme
#
# This library contains reusable functions for GitHub reference processing,
# validation, and parsing that can be shared between the main script and tests.
#

# Security and validation constants
readonly MAX_OWNER_REPO_LENGTH=50       # Maximum length for owner and repo names
readonly MAX_REFERENCE_LENGTH=100       # Maximum length for git references
readonly MAX_TOTAL_REF_LENGTH=150       # Maximum length for complete reference strings

# =============================================================================
# Helper Functions
# =============================================================================

# Print error message and exit (used by validation functions)
error() {
  echo "ERROR: $1" >&2
  exit 1
}

# =============================================================================
# Security Functions
# =============================================================================

# Check if string contains dangerous shell characters
has_dangerous_chars() {
  local string="$1"
  echo "$string" | grep -q '[\\$`;(){}|&<>!#]'
}

# Check if string contains path traversal patterns
# Used in the main function when validating file paths
has_path_traversal() {
  local path="$1"
  if [[ "$path" == *..* || "$path" == *~* ]]; then
    return 0  # Path contains traversal pattern
  else
    return 1  # Path is clean
  fi
}

# Validate input string matches safe pattern
is_safe_name() {
  local string="$1"
  [[ "$string" =~ ^[a-zA-Z0-9_.-]+$ ]]
}

# Validate GitHub reference components (owner, repo, reference)
validate_github_ref() {
  local owner="$1"
  local repo="$2"
  local reference="$3"
  local error_prefix="${4:-ERROR}" # Default to "ERROR", can be customized
  
  # Validate owner format
  if ! is_safe_name "$owner"; then
    if [[ "$error_prefix" == "ERROR" ]]; then
      echo "ERROR: Invalid owner format: $owner (only alphanumeric, underscore, dot and dash allowed)" >&2
      return 1
    else
      error "Invalid owner format: $owner (only alphanumeric, underscore, dot and dash allowed)"
    fi
  fi
  
  # Validate repository format
  if ! is_safe_name "$repo"; then
    if [[ "$error_prefix" == "ERROR" ]]; then
      echo "ERROR: Invalid repository format: $repo (only alphanumeric, underscore, dot and dash allowed)" >&2
      return 1
    else
      error "Invalid repository format: $repo (only alphanumeric, underscore, dot and dash allowed)"
    fi
  fi
  
  # Check for potentially dangerous characters in reference
  if has_dangerous_chars "$reference"; then
    if [[ "$error_prefix" == "ERROR" ]]; then
      echo "ERROR: Invalid reference: $reference (contains potentially dangerous characters)" >&2
      return 1
    else
      error "Invalid reference: $reference (contains potentially dangerous characters)"
    fi
  fi
  
  # Check for excessively long inputs (prevent DoS)
  if [[ ${#owner} -gt $MAX_OWNER_REPO_LENGTH || ${#repo} -gt $MAX_OWNER_REPO_LENGTH || ${#reference} -gt $MAX_REFERENCE_LENGTH ]]; then
    if [[ "$error_prefix" == "ERROR" ]]; then
      echo "ERROR: Input too long. Owner and repo must be less than $MAX_OWNER_REPO_LENGTH characters, and reference less than $MAX_REFERENCE_LENGTH characters." >&2
      return 1
    else
      error "Input too long. Owner and repo must be less than $MAX_OWNER_REPO_LENGTH characters, and reference less than $MAX_REFERENCE_LENGTH characters."
    fi
  fi
  
  return 0
}

# =============================================================================
# Reference Parsing Functions
# =============================================================================

# Parse GitHub reference into components (owner, repo, reference)
# Returns: 0 for standard format, 1 for nested format, 2 for invalid format
# Sets global variables: PARSED_OWNER, PARSED_REPO, PARSED_REFERENCE
parse_github_ref() {
  local ref="$1"
  
  # Clear previous values
  PARSED_OWNER=""
  PARSED_REPO=""
  PARSED_REFERENCE=""
  
  # Check for nested package references first (e.g., github/codeql-action/init@v3)
  if [[ "$ref" =~ ^([a-zA-Z0-9_.-]+)/([a-zA-Z0-9_.-]+)/([a-zA-Z0-9_.-]+)@([a-zA-Z0-9_.-]+)$ ]]; then
    # Nested format detected - not supported for conversion
    return 1
  # Check for standard reference format (owner/repo@ref)
  elif [[ "$ref" =~ ^([a-zA-Z0-9_.-]+)/([a-zA-Z0-9_.-]+)@([a-zA-Z0-9_.-]+)$ ]]; then
    # Standard format - capture matches immediately
    local owner="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    local reference="${BASH_REMATCH[3]}"
    PARSED_OWNER="$owner"
    PARSED_REPO="$repo"
    PARSED_REFERENCE="$reference"
    return 0
  # Check for looser format validation (used in convert_reference)
  elif [[ "$ref" =~ ^([^/]+)/([^@]+)@(.+)$ ]]; then
    # Looser format - allows more characters but still basic structure - capture matches immediately
    local owner="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    local reference="${BASH_REMATCH[3]}"
    PARSED_OWNER="$owner"
    PARSED_REPO="$repo"
    PARSED_REFERENCE="$reference"
    return 0
  else
    # Invalid format
    PARSED_OWNER=""
    PARSED_REPO=""
    PARSED_REFERENCE=""
    return 2
  fi
}

# Check if reference matches the strict pattern used for command-line detection
is_valid_cli_ref() {
  local ref="$1"
  [[ "$ref" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+@[a-zA-Z0-9_.-]+$ ]]
}

# =============================================================================
# Utility Functions
# =============================================================================

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Create a valid sed in-place edit command (compatible with BSD and GNU sed)
sed_in_place() {
  local file="$1"
  local pattern="$2"
  local replacement="$3"
  
  # Remove any trailing newlines from pattern and replacement
  pattern=$(echo -n "$pattern" | tr -d '\n')
  replacement=$(echo -n "$replacement" | tr -d '\n')
  
  # Check if we're using BSD or GNU sed
  if sed --version 2>/dev/null | grep -q "GNU"; then
    # GNU sed
    sed -i "s|$pattern|$replacement|g" "$file"
  else
    # BSD sed (macOS)
    sed -i '' "s|$pattern|$replacement|g" "$file"
  fi
}