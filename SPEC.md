This document outlines the specification for the GitHub RefMe tool.

## Overview

GitHub RefMe is a command-line tool designed to help developers manage and update references in their GitHub Action Workflows. It converts git references (tags, branches, short commits, etc.) into fully qualified references (full commit hashes) for use in GitHub Actions.

## Flow

1. Takes one or more GitHub Action yaml files as input.
2. In the case of zero arguments, it will print the usage information.
3. Loops through the files, reading the contents. 
    * It will skip files that do not exist. 
    * It will also skip files that are not yaml files. 
    * Reads the references from the workflow files, creating a list of references.
4. Loops through the references, processing each one. 
    * Tests the references against security checks (github token leakage, path traversal, special characters outside of the allowed github repo name character set).
    * Skips if already a 40 character git commit hash.
5. Converts the references to fully qualified references using the GitHub API.
 - If gh is available use that:
    * short hash: gh api "repos/metcalfc/changelog-generator/commits/561668d" --jq .sha
    * tag: gh api "repos/metcalfc/changelog-generator/commits/v4.5.0" --jq .sha
    * branch: gh api "repos/metcalfc/changelog-generator/commits/main" --jq .sha
    * full hash: gh api "repos/metcalfc/changelog-generator/commits/561668d6c9ddae84ded9a44d74fde71353f1b9c0" --jq .sha
- Otherwise fall back to curl/jq:
    * short hash: curl -s https://api.github.com/repos/metcalfc/changelog-generator/commits/561668d | jq -r .sha
    * tag: curl -s https://api.github.com/repos/metcalfc/changelog-generator/commits/v4.5.0 | jq -r .sha
    * branch: curl -s https://api.github.com/repos/metcalfc/changelog-generator/commits/main | jq -r .sha
    * full hash: curl -s https://api.github.com/repos/metcalfc/changelog-generator/commits/561668d6c9ddae84ded9a44d74fde71353f1b9c0 | jq -r .sha
6. If dry-run is enabled, it prints the resulting diff to the console.
7. if dry-run is not enabled, it updates the workflow files with the new references.

## Usage

The tool can be used in the following ways:
    * Standalone script (gh-refme)
    * GitHub Action (uses the standalone script)
    * NPM package (uses the standalone script)
    * GitHub CLI extension (gh extension install github.com/metcalfc/gh-refme) which is the same as the standalone script, except the cmd name is `gh refme`.

## Guidelines

* The tool should be written in bash.
* The tool should be cross-platform (Linux, macOS).
* The tool should be easy to install and use.
* The tool should be easy to extend and modify.
* The tool should be easy to test.
* The tool should be easy to document.
* The tool should be easy to maintain.
* The tool should be easy to test in a CI/CD pipeline.
* The tool should be easy to use in a GitHub Action.
* The tool should be easy to use as a GitHub CLI extension.
* The tool should be easy to use via a NPM package.
* The tool should be easy to use as a standalone script.
  
  ### Basic Principles
  
  - Use English for all code, documentation, and comments.
  - Prioritize modular, reusable, and scalable code.
  - Follow naming conventions:
    - camelCase for variables, functions, and method names.
    - PascalCase for class names.
    - snake_case for file names and directory structures.
    - UPPER_CASE for environment variables.
  
  ### Bash Scripting
  
  - Use descriptive names for scripts and variables (e.g., `backup_files.sh` or `log_rotation`).
  - Write modular scripts with functions to enhance readability and reuse.
  - Include comments for each major section or function.
  - Validate all inputs using `getopts` or manual validation logic.
  - Avoid hardcoding; use environment variables or parameterized inputs.
  - Ensure portability by using POSIX-compliant syntax.
  - Use `shellcheck` to lint scripts and improve quality.
  - Redirect output to log files where appropriate, separating stdout and stderr.
  - Use `trap` for error handling and cleaning up temporary files.
