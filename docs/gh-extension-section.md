## GitHub CLI Extension

`gh-refme` is designed to work as a GitHub CLI extension, allowing you to run it directly through the `gh` command.

### Installing as a GitHub CLI Extension

```bash
# Install the GitHub CLI first if you don't have it
# https://cli.github.com/

# Install the extension
gh extension install metcalfc/gh-refme
```

### Using the GitHub CLI Extension

Once installed, you can use the extension as a subcommand of `gh`:

```bash
# Show help information
gh refme --help

# Convert a single reference
gh refme convert actions/checkout@v4

# Process a workflow file
gh refme file .github/workflows/ci.yml

# Process all workflows in a repository
gh refme dir .

# Run in interactive mode
gh refme interactive
```

### Benefits of Using as a GitHub CLI Extension

1. **Authentication**: Automatically uses your GitHub CLI authentication
2. **Integration**: Seamlessly integrates with other GitHub CLI commands
3. **Updates**: Easy to update with `gh extension upgrade refme`
4. **Discoverability**: Can be found and installed from the GitHub CLI extension marketplace

See the [GitHub CLI Extension Guide](docs/gh-extension-usage.md) for more details on installing, using, and developing the extension.
