#!/bin/bash
#
# Unit tests for the security validation and escaping helpers in gh-refme-lib.sh
#
# shellcheck disable=SC2016  # single-quoted $(...) strings are intentional injection payloads
# shellcheck disable=SC2088  # literal ~ (unexpanded) is exactly what has_path_traversal must catch
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_utils.sh"
source "${SCRIPT_DIR}/../lib/gh-refme-lib.sh"

init_test_counters

print_header "Validator Unit Tests"

# =============================================================================
# is_safe_name
# =============================================================================
print_sub_header "Testing is_safe_name"

for name in "actions" "my-repo" "my_repo" "repo.name" "v4.5.0" "0abc"; do
  if is_safe_name "$name"; then
    print_result "is_safe_name accepts '$name'" "pass"
  else
    print_result "is_safe_name accepts '$name'" "fail" "Expected accept"
  fi
done

for name in "" "owner/repo" "a;b" "a b" 'a$(id)' "a|b" 'a`id`'; do
  if is_safe_name "$name"; then
    print_result "is_safe_name rejects '$name'" "fail" "Expected reject"
  else
    print_result "is_safe_name rejects '$name'" "pass"
  fi
done

# =============================================================================
# has_dangerous_chars
# =============================================================================
print_sub_header "Testing has_dangerous_chars"

for str in 'a$(id)' "a;b" 'a`id`' "a|b" "a&b" "a>b" "a<b" "a#b" "a!b" 'a\b' "a(b" "a{b"; do
  if has_dangerous_chars "$str"; then
    print_result "has_dangerous_chars detects '$str'" "pass"
  else
    print_result "has_dangerous_chars detects '$str'" "fail" "Expected detection"
  fi
done

for str in "v4.5.0" "main" "feature/branch" "release-1.0_rc2"; do
  if has_dangerous_chars "$str"; then
    print_result "has_dangerous_chars passes '$str'" "fail" "Expected clean"
  else
    print_result "has_dangerous_chars passes '$str'" "pass"
  fi
done

# =============================================================================
# has_path_traversal
# =============================================================================
print_sub_header "Testing has_path_traversal"

for path in "../etc/passwd" "a/../b" "~/secrets" "workflow~.yml"; do
  if has_path_traversal "$path"; then
    print_result "has_path_traversal detects '$path'" "pass"
  else
    print_result "has_path_traversal detects '$path'" "fail" "Expected detection"
  fi
done

for path in ".github/workflows/ci.yml" "workflow.yml" "./relative/path.yml"; do
  if has_path_traversal "$path"; then
    print_result "has_path_traversal passes '$path'" "fail" "Expected clean"
  else
    print_result "has_path_traversal passes '$path'" "pass"
  fi
done

# =============================================================================
# validate_github_ref
# =============================================================================
print_sub_header "Testing validate_github_ref"

if validate_github_ref "actions" "checkout" "v4" 2>/dev/null; then
  print_result "validate_github_ref accepts actions/checkout@v4" "pass"
else
  print_result "validate_github_ref accepts actions/checkout@v4" "fail" "Expected accept"
fi

if validate_github_ref "evil;owner" "checkout" "v4" 2>/dev/null; then
  print_result "validate_github_ref rejects dangerous owner" "fail" "Expected reject"
else
  print_result "validate_github_ref rejects dangerous owner" "pass"
fi

if validate_github_ref "actions" 'repo$(id)' "v4" 2>/dev/null; then
  print_result "validate_github_ref rejects dangerous repo" "fail" "Expected reject"
else
  print_result "validate_github_ref rejects dangerous repo" "pass"
fi

if validate_github_ref "actions" "checkout" 'v4$(id)' 2>/dev/null; then
  print_result "validate_github_ref rejects dangerous reference" "fail" "Expected reject"
else
  print_result "validate_github_ref rejects dangerous reference" "pass"
fi

LONG_OWNER=$(printf 'a%.0s' $(seq 1 $((MAX_OWNER_REPO_LENGTH + 1))))
if validate_github_ref "$LONG_OWNER" "checkout" "v4" 2>/dev/null; then
  print_result "validate_github_ref rejects overlong owner" "fail" "Expected reject"
else
  print_result "validate_github_ref rejects overlong owner" "pass"
fi

LONG_REF=$(printf 'a%.0s' $(seq 1 $((MAX_REFERENCE_LENGTH + 1))))
if validate_github_ref "actions" "checkout" "$LONG_REF" 2>/dev/null; then
  print_result "validate_github_ref rejects overlong reference" "fail" "Expected reject"
