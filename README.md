# Automated Remote SSH Key Setup

Scripts to automate the process of setting up passwordless SSH login to remote servers.  
This is useful for developers who want quick and secure access to servers from the terminal, VS Code, Cursor, or other tools without repeatedly entering passwords.

## 📋 Table of Contents

- [Automated Remote SSH Key Setup](#automated-remote-ssh-key-setup)
  - [📋 Table of Contents](#-table-of-contents)
  - [🚀 Features](#-features)
    - [Core Functionality](#core-functionality)
    - [Smart Duplicate Detection 🎯](#smart-duplicate-detection-)
    - [Intelligent Checks ✨](#intelligent-checks-)
    - [Flexible Modes](#flexible-modes)
    - [Available Scripts](#available-scripts)
  - [📂 Files](#-files)
  - [🛠 Usage](#-usage)
    - [1. Clone the repo](#1-clone-the-repo)
    - [2. Configure Server Details (for automation only)](#2-configure-server-details-for-automation-only)
    - [3. Make scripts executable](#3-make-scripts-executable)
    - [4. Validate configuration (recommended)](#4-validate-configuration-recommended)
    - [5. Run the script](#5-run-the-script)
      - [First-time setup (normal case):](#first-time-setup-normal-case)
      - [Replacing an existing key:](#replacing-an-existing-key)
      - [Advanced scenarios:](#advanced-scenarios)
      - [Interactive mode (alternative):](#interactive-mode-alternative)
      - [Get help:](#get-help)
    - [6. Test the connection](#6-test-the-connection)
  - [🎯 Common Workflows](#-common-workflows)
    - [Check before running](#check-before-running)
    - [First-time setup](#first-time-setup)
    - [Replace existing key](#replace-existing-key)
    - [Inspect full system status](#inspect-full-system-status)
  - [🚩 Available Flags](#-available-flags)
    - [`--sanity-check` (aliases: `--validate`, `--dry-run`)](#--sanity-check-aliases---validate---dry-run)
    - [`--force`](#--force)
    - [Flag Combinations](#flag-combinations)
  - [🔄 Teardown](#-teardown)
  - [🔑 Loading Keys at Startup (Optional)](#-loading-keys-at-startup-optional)
    - [How It Currently Works](#how-it-currently-works)
    - [Pre-loading Keys at Startup](#pre-loading-keys-at-startup)
      - [Option 1: Using the Helper Script (Recommended)](#option-1-using-the-helper-script-recommended)
      - [Option 2: Manual Configuration](#option-2-manual-configuration)
    - [What This Does](#what-this-does)
    - [Security Considerations](#security-considerations)
    - [Verification](#verification)
    - [Removing from Startup](#removing-from-startup)

---

## 🚀 Features

### Core Functionality

- Generates a new SSH key pair for this server (if one doesn't exist)
- Copies the public key to a remote server
- Adds the private key to `ssh-agent` for passwordless use
- Optionally creates a neat alias in `~/.ssh/config`
- **Automatic backup** of existing SSH config before modifications (timestamped backups in `~/.ssh/`)

### Smart Duplicate Detection 🎯

- **Early exit gate** - Detects existing SSH access before making changes
- Prevents accidental duplicate key creation for the same server
- Distinguishes between same key vs different key scenarios
- Provides clear guidance on whether to use existing key or replace it
- Requires explicit confirmation to proceed if access already exists

### Intelligent Checks ✨

- **Remote authentication test** - Actually tests if SSH key auth works on the server
- **Agent status verification** - Checks if keys are loaded in ssh-agent
- **Configuration validation** - Verifies SSH config entries
- **Idempotent operation** - Safely re-runnable, skips already completed steps
- Caches check results for efficiency (checks run once, used everywhere)

### Flexible Modes

- **Sanity check mode** (`--sanity-check`) - Preview what will happen, no changes made
- **Force mode** (`--force`) - Bypass duplicate detection for advanced scenarios
- **Interactive mode** (`setup_ssh.sh`) - Prompts for all details during setup
- **Automated mode** (`setup_ssh_auto.sh`) - Reads everything from `ssh_setup.conf`

### Available Scripts

- **Setup** - Create and configure SSH keys
- **Teardown** - Remove SSH keys and configurations
- Both scripts work together for key replacement workflows

---

## 📂 Files

- **`setup_ssh_auto.sh`** - Main automated setup script (reads from `ssh_setup.conf`)
  - Supports `--sanity-check`, `--force`, and combined flags
  - Smart duplicate detection with early exit gate
  - Comprehensive status checks
- **`setup_ssh.sh`** - Interactive setup script (prompts for all values)
- **`teardown_ssh_key.sh`** - Removes SSH keys and configurations
- **`load_ssh_keys.sh`** - Helper script to load keys from keychain (optional)
- **`ssh_setup.conf`** - Configuration file (server details, key name, alias)

---

## 🛠 Usage

### 1. Clone the repo

```bash
git clone https://github.com/Tiiatcha/automated-remote-ssh-key-setup.git
cd automated-remote-ssh-key-setup
```

### 2. Configure Server Details (for automation only)

Edit the ssh_setup.conf and set the values:

```conf
# Server info
SERVER_HOST="server.example.com"
SERVER_PORT=22
SERVER_USER="user"

# SSH key info
KEY_NAME="id_example_key"
KEY_PASSPHRASE=""

# Optional SSH alias
SSH_ALIAS="myserver"
```

### 3. Make scripts executable

Before you run for the first time, make the scripts executable:

```bash
chmod +x setup_ssh_auto.sh
chmod +x setup_ssh.sh
chmod +x teardown_ssh_key.sh
chmod +x load_ssh_keys.sh
```

**Note:** You only need to make executable the scripts you plan to use:

- `setup_ssh_auto.sh` (automated) OR `setup_ssh.sh` (interactive)
- `teardown_ssh_key.sh` (if you need to remove keys)
- `load_ssh_keys.sh` (optional, for auto-loading keys at startup)

### 4. Validate configuration (recommended)

Before running setup, validate your configuration with sanity check mode:

```bash
./setup_ssh_auto.sh --sanity-check
# Aliases also work: --validate, --dry-run
```

**What happens:**

- Shows all configuration values
- **Detects existing SSH access** (stops immediately if found)
- Checks local key status
- Verifies SSH agent status
- Tests remote authentication
- Shows exactly which steps will run/skip
- Makes NO changes to your system

**If you already have SSH access:**
The script will stop with a clear message explaining:

- Whether it's the same key or a different one
- Options: keep existing, replace with teardown, or force multiple keys

**To see full details even with existing access:**

```bash
./setup_ssh_auto.sh --force --sanity-check
```

### 5. Run the script

#### First-time setup (normal case):

```bash
./setup_ssh_auto.sh
```

**What happens:**

1. Checks if you already have SSH access
2. If yes → stops and shows options (prevents duplicates)
3. If no → proceeds with setup
4. Asks for server password when copying the key

#### Replacing an existing key:

```bash
# Step 1: Remove the old key
./teardown_ssh_key.sh

# Step 2: Create new key
./setup_ssh_auto.sh
```

#### Advanced scenarios:

**Force multiple keys (rare):**

```bash
./setup_ssh_auto.sh --force
# Use only if you genuinely need multiple keys for the same server
```

**Debug/inspect full status:**

```bash
./setup_ssh_auto.sh --force --sanity-check
# Shows all checks even if SSH access exists
```

#### Interactive mode (alternative):

```bash
./setup_ssh.sh
# Prompts for all values - doesn't use ssh_setup.conf
```

#### Get help:

```bash
./setup_ssh_auto.sh --help
# Shows all available flags and options
```

### 6. Test the connection

After successful setup, connect without passwords or passphrases:

```bash
# With alias (if configured)
ssh myserver

# Without alias
ssh user@server.example.com
```

The connection should work immediately from:

- Terminal
- VS Code Remote SSH
- Cursor
- Any SSH-based tool

---

## 🎯 Common Workflows

### Check before running

```bash
./setup_ssh_auto.sh --sanity-check
```

### First-time setup

```bash
./setup_ssh_auto.sh
```

### Replace existing key

```bash
./teardown_ssh_key.sh && ./setup_ssh_auto.sh
```

### Inspect full system status

```bash
./setup_ssh_auto.sh --force --sanity-check
```

---

## 🚩 Available Flags

### `--sanity-check` (aliases: `--validate`, `--dry-run`)

- Preview mode - makes NO changes
- Stops immediately if SSH access already exists
- Shows exactly what will happen
- **Use this first!**

### `--force`

- Bypasses duplicate detection
- Use when you genuinely need multiple keys
- Can combine with `--sanity-check`

### Flag Combinations

| Command                                      | Purpose                           |
| -------------------------------------------- | --------------------------------- |
| `./setup_ssh_auto.sh`                        | Normal setup (safe, recommended)  |
| `./setup_ssh_auto.sh --sanity-check`         | Preview without changes           |
| `./setup_ssh_auto.sh --force`                | Allow duplicate keys              |
| `./setup_ssh_auto.sh --force --sanity-check` | Inspect even with existing access |

---

## 🔄 Teardown

To remove SSH keys and configuration:

```bash
./teardown_ssh_key.sh
```

This will:

- Remove the key from the remote server
- Remove the key from ssh-agent
- Delete local key files
- Remove from macOS keychain (if present)
- Remove SSH config entry

---

## 🔑 Loading Keys at Startup (Optional)

### How It Currently Works

After running setup, your SSH keys are automatically loaded when needed thanks to these settings in your SSH config:

```
UseKeychain yes
AddKeysToAgent yes
```

**This means:** Keys automatically load from macOS Keychain on **first SSH use** after login.

### Pre-loading Keys at Startup

If you prefer to have your SSH keys **pre-loaded into ssh-agent at login** (before first use), you have two options:

#### Option 1: Using the Helper Script (Recommended)

We provide a helper script that loads all keys from keychain:

```bash
# Test it manually first
./load_ssh_keys.sh

# Verify keys are loaded
ssh-add -l
```

**Add to your shell profile:**

For **Zsh** (default on macOS):

```bash
echo '' >> ~/.zshrc
echo '# Load SSH keys from keychain at login' >> ~/.zshrc
echo 'ssh-add --apple-use-keychain &>/dev/null' >> ~/.zshrc
```

For **Bash**:

```bash
echo '' >> ~/.bash_profile
echo '# Load SSH keys from keychain at login' >> ~/.bash_profile
echo 'ssh-add --apple-use-keychain &>/dev/null' >> ~/.bash_profile
```

After adding, either:

- Restart your terminal, OR
- Run: `source ~/.zshrc` (or `source ~/.bash_profile`)

#### Option 2: Manual Configuration

Add this line to your shell profile (`~/.zshrc` or `~/.bash_profile`):

```bash
ssh-add --apple-use-keychain &>/dev/null
```

### What This Does

- Loads **ALL** SSH keys that were added with `--apple-use-keychain`
- Runs silently (errors suppressed)
- Happens automatically at each login
- Keys are immediately available for SSH connections

### Security Considerations

**Is this secure?** Yes, for typical use cases:

- ✅ Your macOS Keychain is already unlocked when you log in
- ✅ Keys are protected by your user account login
- ✅ With `UseKeychain yes`, keys would auto-load on first SSH use anyway
- ✅ This just pre-loads them instead of loading on-demand

**Best practices:**

- Use strong passphrases on your SSH keys ✓ (already doing this)
- Lock your screen when away from computer
- Enable FileVault disk encryption
- Use a strong login password

### Verification

To check if keys are loaded:

```bash
# List loaded keys
ssh-add -l

# Should show your key(s), for example:
# 256 SHA256:abc123... your_email@example.com (ED25519)
```

### Removing from Startup

To stop auto-loading at startup:

For **Zsh**:

```bash
# Edit your profile
nano ~/.zshrc

# Remove or comment out these lines:
# ssh-add --apple-use-keychain &>/dev/null
```

For **Bash**:

```bash
# Edit your profile
nano ~/.bash_profile

# Remove or comment out these lines:
# ssh-add --apple-use-keychain &>/dev/null
```
