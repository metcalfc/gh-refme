# Using gh-refme as a GitHub CLI Extension

This guide explains how to install, use, and develop the `gh-refme` extension for GitHub CLI.

## What is a GitHub CLI Extension?

GitHub CLI extensions are add-ons that extend the functionality of the `gh` command-line tool. They allow you to create custom commands that integrate with GitHub's ecosystem.

## Installation

### Method 1: Install from GitHub Repository

```bash
gh extension install metcalfc/gh-refme
```

### Method 2: Install from Local Directory

If you're developing the extension or have the code locally:

```bash
# Clone the repository
git clone https://github.com/metcalfc/gh-refme.git

# Install the extension from the local directory
cd gh-refme
gh extension install .
```

### Method 3: Manual Installation

```bash
# Create the extensions directory if it doesn't exist
mkdir -p ~/.local/share/gh/extensions

# Clone the repository directly to the extensions directory
git clone https://github.com/metcalfc/gh-refme.git ~/.local/share/gh/extensions/gh-refme
```

## Usage

After installation, you can use the extension as a subcommand of `gh`:

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

## Updating the Extension

```bash
gh extension upgrade refme
```

## Uninstalling the Extension

```bash
gh extension remove refme
```

## Extension Development

If you're developing the extension:

1. Make your changes to the code
2. Test the extension locally:
   ```bash
   gh extension install .
   gh refme --help  # Test basic functionality
   ```
3. Once you're satisfied, push your changes to GitHub
4. Users can then update to the latest version using `gh extension upgrade refme`

## Publishing the Extension

To make your extension discoverable in the GitHub CLI extension marketplace:

1. Ensure your repository is public on GitHub
2. Add the topic `gh-extension` to your repository
3. (Optional) Add a screenshot or GIF to your README.md showing the extension in action

## Extension Structure Requirements

For a GitHub CLI extension to work properly, ensure:

1. The repository name starts with `gh-`
2. The main executable has the same name as the repository (without the `.sh` extension)
3. The repository includes a properly formatted `gh-refme.json` manifest file
4. The main script has proper execute permissions (`chmod +x gh-refme`)

## Debugging

If you encounter issues with the extension:

```bash
# Check if the extension is installed
gh extension list

# Check extension path
which gh-refme

# Run with debug output
GH_DEBUG=1 gh refme --help
```

## GitHub CLI Authentication

As a GitHub CLI extension, `gh-refme` automatically uses your GitHub authentication credentials when making API requests, so no separate authentication is needed.

## Benefits of Using as a GitHub CLI Extension

When used as a GitHub CLI extension, gh-refme offers several advantages:

1. **Authentication**: Automatically uses your GitHub CLI authentication
2. **Integration**: Seamlessly integrates with other GitHub CLI commands
3. **Updates**: Easy to update with `gh extension upgrade refme`
4. **Discoverability**: Can be found and installed from the GitHub CLI extension marketplace

## Command Reference

### Convert Command

Converts a single GitHub reference to a commit hash:

```bash
gh refme convert actions/checkout@v4
```

### File Command

Processes a single workflow file:

```bash
gh refme file path/to/workflow.yml

# With dry run option (preview only)
gh refme file path/to/workflow.yml -n
```

### Directory Command

Processes all workflow files in a repository:

```bash
gh refme dir path/to/repo
```

### Interactive Command

Runs the tool in interactive guided mode:

```bash
gh refme interactive
```

## Conclusion

Using gh-refme as a GitHub CLI extension provides a seamless experience for GitHub users who already use the CLI. It integrates nicely with existing GitHub workflows and takes advantage of your existing authentication.
