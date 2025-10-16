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

# GitHub API configuration
readonly GITHUB_API="https://api.github.com"

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

# Sanitize environment variables to prevent injection
sanitize_environment() {
  # Clear potentially dangerous environment variables
  unset IFS
  # Ensure PATH doesn't contain current directory
  export PATH="${PATH//.:/:}"
  export PATH="${PATH#:}"
  export PATH="${PATH%:}"
  
  # Set secure umask for file creation
  umask 0077
}

# Create a secure temporary file with proper permissions
create_secure_temp_file() {
  local prefix="$1"
  local temp_file
  temp_file=$(mktemp "${TEMP_DIR}/${prefix}.XXXXXX")
  chmod 600 "$temp_file"
  echo "$temp_file"
}

# Validate file path security before processing
validate_file_path_security() {
  local file_path="$1"
  
  # Check for null bytes using tr to count them
  if [[ $(printf '%s' "$file_path" | tr -d '\0' | wc -c) -ne ${#file_path} ]]; then
    echo "ERROR: File path contains null bytes" >&2
    return 1
  fi
  
  # Check for excessively long paths
  if [[ ${#file_path} -gt 4096 ]]; then
    echo "ERROR: File path too long (>${#file_path} characters)" >&2
    return 1
  fi
  
  # Ensure we're not operating on special files (only if file exists)
  if [[ -e "$file_path" ]] && [[ -c "$file_path" || -b "$file_path" || -p "$file_path" ]]; then
    echo "ERROR: Cannot process special files (character/block/pipe)" >&2
    return 1
  fi
  
  return 0
}

# =============================================================================
# Security Functions (Existing)
# =============================================================================

# Check if string contains dangerous shell characters
has_dangerous_chars() {
  local string="$1"
  echo "$string" | grep -q '[\\$`;(){}|&<>!#]'
}

# Enhanced security validation for references
validate_reference_security() {
  local ref="$1"
  
  # Check for URL injection attempts
  if [[ "$ref" =~ https?:// ]] || [[ "$ref" =~ ftp:// ]] || [[ "$ref" =~ file:// ]]; then
    echo "ERROR: Reference contains URL schemes (potential injection)" >&2
    return 1
  fi
  
  # Check for control characters that could cause issues
  if [[ "$ref" =~ [[:cntrl:]] ]]; then
    echo "ERROR: Reference contains control characters" >&2
    return 1
  fi
  
  # Check for Unicode bidirectional override characters (security concern)
  if echo "$ref" | grep -q $'\u202e\|\u202d\|\u202a\|\u202b\|\u202c'; then
    echo "ERROR: Reference contains bidirectional text override characters" >&2
    return 1
  fi
  
  return 0
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
# GitHub API Functions
# =============================================================================

# Get GitHub token for authentication
get_github_token() {
  # First try GitHub CLI if installed
  if command_exists gh && gh auth status >/dev/null 2>&1; then
    gh auth token 2>/dev/null && return 0
  fi
  
  # Then try environment variable
  if [[ -n "${GITHUB_TOKEN}" ]]; then
    echo "${GITHUB_TOKEN}"
    return 0
  fi
  
  # Return empty if no token available
  echo ""
  return 0
}

# Make GitHub API request
github_api_request() {
  local url="$1"
  
  # Strip leading slash if present
  url="${url#/}"
  
  # Use gh api command if available (handles auth automatically)
  if command_exists gh; then
    local response
    if response=$(gh api "$url" 2>/dev/null); then
      echo "$response"
      return 0
    fi
  fi
  
  # Fallback to curl
  local token
  token=$(get_github_token)
  
  if command_exists curl; then
    if [[ -n "$token" ]]; then
      curl -s -H "Authorization: token ${token}" "${GITHUB_API}/${url}"
      return $?
    else
      curl -s "${GITHUB_API}/${url}"
      return $?
    fi
  fi
  
  error "Neither gh nor curl is available"
}

# Get commit hash for a GitHub reference
get_commit_hash() {
  local owner="$1"
  local repo="$2"
  local reference="$3"
  
  # Validate inputs using shared validation function
  validate_github_ref "$owner" "$repo" "$reference" "FATAL"
  
  # Check if reference is already a full hash (40 character hex)
  if [[ "$reference" =~ ^[0-9a-f]{40}$ ]]; then
    echo "$reference"
    return 0
  fi
  
  # Try direct commit reference (this works for branches, tags, and short hashes)
  local commit_url="repos/${owner}/${repo}/commits/${reference}"
  local commit_response
  commit_response=$(github_api_request "$commit_url")
  
  # Parse response with jq if available
  if command_exists jq && [[ -n "$commit_response" ]]; then
    local sha
    sha=$(echo "$commit_response" | jq -r '.sha' 2>/dev/null)
    if [[ "$sha" != "null" && -n "$sha" ]]; then
      echo "$sha"
      return 0
    fi
  else
    # Simple grep fallback if jq not available
    local sha
    sha=$(echo "$commit_response" | grep -o '"sha":"[0-9a-f]\{40\}"' | head -1 | cut -d'"' -f4)
    if [[ -n "$sha" ]]; then
      echo "$sha"
      return 0
    fi
  fi
  
  # If still not found, error out
  error "Could not find reference: ${reference} in ${owner}/${repo}"
}

# =============================================================================
# File Processing Functions
# =============================================================================

# Validate that a file exists and is a YAML workflow file
validate_workflow_file() {
  local file="$1"
  
  # Check if file exists
  if [[ ! -f "$file" ]]; then
    echo "File not found: $file (skipping)"
    return 1
  fi
  
  # Check file extension
  if [[ ! "$file" =~ \.(yml|yaml)$ ]]; then
    echo "Not a YAML file: $file (skipping)"
    return 1
  fi
  
  return 0
}

# Setup temporary files for processing a workflow file
setup_temp_files() {
  local file="$1"
  local temp_dir="$2"
  
  # Validate file path security
  if ! validate_file_path_security "$file"; then
    return 1
  fi
  
  # Create secure temporary files
  local temp_file
  temp_file=$(create_secure_temp_file "process_$(basename "$file" .yml)")
  cp "$file" "$temp_file"
  
  local read_file
  read_file=$(create_secure_temp_file "read_$(basename "$file" .yml)")
  cp "$file" "$read_file"
  
  # Export file paths for use by calling function
  TEMP_PROCESSING_FILE="$temp_file"
  TEMP_READ_FILE="$read_file"
}

# Process GitHub references in a workflow file
process_github_references() {
  local read_file="$1"
  local temp_file="$2"
  local original_file="$3"
  
  local line_num=0
  local ref_count=0
  local updated_count=0
  local prev_comment=""
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_num=$((line_num + 1))
    
    # Check if line is a comment
    if [[ "$line" =~ ^[[:space:]]*# ]]; then
      # Store the comment for checking "refme: ignore" in the next line
      prev_comment="$line"
      continue
    fi
    
    # Check if line contains a GitHub Action reference
    if [[ "$line" =~ uses:[[:space:]]*([^[:space:]]+) ]]; then
      local ref="${BASH_REMATCH[1]}"
      
      # Check if previous line had "refme: ignore" comment
      if [[ -n "$prev_comment" && "$prev_comment" =~ refme:[[:space:]]*ignore ]]; then
        echo "Skipping $ref (refme: ignore)"
        unset prev_comment
        continue
      fi
      
      # Increment reference counter for any reference format
      ref_count=$((ref_count + 1))
      
      # Process the reference
      if process_single_reference "$ref" "$temp_file" "$original_file" "$line_num"; then
        updated_count=$((updated_count + 1))
      fi
    fi
    
    # Clear previous comment
    unset prev_comment
    
  done < "$read_file"
  
  # Export results for calling function
  PROCESSED_REF_COUNT=$ref_count
  PROCESSED_UPDATE_COUNT=$updated_count
}

# Process a single GitHub reference
process_single_reference() {
  local ref="$1"
  local temp_file="$2"
  local original_file="$3"
  local line_num="$4"
  
  # Extract the actual line content for better debugging (computed once and reused)
  local line_content
  line_content=$(sed -n "${line_num}p" "$original_file")
  
  # Enhanced security validation first
  if ! validate_reference_security "$ref"; then
    printf '%s\n' "Line $line_num: Security validation failed for $ref (skipping)"
    return 1
  fi
  
  # Parse the GitHub reference using shared parsing function
  local parse_result
  parse_result=$(parse_github_ref "$ref"; echo $?)
  
  if [[ $parse_result -eq 1 ]]; then
    printf '%s\n' "Nested GitHub package detected: $ref (format not supported for conversion)"
    return 1
  elif [[ $parse_result -eq 0 ]]; then
    local owner="$PARSED_OWNER"
    local repo="$PARSED_REPO"
    local reference="$PARSED_REFERENCE"

    # Try to get commit hash
    local hash
    if hash=$(get_commit_hash "$owner" "$repo" "$reference" 2>/dev/null); then
      # Replace in the temp file with a comment showing the original reference
      local old_pattern="uses: ${ref}"
      local new_pattern="uses: ${owner}/${repo}@${hash} # was: ${ref}"
      
      # Check if there's already a comment - use the original file
      if grep -q "uses: ${ref} #" "$original_file"; then
        # Preserve the existing comment
        old_pattern="uses: ${ref} #"
        new_pattern="uses: ${owner}/${repo}@${hash} #"
      fi
      
      sed_in_place "$temp_file" "$old_pattern" "$new_pattern"
      
      printf '%s\n' "Line $line_num: Updated $ref -> ${owner}/${repo}@${hash}"
      printf '%s\n' "  Content: $line_content"
      return 0
    else
      printf '%s\n' "Line $line_num: Failed to get hash for $ref (skipping)"
      printf '%s\n' "  Content: $line_content"
      return 1
    fi
  else
    # Invalid reference format
    printf '%s\n' "Line $line_num: Invalid reference format: $ref (skipping)"
    printf '%s\n' "  Content: $line_content"
    return 1
  fi
}

# Securely copy file contents while preserving permissions
secure_copy_file() {
  local source_file="$1"
  local dest_file="$2"
  
  # Validate both file paths
  if ! validate_file_path_security "$source_file" || ! validate_file_path_security "$dest_file"; then
    return 1
  fi
  
  # Get original file permissions
  local orig_perms
  orig_perms=$(stat -c '%a' "$dest_file" 2>/dev/null || echo "644")
  
  # Copy content securely
  if cp "$source_file" "$dest_file"; then
    # Restore original permissions
    chmod "$orig_perms" "$dest_file"
    return 0
  else
    echo "ERROR: Failed to copy file securely" >&2
    return 1
  fi
}

# Apply changes or show diff for processed file
apply_or_show_changes() {
  local original_file="$1"
  local temp_file="$2"
  local ref_count="$3"
  local updated_count="$4"
  local dry_run="$5"
  local create_backup="$6"
  
  # Summary of changes
  if [[ $ref_count -eq 0 ]]; then
    echo "No GitHub references found in $original_file"
    return 0
  fi
  
  echo "Found $ref_count GitHub references, updated $updated_count"
  
  # Apply changes or show diff
  if [[ $updated_count -gt 0 ]]; then
    if [[ "$dry_run" == "true" ]]; then
      echo "Dry run: Not writing changes to $original_file"
      echo "Diff:"
      diff -u "$original_file" "$temp_file" || true
    else
      # Create a backup only if requested
      if [[ "$create_backup" == "true" ]]; then
        if ! secure_copy_file "$original_file" "${original_file}.bak"; then
          echo "ERROR: Failed to create secure backup" >&2
          return 1
        fi
        echo "Changes written to $original_file (backup at ${original_file}.bak)"
      else
        echo "Changes written to $original_file"
      fi
      # Copy the new content securely
      if ! secure_copy_file "$temp_file" "$original_file"; then
        echo "ERROR: Failed to apply changes securely" >&2
        return 1
      fi
    fi
  else
    echo "No changes made to $original_file"
  fi
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