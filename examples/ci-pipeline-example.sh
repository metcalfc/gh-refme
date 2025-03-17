#!/bin/bash
#
# Example script for integrating gh-refme into a CI/CD pipeline
#
set -e

# Download the script if it doesn't exist
if [[ ! -f ./gh-refme ]]; then
  echo "Downloading gh-refme..."
  curl -s -o gh-refme https://raw.githubusercontent.com/metcalfc/gh-refme/main/gh-refme
  chmod +x gh-refme
fi

# Create an example repository structure
echo "Creating example repository structure..."
mkdir -p .github/workflows

# Create a sample workflow file
cat > .github/workflows/ci.yml << 'EOF'
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18.x'
      - run: npm ci
      - run: npm test
EOF

echo "Created sample workflow file at .github/workflows/ci.yml"

# Run gh-refme to convert references
echo "Running gh-refme to convert GitHub Action references..."
./gh-refme file .github/workflows/ci.yml

echo "Done! You can examine the converted workflow file at .github/workflows/ci.yml"
echo "A backup of the original file is at .github/workflows/ci.yml.bak"