else
  print_result "validate_github_ref rejects overlong reference" "pass"
fi

# =============================================================================
# validate_reference_security
# =============================================================================
print_sub_header "Testing validate_reference_security"

if validate_reference_security "v4.5.0" 2>/dev/null; then
  print_result "validate_reference_security accepts clean ref" "pass"
else
  print_result "validate_reference_security accepts clean ref" "fail" "Expected accept"
fi

for ref in "https://evil.com/x" "ftp://evil.com/x" "file:///etc/passwd"; do
  if validate_reference_security "$ref" 2>/dev/null; then
    print_result "validate_reference_security rejects '$ref'" "fail" "Expected reject"
  else
    print_result "validate_reference_security rejects '$ref'" "pass"
  fi
done

CTRL_REF=$(printf 'v4\001x')
if validate_reference_security "$CTRL_REF" 2>/dev/null; then
  print_result "validate_reference_security rejects control characters" "fail" "Expected reject"
else
  print_result "validate_reference_security rejects control characters" "pass"
fi

# U+202E RIGHT-TO-LEFT OVERRIDE as UTF-8 bytes (works on bash 3.2 and later)
BIDI_REF=$(printf 'v4\342\200\256evil')
if validate_reference_security "$BIDI_REF" 2>/dev/null; then
  print_result "validate_reference_security rejects bidi override chars" "fail" "Expected reject"
else
  print_result "validate_reference_security rejects bidi override chars" "pass"
fi

# =============================================================================
# is_valid_cli_ref
# =============================================================================
print_sub_header "Testing is_valid_cli_ref"

if is_valid_cli_ref "actions/checkout@v4"; then
  print_result "is_valid_cli_ref accepts owner/repo@ref" "pass"
else
  print_result "is_valid_cli_ref accepts owner/repo@ref" "fail" "Expected accept"
fi

for ref in "actions/checkout" "github/codeql-action/init@v3" "actions checkout@v4" "@v4"; do
  if is_valid_cli_ref "$ref"; then
    print_result "is_valid_cli_ref rejects '$ref'" "fail" "Expected reject"
  else
    print_result "is_valid_cli_ref rejects '$ref'" "pass"
  fi
done

# =============================================================================
# validate_file_path_security
# =============================================================================
print_sub_header "Testing validate_file_path_security"

if validate_file_path_security "workflow.yml" 2>/dev/null; then
  print_result "validate_file_path_security accepts normal path" "pass"
else
  print_result "validate_file_path_security accepts normal path" "fail" "Expected accept"
fi

LONG_PATH=$(printf 'a%.0s' $(seq 1 5000))
if validate_file_path_security "$LONG_PATH" 2>/dev/null; then
  print_result "validate_file_path_security rejects overlong path" "fail" "Expected reject"
else
  print_result "validate_file_path_security rejects overlong path" "pass"
fi

if validate_file_path_security "/dev/null" 2>/dev/null; then
  print_result "validate_file_path_security rejects character device" "fail" "Expected reject"
else
  print_result "validate_file_path_security rejects character device" "pass"
fi

# =============================================================================
# sed escaping helpers
# =============================================================================
print_sub_header "Testing sed escaping helpers"

if [[ "$(escape_sed_pattern 'a.b*c')" == 'a\.b\*c' ]]; then
  print_result "escape_sed_pattern escapes . and *" "pass"
else
  print_result "escape_sed_pattern escapes . and *" "fail" "Got: $(escape_sed_pattern 'a.b*c')"
fi

if [[ "$(escape_sed_pattern '$x^y[z')" == '\$x\^y\[z' ]]; then
  print_result "escape_sed_pattern escapes \$ ^ [" "pass"
else
  print_result "escape_sed_pattern escapes \$ ^ [" "fail" "Got: $(escape_sed_pattern '$x^y[z')"
fi

if [[ "$(escape_sed_replacement 'a&b')" == 'a\&b' ]]; then
  print_result "escape_sed_replacement escapes &" "pass"
else
  print_result "escape_sed_replacement escapes &" "fail" "Got: $(escape_sed_replacement 'a&b')"
fi

if [[ "$(escape_sed_replacement 'a|b')" == 'a\|b' ]]; then
  print_result "escape_sed_replacement escapes | (sed delimiter)" "pass"
else
  print_result "escape_sed_replacement escapes | (sed delimiter)" "fail" "Got: $(escape_sed_replacement 'a|b')"
fi

# =============================================================================
# Summary
# =============================================================================
print_summary "Validator"
