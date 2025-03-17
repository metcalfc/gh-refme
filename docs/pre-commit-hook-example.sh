#!/bin/bash
# Pre-commit hook for gh-refme
# Save this script as .git/hooks/pre-commit and make it executable with chmod +x .git/hooks/pre-commit
set -e

# Configuration
REFME_SCRIPT="$(git rev-parse --show-toplevel)/gh-refme"

# Ensure the script is executable
if [ -f "$REFME_SCRIPT" ]; then
  chmod +x "$REFME_SCRIPT"
else
  echo "Error: gh-refme script not found at $REFME_SCRIPT"
  echo "Please place the script in your repository root or update the path in this hook"
  exit 1
fi

# Find modified workflow files
WORKFLOW_FILES=$(git diff --cached --name-only | grep -E '\.github/workflows/.*\.ya?ml$' || true)

if [ -n "$WORKFLOW_FILES" ]; then
  echo "🔒 Converting GitHub references to commit hashes..."
  
  for file in $WORKFLOW_FILES; do
    if [ -f "$file" ]; then
      echo "Processing $file"
      "$REFME_SCRIPT" -f "$file"
      
      # Stage any changes made to the file
      git add "$file"
    fi
  done
  
  echo "✅ All workflow files processed!"
fi

# Exit successfully
exit 0
