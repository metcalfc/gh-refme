#!/bin/bash
# install-hook.sh - Install gh-refme as a pre-commit hook
set -e

echo "Installing gh-refme as a pre-commit hook..."

# Check if this is a git repository
if [ ! -d ".git" ]; then
  echo "Error: Not a git repository. Please run this script from the root of your git repository."
  exit 1
fi

# Check if gh-refme exists
if [ ! -f "gh-refme" ]; then
  echo "Error: gh-refme not found in the current directory."
  echo "Please place gh-refme in the repository root or update the script path in the hook."
  exit 1
fi

# Ensure gh-refme is executable
chmod +x gh-refme

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Create the pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook for gh-refme
set -e

# Path to the gh-refme script
REFME_SCRIPT="$(git rev-parse --show-toplevel)/gh-refme"

# Ensure the script is executable
if [ -f "$REFME_SCRIPT" ]; then
  chmod +x "$REFME_SCRIPT"
else
  echo "Error: gh-refme script not found at $REFME_SCRIPT"
  exit 1
fi

# Find modified workflow files
WORKFLOW_FILES=$(git diff --cached --name-only | grep -E '\.github/workflows/.*\.ya?ml$' || true)

if [ -n "$WORKFLOW_FILES" ]; then
  echo "🔒 Converting GitHub references to commit hashes..."
  
  for file in $WORKFLOW_FILES; do
    if [ -f "$file" ]; then
      echo "Processing $file"
      "$REFME_SCRIPT" file "$file"
      
      # Stage any changes made to the file
      git add "$file"
    fi
  done
  
  echo "✅ All workflow files processed!"
fi
EOF

# Make the hook executable
chmod +x .git/hooks/pre-commit

echo "✅ Pre-commit hook installed successfully!"
echo ""
echo "The hook will automatically run when you commit changes to workflow files."
echo "To test it, make a change to a workflow file in .github/workflows/ and try to commit it."
echo ""
echo "For more information and advanced configurations, see docs/pre-commit-hook-guide.md"
