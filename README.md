# GitHub RefMe

A lightweight tool to convert GitHub references (tags, branches) to their corresponding commit hashes. This enhances security by helping you convert GitHub Actions to specific commit hashes instead of potentially mutable tags or branches.

![Security](https://img.shields.io/badge/Security-Enhanced-blue)
![Bash](https://img.shields.io/badge/Language-Bash-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

- **Dual Mode**: Use as a standalone script **or** a GitHub CLI extension
- **Simple Interface**: Single command design for all operations
- **No Dependencies**: Uses only standard Unix tools and either `curl` or GitHub CLI (`gh`)
- **Flexible**: Convert individual references, files, or entire repositories
- **CI/CD Integration**: Easily add to your GitHub Actions workflows
- **Branch Support**: Automatically resolves branches, tags, and short/full commit hashes
- **Wildcard Support**: Process multiple workflow files with a single command
- **Nested Package Detection**: Clear messaging for unsupported GitHub package formats

## Quick Start

### As a Standalone Script

```bash
# Download the script
curl -o gh-refme https://raw.githubusercontent.com/metcalfc/gh-refme/main/gh-refme
chmod +x gh-refme

# Convert a single reference
./gh-refme convert actions/checkout@v4

# Process a workflow file
./gh-refme convert .github/workflows/my-workflow.yml

# Process multiple workflow files with wildcards
./gh-refme convert .github/workflows/*.yml

# Process all workflows in a repository
./gh-refme convert path/to/repo
```

### As a GitHub CLI Extension

```bash
# Install the extension
gh extension install metcalfc/gh-refme

# Convert a single reference
gh refme convert actions/checkout@v4

# Process a workflow file
gh refme convert .github/workflows/my-workflow.yml

# Process multiple workflow files with wildcards
gh refme convert .github/workflows/*.yml

# Process all workflows in a repository
gh refme convert path/to/repo
```

## Why Convert GitHub Actions to Commit Hashes?

Using tags (like `@v3`) or branches (like `@main`) in GitHub Actions workflows is a security risk. Tags and branches can be modified to point to different code after you've reviewed and approved them, potentially enabling supply chain attacks.

GitHub's own [security hardening guide](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions) states:

> "Using a full length commit SHA is currently the only way to use an action in a way that's immune to both repository hijacking and branch/tag hijacking."

This tool makes it easy to follow this security best practice.

## Usage Examples

```bash
# Convert single reference
./gh-refme convert actions/checkout@v4
gh refme convert actions/checkout@v4

# Convert multiple references 
./gh-refme convert actions/checkout@v4 actions/setup-node@v3
gh refme convert actions/checkout@v4 actions/setup-node@v3

# Process a specific workflow file
./gh-refme convert path/to/workflow.yml
gh refme convert path/to/workflow.yml

# Process workflow files with wildcards
./gh-refme convert path/to/*.yml
gh refme convert path/to/*.yml

# Process all workflows in a repository
./gh-refme convert path/to/repo
gh refme convert path/to/repo

# Show what would be changed without making changes (dry run)
./gh-refme convert path/to/workflow.yml -n
gh refme convert path/to/workflow.yml -n
```

### Help & Information

```bash
# Show help information (standalone)
./gh-refme --help

# Show help information (GitHub CLI extension)
gh refme --help

# Show version information (standalone)
./gh-refme --version

# Show version information (GitHub CLI extension)
gh refme --version
```

## GitHub Actions Integration

You can add this script to your `.github/workflows/refme.yml` file to automatically convert GitHub Actions in your repository:

```yaml
name: Convert GitHub Actions to Commit Hashes
on:
  schedule:
    - cron: '0 2 * * 1'  # Runs weekly
  workflow_dispatch:  # Allow manual triggering

jobs:
  refme:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Download gh-refme script
        run: |
          curl -o /tmp/gh-refme https://raw.githubusercontent.com/metcalfc/gh-refme/main/gh-refme
          chmod +x /tmp/gh-refme
      
      - name: Create branch for changes
        run: |
          git config --global user.name "GitHub Actions"
          git config --global user.email "actions@github.com"
          git checkout -b security/refme-$(date +%Y%m%d)
      
      - name: Process workflow files
        run: /tmp/gh-refme convert .
      
      - name: Create PR if changes found
        run: |
          if git status --porcelain | grep -q "\.yml\|\.yaml"; then
            git add .github/workflows/*.yml .github/workflows/*.yaml
            git commit -m "security: convert GitHub Actions to commit hashes"
            git push origin HEAD
            gh pr create --title "Security: Convert GitHub Actions to commit hashes" --body "This PR converts actions to commit hashes for better security."
          fi
```

## Testing

The tool includes several test scripts to verify functionality and security:

```bash
# Run basic functionality tests
./tests/test.sh

# Run branch and short hash reference tests
./tests/branch-ref-test.sh

# Run comprehensive test suite
./tests/run-all-tests.sh

# Run security tests
./tests/security-test.sh

# Check shell script best practices (requires shellcheck)
./tests/shellcheck-test.sh
```

These tests ensure that:
- Basic functionality works as expected
- Branch references and short hashes are handled correctly
- Edge cases are handled properly
- The script is secure against common shell script vulnerabilities
- Best practices are followed

## Requirements

- Bash 4.0+
- Either `curl` or GitHub CLI (`gh`)
- `jq` is recommended but not required (for better JSON parsing)
- `git` (for repository operations)

## Security Considerations

The tool follows these security best practices:

1. **Input validation**: All references and file paths are validated before use
2. **No command injection**: Special characters in references are properly handled
3. **Secure temp files**: Temporary files are created securely and cleaned up properly
4. **Token protection**: GitHub tokens are handled carefully to prevent exposure
5. **Controlled file operations**: Files are only modified with explicit permission

## How It Works

1. The tool parses GitHub Actions references in the format `owner/repo@ref`
2. It queries the GitHub API to convert references to their corresponding commit hashes
   - First checks if the reference is a short hash and expands it
   - Then checks if the reference is a tag
   - If not found, tries as a branch
   - Finally tries as a direct commit reference
   - If all fail, reports an error
3. For workflow files, it uses pattern matching to locate and replace references
4. Changes can be previewed before applying (dry run mode)
5. Backups are created before modifying any files

## Advanced Usage

### Environment Variables

- `GITHUB_TOKEN`: Authentication token for GitHub API (increases rate limits)

### Use as a Git Pre-Commit Hook

You can use gh-refme as a pre-commit hook to automatically convert GitHub references in workflow files when you commit changes:

```bash
# Run the installation script
./install-hook.sh
```

This will install gh-refme as a pre-commit hook in your Git repository. The hook will automatically run when you commit changes to workflow files, converting any GitHub Action references to commit hashes.

For more advanced configurations and options, see the [pre-commit hook guide](docs/pre-commit-hook-guide.md).

## Contributing

Contributions are welcome! Here are some ways to help:

1. Report bugs or suggest features by opening issues
2. Improve documentation
3. Add more tests
4. Submit pull requests with improvements

## License

MIT
