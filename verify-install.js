#!/usr/bin/env node

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

// Path to the scripts
const scriptPath = path.join(__dirname, 'gh-refme');
const hookScriptPath = path.join(__dirname, 'install-hook.sh');

// Ensure the scripts are executable
try {
  fs.chmodSync(scriptPath, '755');
  console.log('✅ Set gh-refme as executable');
  
  fs.chmodSync(hookScriptPath, '755');
  console.log('✅ Set install-hook.sh as executable');
} catch (err) {
  console.error('⚠️ Warning: Could not make scripts executable. You may need to run: chmod +x gh-refme install-hook.sh');
}

// Check for required dependencies
try {
  let missingDeps = [];
  let hasCurl = false;
  let hasGh = false;

  try {
    execSync('which curl', { stdio: 'ignore' });
    hasCurl = true;
  } catch (e) {
    // curl not found
  }

  try {
    execSync('which gh', { stdio: 'ignore' });
    hasGh = true;
  } catch (e) {
    // gh not found
  }

  if (!hasCurl && !hasGh) {
    missingDeps.push('curl or gh CLI');
  }

  try {
    execSync('which jq', { stdio: 'ignore' });
  } catch (e) {
    // jq is optional but recommended
    console.log('ℹ️ Note: jq is not installed but recommended for better JSON parsing');
  }

  if (missingDeps.length > 0) {
    console.warn(`⚠️ Warning: Some required dependencies are missing: ${missingDeps.join(', ')}`);
    console.warn('gh-refme may not work correctly without these dependencies.');
  } else {
    console.log('✅ All required dependencies are available');
  }

  // Verify bash version (need 4.0+)
  try {
    const bashVersion = execSync('bash --version').toString();
    const versionMatch = bashVersion.match(/version\s+(\d+)\.(\d+)/i);
    
    if (versionMatch) {
      const major = parseInt(versionMatch[1], 10);
      if (major >= 4) {
        console.log('✅ Bash version 4.0+ detected');
      } else {
        console.warn(`⚠️ Warning: Detected Bash version ${major}.x, but 4.0+ is recommended`);
      }
    }
  } catch (e) {
    console.warn('⚠️ Warning: Could not determine Bash version');
  }

  console.log('\n🎉 gh-refme installation complete!');
  console.log('- Run "gh-refme --help" to get started');
  console.log('- Run "install-hook.sh" to set up the Git pre-commit hook');
} catch (error) {
  console.error('Error during installation verification:', error);
}
