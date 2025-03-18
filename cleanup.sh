#!/bin/bash
# Clean up unnecessary files

# Remove extra README
rm -f README.npm.md

# Remove unneeded release script 
rm -f release.sh

# Make all scripts executable
chmod +x gh-refme
chmod +x tests/*.sh
chmod +x install-hook.sh
chmod +x verify-install.js

echo "Cleanup complete!"
