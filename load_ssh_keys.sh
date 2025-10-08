#!/bin/bash
# Load all SSH keys from macOS Keychain into ssh-agent
#
# This script loads all SSH keys that were previously added with --apple-use-keychain
# to the ssh-agent. This is useful for having your keys pre-loaded at system startup.
#
# Usage:
#   ./load_ssh_keys.sh                    # Run manually
#   Or add to your shell profile for automatic loading at login

# Suppress output unless there's an error
ssh-add --apple-use-keychain 2>/dev/null

# Optional: Uncomment to see which keys were loaded
# ssh-add -l 2>/dev/null | grep -q "." && echo "✅ SSH keys loaded from keychain"
