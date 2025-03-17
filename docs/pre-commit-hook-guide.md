# Using gh-refme as a Git Pre-Commit Hook

This guide explains how to use the gh-refme tool as a pre-commit hook in your Git workflow to automatically convert GitHub Actions references to commit hashes for enhanced security.

## What is a Pre-Commit Hook?

A pre-commit hook is a script that Git executes before finalizing a commit. It allows you to automatically run checks or modifications on your changes before they're committed to your repository.

## Benefits of Using gh-refme as a Pre-Commit Hook

- **Automatic Security**: Every commit that modifies workflow files will automatically have GitHub Actions references converted to commit hashes
- **No Manual Work**: You don't need to remember to run gh-refme, it happens automatically
- **Consistent Security Practices**: Ensures all team members follow security best practices
- **Early Detection**: Catch and fix potential security issues before they're committed

## Setting Up the Pre-Commit Hook

### Method 1: Using the Install Script (Recommended)

The easiest way to install the pre-commit hook is using the included script:

```bash
# Make sure the script is executable
chmod +x gh-refme
chmod +x install-hook.sh

# Run the installation script
./install-hook.sh
```

### Method 2: Manual Setup

1. Create a pre-commit hook file in your repository:

```bash
touch .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

2. Add the following script to the pre-commit hook:

```bash
#!/bin/bash
# Pre-commit hook to convert GitHub references to commit hashes
set -e

# Path to the gh-refme script (update as needed)
REFME_SCRIPT="$(git rev-parse --show-toplevel)/gh-refme"

# Check if the script exists
if [ ! -f "$REFME_SCRIPT" ]; then
  echo "Error: gh-refme script not found at $REFME_SCRIPT"
  echo "Please update the script path in the pre-commit hook"
  exit 1
fi

# Check if any workflow files are staged for commit
WORKFLOW_FILES=$(git diff --cached --name-only | grep -E '\.github/workflows/.*\.ya?ml$' || true)

if [ -n "$WORKFLOW_FILES" ]; then
  echo "🔒 Converting GitHub references in workflow files to commit hashes..."
  
  for file in $WORKFLOW_FILES; do
    echo "Processing $file"
    $REFME_SCRIPT file "$file"
    
    # Re-stage the file if it was modified
    git add "$file"
  done
  
  echo "✅ All workflow files processed!"
fi
```

### Method 3: Team-Wide Setup with pre-commit Framework

For teams, it's often better to use the [pre-commit](https://pre-commit.com/) framework which allows sharing hooks across the team:

1. Install the pre-commit framework:

```bash
pip install pre-commit
```

2. Create a `.pre-commit-config.yaml` file in your repository root:

```yaml
repos:
  - repo: local
    hooks:
      - id: gh-refme
        name: Convert GitHub Actions to commit hashes
        entry: ./gh-refme file
        language: script
        files: \.github/workflows/.*\.ya?ml$
        pass_filenames: true
```

3. Install the hooks:

```bash
pre-commit install
```

## Customizing the Pre-Commit Hook

You can customize the hook behavior with these options:

### Dry Run Mode

To first preview changes without applying them:

```bash
$REFME_SCRIPT file "$file" -n

# If changes look good, run without the -n flag
if [ "$?" -eq 0 ] && confirm "Apply changes?"; then
  $REFME_SCRIPT file "$file"
  git add "$file"
fi
```

### Skip Option

Add a way to skip the hook when needed:

```bash
# Check for skip flag in commit message
if git log -1 --pretty=%B | grep -q "SKIP_REFME"; then
  echo "Skipping gh-refme hook (SKIP_REFME flag detected)"
  exit 0
fi
```

### Error Handling

You may want to add some error handling:

```bash
for file in $WORKFLOW_FILES; do
  echo "Processing $file"
  if ! $REFME_SCRIPT file "$file"; then
    echo "❌ Error processing $file"
    echo "You can skip this hook with: git commit --no-verify"
    exit 1
  fi
  git add "$file"
done
```

## Advanced Configuration

### Team Notification on Error

For team environments, you might want to notify when the hook fails:

```bash
# Add to your pre-commit hook
if ! $REFME_SCRIPT file "$file"; then
  REPO_URL=$(git config --get remote.origin.url)
  USER=$(git config user.name)
  MESSAGE="⚠️ gh-refme pre-commit hook failed for $USER on file $file in $REPO_URL"
  
  # Send a message to your team chat (example for Slack webhook)
  if [ -n "$SLACK_WEBHOOK_URL" ]; then
    curl -s -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"$MESSAGE\"}" \
      "$SLACK_WEBHOOK_URL"
  fi
  
  exit 1
fi
```

### Selective Processing

You can also make the hook more selective:

```bash
# Only process files that contain GitHub Actions references
if grep -q "uses:" "$file"; then
  echo "GitHub Actions found in $file, processing..."
  $REFME_SCRIPT file "$file"
  git add "$file"
else
  echo "No GitHub Actions in $file, skipping"
fi
```

## Troubleshooting

### Hook Not Running

If your hook isn't running, check:
- Permissions: The hook file must be executable (`chmod +x .git/hooks/pre-commit`)
- Path: Make sure the path to the gh-refme script is correct
- Installation: For pre-commit framework, ensure you ran `pre-commit install`

### Invalid References Not Being Caught

If references aren't being caught:
- Check file patterns in the grep command
- Ensure your file is being recognized as a GitHub workflow file

### Can't Commit Due to Hook Errors

To temporarily bypass the hook:

```bash
git commit --no-verify -m "Your commit message"
```

## Best Practices

1. **Keep the script updated**: Regularly update to the latest version of gh-refme
2. **Test the hook**: Try committing a workflow file with references to verify it works
3. **Documentation**: Make sure your team knows about the hook and why it's important
4. **Backup**: Create backups when modifying files to avoid losing changes
5. **CI/CD Integration**: Also use gh-refme in your CI pipeline for double protection

## Combining with Other Pre-Commit Hooks

You can combine gh-refme with other pre-commit hooks like:
- Code linting
- Secrets scanning
- YAML validation
- Security checks

This creates a comprehensive pre-commit pipeline that ensures both code quality and security.

## Conclusion

Using gh-refme as a pre-commit hook provides an automated way to follow GitHub's security best practices for Actions. This simple integration significantly reduces your repository's vulnerability to supply chain attacks with minimal effort.

For more information on the security benefits of using commit hashes, refer to the [GitHub security hardening guide](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions).
