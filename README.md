# GitHub RefMe

A lightweight tool to convert GitHub references (tags, branches) to their corresponding commit hashes in workflow files. This enhances security by helping you convert GitHub Actions to specific commit hashes instead of potentially mutable tags or branches.

![Security](https://img.shields.io/badge/Security-Enhanced-blue)
![Bash](https://img.shields.io/badge/Language-Bash-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

```
______        __ ___  ___      
| ___ \      / _||  \/  |      
| |_/ / ___ | |_ | .  . |  ___ 
|    / / _ \|  _|| |\/| | / _ \
| |\ \|  __/| |  | |  | ||  __/
\_| \_|\___||_|  \_|  |_/ \___|
```

## Installation

### GitHub CLI Extension (recommended)

```bash
gh extension install metcalfc/gh-refme
```

### npm

```bash
npm install -g gh-refme

# Optional: setup the Git pre-commit hook
install-hook.sh
```

### Manual Download

Always pin to a specific release tag, not `main`:

```bash
# Download from a specific release
curl -sL -o gh-refme https://raw.githubusercontent.com/metcalfc/gh-refme/refs/tags/v1.6.2/gh-refme
chmod +x gh-refme
```

## Features

- **Dual Mode**: Use as a standalone script **or** a GitHub CLI extension
- **Simple Interface**: File-focused design for all operations
- **No Dependencies**: Uses only standard Unix tools and either `curl` or GitHub CLI (`gh`)
- **Security**: Properly validates all references and handles edge cases
- **CI/CD Integration**: Easily add to your GitHub Actions workflows
- **Branch Support**: Automatically resolves branches, tags, and short/full commit hashes
- **Wildcard Support**: Process multiple workflow files with a single command
- **Nested Package Detection**: Clear messaging for unsupported GitHub package formats
- **Dry Run Mode**: Preview changes without modifying files
- **Comment Preservation**: Adds helpful comments to track what tags/branches were converted to hashes

## Quick Start

### As a Standalone Script

```bash
# Process a workflow file
gh-refme .github/workflows/my-workflow.yml

# Process multiple workflow files with wildcards
gh-refme .github/workflows/*.yml
```

### As a GitHub CLI Extension

```bash
# Process a workflow file
gh refme .github/workflows/my-workflow.yml

# Process multiple workflow files with wildcards
gh refme .github/workflows/*.yml
```

## Why Convert GitHub Actions to Commit Hashes?

In March 2025, the [tj-actions/changed-files supply chain attack](https://www.stepsecurity.io/blog/harden-runner-detection-tj-actions-changed-files-attack-and-setup-of-coinminer) compromised 23,000+ repositories by force-pushing malicious code to existing Git tags. Every repo using `@v45` (or any mutable tag) silently ran the attacker's code, which dumped CI secrets to workflow logs.

The attack exploited a fundamental property of Git: **tags are mutable**. Anyone with write access can run `git tag -f v1 && git push --force` and every consumer using `@v1` gets the new code with no warning.

GitHub's own [security hardening guide](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions) states:

> "Using a full length commit SHA is currently the only way to use an action in a way that's immune to both repository hijacking and branch/tag hijacking."

This tool makes it easy to follow this security best practice.

## Usage Examples

```bash
# Process a specific workflow file
./gh-refme .github/workflows/workflow.yml
gh refme .github/workflows/workflow.yml

# Process workflow files with wildcards
./gh-refme .github/workflows/*.yml
gh refme .github/workflows/*.yml

# Show what would be changed without making changes (dry run)
./gh-refme -n .github/workflows/workflow.yml
gh refme -n .github/workflows/workflow.yml
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

Add this to `.github/workflows/refme.yml` to automatically pin actions in your repository. Note: this example follows its own advice — `actions/checkout` is SHA-pinned and gh-refme runs from the checkout rather than being downloaded at runtime.

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
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6
        with:
          fetch-depth: 0

      - name: Checkout gh-refme
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6
        with:
          repository: metcalfc/gh-refme
          ref: v1.6.2
          path: .gh-refme

      - name: Run gh-refme
        run: |
          .gh-refme/gh-refme .github/workflows/*.{yml,yaml} 2>&1 | tee refme_output.log

          if git diff --quiet; then
            echo "All workflows already pinned!"
            exit 0
          fi

          BRANCH_NAME="security/refme-$(date +%Y%m%d%H%M%S)"
          git checkout -b "$BRANCH_NAME"
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null || true
          git commit -m "security: pin workflow actions to full commit hashes"
          git push origin "$BRANCH_NAME"
          gh pr create \
            --title "Security: Pin GitHub Actions to commit hashes" \
            --body "Automatically generated by [gh-refme](https://github.com/metcalfc/gh-refme)."
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
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

### Supply chain

npm releases are published with [provenance](https://docs.npmjs.com/generating-provenance-statements), which cryptographically links each package version to the specific GitHub Actions workflow run and commit that produced it. You can verify this on the [npm package page](https://www.npmjs.com/package/gh-refme).

### Code security

The tool follows these security best practices:

1. **Strict mode**: `set -euo pipefail` — fail fast on errors, undefined variables, and broken pipes
2. **Input validation**: All references and file paths are validated before use
3. **No command injection**: Special characters in references are properly handled
4. **Secure temp files**: Temporary files are created securely and cleaned up properly
5. **Token protection**: GitHub tokens are handled carefully to prevent exposure
6. **Controlled file operations**: Files are only modified with explicit permission

## How It Works

1. The tool parses GitHub Actions workflow files to find references in the format `owner/repo@ref`
2. It queries the GitHub API to convert references to their corresponding commit hashes
3. For workflow files, it uses pattern matching to locate and replace references
4. It adds helpful comments to track what tags/branches were converted to hashes
   ```yaml
   # Before:
   - uses: actions/checkout@v6

   # After:
   - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # was: actions/checkout@v6
   ```
5. Changes can be previewed before applying (dry run mode)
6. Backups are created before modifying any files

### Special Features

- **refme: ignore** - Add this comment before any action reference to skip its conversion:
  ```yaml
  # refme: ignore
  - uses: actions/checkout@v4
  ```

- **Nested Action References** - The tool will detect and skip nested references like `github/codeql-action/init@v3` with an info message

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
