#!/bin/bash
# Fully automated SSH key setup reading from a config file

# --- Parse command line arguments ---
SANITY_CHECK_MODE=false
FORCE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --sanity-check|--validate|--dry-run)
            SANITY_CHECK_MODE=true
            shift
            ;;
        --force)
            FORCE_MODE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --sanity-check, --validate, --dry-run"
            echo "                    Validate configuration and show what would be done"
            echo "                    without making any changes"
            echo "  --force          Bypass the existing SSH access check"
            echo "                    (use only if you already have a working key and genuinely need multiple keys)"
            echo "  -h, --help       Display this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# --- Config file location ---
CONFIG_FILE="./ssh_setup.conf"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Backup SSH config file before modifications
backup_ssh_config() {
    local config_file="$HOME/.ssh/config"
    if [ -f "$config_file" ]; then
        local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$config_file" "$backup_file"
        echo "✅ SSH config backed up to: $backup_file"
        return 0
    else
        echo "ℹ️  No existing SSH config file to backup"
        return 1
    fi
}

# Display configuration values
display_configuration() {
    echo "📋 Configuration Values:"
    echo "  Server host       : $SERVER_HOST"
    echo "  Server port       : $SERVER_PORT"
    echo "  Server user       : $SERVER_USER"
    echo "  SSH key filename  : $KEY_NAME"
    echo "  SSH key path      : $KEY_PATH"
    if [ -z "$KEY_PASSPHRASE" ]; then
        echo "  SSH key passphrase: (none - key will not be encrypted)"
    else
        echo "  SSH key passphrase: (set - key will be encrypted)"
    fi
    if [ -z "$SSH_ALIAS" ]; then
        echo "  SSH alias         : (none - no config entry will be created)"
    else
        echo "  SSH alias         : $SSH_ALIAS"
    fi
    echo ""
}

# Reset config file to default template (utility function, not called by default)
reset_config() {
    echo "Resetting config file to default example values..."
    cat > "$CONFIG_FILE" <<EOL
# ssh_setup.conf (example template)

# Server info
SERVER_HOST="server.example.com"
SERVER_PORT=22
SERVER_USER="user"

# SSH key info
KEY_NAME="id_example_key"
KEY_PASSPHRASE="" # leave empty for no passphrase

# Optional SSH alias
SSH_ALIAS="myserver"
EOL
    echo "✅ Config file has been reset to default values."
}

# ============================================================================
# CHECK FUNCTIONS - Pure boolean checks (no output, just return status)
# ============================================================================

# Check if SSH key exists
# Returns: 0 (true) if key exists, 1 (false) if it doesn't
check_ssh_key_exists() {
    [ -f "$KEY_PATH" ]
}

# Check if public key exists
# Returns: 0 (true) if public key exists, 1 (false) if it doesn't
check_public_key_exists() {
    [ -f "${KEY_PATH}.pub" ]
}

# Check if SSH config entry exists for the alias
# Returns: 0 (true) if entry exists, 1 (false) if it doesn't
check_ssh_config_entry_exists() {
    [ -f "$HOME/.ssh/config" ] && grep -q "Host $SSH_ALIAS" "$HOME/.ssh/config" 2>/dev/null
}

# Check if key is loaded in SSH agent
# Returns: 0 (true) if key is in agent, 1 (false) if not
check_key_in_ssh_agent() {
    # Check if public key file exists
    if [ ! -f "${KEY_PATH}.pub" ]; then
        return 1
    fi
    
    # Extract the key hash (second field) from the public key file
    local key_hash
    key_hash=$(awk '{print $2}' "${KEY_PATH}.pub" 2>/dev/null)
    
    # Check if this key hash appears in the agent's loaded keys
    ssh-add -L 2>/dev/null | grep -q "$key_hash"
}

# Check if SSH agent is running
# Returns: 0 (true) if agent is running, 1 (false) if not
check_ssh_agent_running() {
    ssh-add -l &>/dev/null
}

# Check if we can already connect to server without specifying any key
# This detects if another key is already configured and working
# Returns: 0 (true) if can connect, 1 (false) if cannot
check_any_key_auth_works() {
    # Test connection WITHOUT specifying a key
    # SSH will try keys from agent and default locations
    ssh -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o PasswordAuthentication=no \
        -p "$SERVER_PORT" \
        "$SERVER_USER@$SERVER_HOST" \
        "exit 0" >/dev/null 2>&1
}

# Check if SSH key authentication already works on remote server
# Returns: 0 (true) if key auth works, 1 (false) if it doesn't
check_key_auth_works() {
    # Only test if the key files exist locally
    if [ ! -f "$KEY_PATH" ] || [ ! -f "${KEY_PATH}.pub" ]; then
        return 1
    fi
    
    # Test connection with THIS SPECIFIC key (using -i to specify)
    # BatchMode prevents password prompts
    ssh -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o PasswordAuthentication=no \
        -i "$KEY_PATH" \
        -p "$SERVER_PORT" \
        "$SERVER_USER@$SERVER_HOST" \
        "exit 0" >/dev/null 2>&1
}

# ============================================================================
# EXECUTION FUNCTIONS - Perform actual operations (used in wet-run mode)
# ============================================================================

# Generate SSH key
# Generates a new ed25519 SSH key at KEY_PATH
generate_ssh_key() {
    echo "Generating SSH key at $KEY_PATH..."
    if [ -z "$KEY_PASSPHRASE" ]; then
        ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$USER@$HOSTNAME" -N ""
    else
        ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$USER@$HOSTNAME" -N "$KEY_PASSPHRASE"
    fi
}

# Copy public key to remote server
# Uses ssh-copy-id to install the public key on the remote server
copy_key_to_server() {
    echo "Copying public key to $SERVER_USER@$SERVER_HOST..."
    ssh-copy-id -i "${KEY_PATH}.pub" -p "$SERVER_PORT" \
        -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no \
        "$SERVER_USER@$SERVER_HOST"
}

# Add key to SSH agent
# Adds the private key to the macOS keychain and SSH agent
add_key_to_ssh_agent() {
    echo "Adding key to ssh-agent..."
    ssh-add --apple-use-keychain "$KEY_PATH"
}

# Create SSH config entry
# Creates a new host entry in ~/.ssh/config with the configured alias
create_ssh_config_entry() {
    local config_ssh="$HOME/.ssh/config"
    
    backup_ssh_config
    echo "Adding SSH config entry..."
    cat <<EOL >> "$config_ssh"

Host $SSH_ALIAS
  HostName $SERVER_HOST
  User $SERVER_USER
  Port $SERVER_PORT
  UseKeychain yes
  AddKeysToAgent yes
  IdentitiesOnly yes
  IdentityFile $KEY_PATH
EOL
}

# --- Load config ---
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# Paths
KEY_PATH="$HOME/.ssh/$KEY_NAME"

# ============================================================================
# ORCHESTRATION FUNCTIONS
# ============================================================================

# Run sanity check (dry-run mode)
# Only performs checks, makes no modifications
run_sanity_check() {
    echo "=========================================="
    echo "       SSH SETUP SANITY CHECK"
    echo "=========================================="
    echo ""
    
    display_configuration
    
    # ========================================================================
    # CRITICAL EARLY CHECK: Do we already have SSH access to this server?
    # ========================================================================
    if [ "$FORCE_MODE" = false ]; then
        echo "🔍 Checking existing SSH access to $SERVER_USER@$SERVER_HOST..."
        echo ""
        
        if check_any_key_auth_works; then
        # We can already connect! Determine if it's the same key or different
        local key_auth_works=false
        check_key_auth_works && key_auth_works=true
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        if [ "$key_auth_works" = false ]; then
            # Different key is working
            echo "🚨 SSH ACCESS ALREADY EXISTS 🚨"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "✅ You can already connect to $SERVER_USER@$SERVER_HOST"
            echo ""
            echo "This means a DIFFERENT SSH key is already configured."
            echo "The key configured in this script ($KEY_NAME) is NOT being used."
            echo ""
            echo "Creating another key will result in MULTIPLE keys for the same server,"
            echo "which can cause confusion and maintenance issues."
        else
            # Same key is working
            echo "✅ SSH ACCESS ALREADY CONFIGURED ✅"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "✅ You can already connect to $SERVER_USER@$SERVER_HOST"
            echo ""
            echo "Your SSH key ($KEY_NAME) is already fully configured."
            if [ ! -z "$SSH_ALIAS" ]; then
                echo ""
                echo "You can connect right now using:"
                echo "  ssh $SSH_ALIAS"
            fi
        fi
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📌 WHAT DO YOU WANT TO DO?"
        echo ""
        echo "   Option 1: Nothing! (Recommended)"
        echo "   └─ Your connection works. Exit this script."
        echo ""
        echo "   Option 2: Replace the existing key"
        echo "   ├─ Run:  ./teardown_ssh_key.sh"
        echo "   └─ Then: ./setup_ssh_auto.sh"
        echo ""
        echo "   Option 3: See detailed checks anyway"
        echo "   └─ Rerun ./setup_ssh_auto.sh --force to bypass this check"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "✋ Sanity check stopped. SSH access already exists."
        echo ""
        exit 0
        fi
    else
        echo "⚠️  FORCE MODE ENABLED - Skipping existing SSH access check"
        echo ""
    fi
    
    # Run remaining checks (only if we passed the early gate)
    local ssh_key_exists=false
    local public_key_exists=false
    local config_entry_exists=false
    local key_in_agent=false
    local agent_running=false
    local key_auth_works=false
    
    check_ssh_key_exists && ssh_key_exists=true
    check_public_key_exists && public_key_exists=true
    check_ssh_config_entry_exists && config_entry_exists=true
    check_key_in_ssh_agent && key_in_agent=true
    check_ssh_agent_running && agent_running=true
    check_key_auth_works && key_auth_works=true
    
    echo "🔍 Pre-flight Checks:"
    echo ""
    
    # Display SSH key status
    if [ "$ssh_key_exists" = true ]; then
        echo "  ✅ SSH key already exists at: $KEY_PATH"
        echo "     (will be skipped during setup)"
    else
        echo "  ℹ️  SSH key does not exist yet"
        echo "     (will be generated during setup)"
    fi
    
    # Display public key status
    if [ "$public_key_exists" = true ]; then
        echo "  ✅ Public key already exists at: ${KEY_PATH}.pub"
        echo "     (will be skipped during setup)"
    else
        echo "  ℹ️  Public key does not exist yet"
        echo "     (will be generated during setup)"
    fi
    
    # Display SSH config entry status
    if [ ! -z "$SSH_ALIAS" ]; then
        if [ "$config_entry_exists" = true ]; then
            echo "  ✅ SSH config entry for '$SSH_ALIAS' already exists"
            echo "     (will be skipped during setup)"
        else
            echo "  ℹ️  SSH config entry for '$SSH_ALIAS' does not exist"
            echo "     (will be created during setup)"
        fi
    fi
    
    # Display SSH agent status
    if [ "$agent_running" = true ]; then
        if [ "$key_in_agent" = true ]; then
            echo "  ✅ SSH agent is running"
            echo "     Key is already loaded in agent (will be skipped during setup)"
        else
            echo "  ✅ SSH agent is running"
            echo "     Key is not yet loaded in agent (will be added during setup)"
        fi
    else
        echo "  ⚠️  SSH agent is not running or has no keys"
        echo "     (key will be added during setup)"
    fi
    
    # Display remote key authentication status
    if [ "$ssh_key_exists" = true ]; then
        if [ "$key_auth_works" = true ]; then
            echo "  ✅ SSH key authentication to remote server is working"
            echo "     (public key is already on server - will be skipped during setup)"
        else
            echo "  ℹ️  SSH key authentication not yet configured on remote server"
            echo "     (public key will be copied during setup)"
        fi
    fi
    
    echo ""
    echo "📝 Steps that will be executed during setup:"
    
    local step_num=1
    
    # Step 1: Key generation
    if [ "$ssh_key_exists" = true ]; then
        echo "  ⏭️  Step $step_num: Skip SSH key generation (already exists)"
    else
        echo "  ▶️  Step $step_num: Generate SSH key at $KEY_PATH"
    fi
    step_num=$((step_num + 1))
    
    # Step 2: Copy key to server
    if [ "$key_auth_works" = true ]; then
        echo "  ⏭️  Step $step_num: Skip copying public key (already authorized on server)"
    else
        echo "  ▶️  Step $step_num: Copy public key to $SERVER_USER@$SERVER_HOST:$SERVER_PORT"
    fi
    step_num=$((step_num + 1))
    
    # Step 3: Add to agent
    if [ "$key_in_agent" = true ]; then
        echo "  ⏭️  Step $step_num: Skip adding key to ssh-agent (already loaded)"
    else
        echo "  ▶️  Step $step_num: Add key to ssh-agent"
    fi
    step_num=$((step_num + 1))
    
    # Step 4: Config entry
    if [ ! -z "$SSH_ALIAS" ]; then
        if [ "$config_entry_exists" = true ]; then
            echo "  ⏭️  Step $step_num: Skip SSH config entry creation (already exists for '$SSH_ALIAS')"
        else
            echo "  ▶️  Step $step_num: Create SSH config entry for alias '$SSH_ALIAS'"
        fi
    fi
    
    echo ""
    echo "=========================================="
    echo "✅ Sanity check complete. No changes made."
    echo "=========================================="
}

# Run actual SSH setup (wet-run mode)
# Performs the actual setup operations
run_setup() {
    echo "Starting SSH key setup..."
    echo ""
    
    # ========================================================================
    # CRITICAL EARLY CHECK: Do we already have SSH access to this server?
    # ========================================================================
    if [ "$FORCE_MODE" = false ]; then
        echo "🔍 Checking existing SSH access to $SERVER_USER@$SERVER_HOST..."
        echo ""
        
        if check_any_key_auth_works; then
            # We can already connect! Determine if it's the same key or different
            local key_auth_works=false
            check_key_auth_works && key_auth_works=true
            
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            if [ "$key_auth_works" = false ]; then
                # Different key is working
                echo "🚨 SSH ACCESS ALREADY EXISTS 🚨"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                echo "✅ You can already connect to $SERVER_USER@$SERVER_HOST"
                echo ""
                echo "This means a DIFFERENT SSH key is already configured."
                echo "The key configured in this script ($KEY_NAME) is NOT being used."
                echo ""
                echo "Creating another key will result in MULTIPLE keys for the same server,"
                echo "which can cause confusion and maintenance issues."
            else
                # Same key is working
                echo "✅ SSH ACCESS ALREADY CONFIGURED ✅"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                echo "✅ You can already connect to $SERVER_USER@$SERVER_HOST"
                echo ""
                echo "Your SSH key ($KEY_NAME) is already fully configured."
                if [ ! -z "$SSH_ALIAS" ]; then
                    echo ""
                    echo "You can connect right now using:"
                    echo "  ssh $SSH_ALIAS"
                fi
            fi
            
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "📌 WHAT DO YOU WANT TO DO?"
            echo ""
            echo "   Option 1: Exit (Recommended)"
            echo "   └─ Your connection works. Press Ctrl+C now."
            echo ""
            echo "   Option 2: Replace the existing key"
            echo "   ├─ Press Ctrl+C to exit"
            echo "   ├─ Run:  ./teardown_ssh_key.sh"
            echo "   └─ Then: ./setup_ssh_auto.sh"
            echo ""
            echo "   Option 3: Proceed anyway (not recommended)"
            echo "   └─ Type 'yes' below to continue"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            
            read -p "Type 'yes' to proceed (NOT recommended): " response
            echo ""
            
            if [ "$response" != "yes" ]; then
                echo "❌ Setup cancelled. No changes were made."
                echo ""
                if [ "$key_auth_works" = true ]; then
                    echo "💡 Your SSH connection is ready to use!"
                    if [ ! -z "$SSH_ALIAS" ]; then
                        echo "   Try: ssh $SSH_ALIAS"
                    fi
                else
                    echo "💡 TIP: If you want to replace the existing key, run:"
                    echo "   ./teardown_ssh_key.sh"
                fi
                exit 0
            fi
            
            echo "⚠️  Proceeding despite existing SSH access..."
            echo ""
        fi
    else
        echo "⚠️  FORCE MODE ENABLED - Skipping existing SSH access check"
        echo ""
    fi
    
    # Run remaining checks
    local ssh_key_exists=false
    local key_in_agent=false
    local config_entry_exists=false
    local key_auth_works=false
    
    check_ssh_key_exists && ssh_key_exists=true
    check_key_in_ssh_agent && key_in_agent=true
    check_ssh_config_entry_exists && config_entry_exists=true
    check_key_auth_works && key_auth_works=true
    
    local step_num=1
    
    # Step 1: Generate SSH key if it doesn't exist
    echo "Step $step_num: SSH Key Generation"
    if [ "$ssh_key_exists" = true ]; then
        echo "  ⏭️  SSH key already exists at $KEY_PATH - skipping generation"
    else
        generate_ssh_key
    fi
    echo ""
    step_num=$((step_num + 1))
    
    # Step 2: Copy public key to server
    echo "Step $step_num: Copy Public Key to Server"
    if [ "$key_auth_works" = true ]; then
        echo "  ⏭️  SSH key authentication already working on server - skipping"
    else
        copy_key_to_server
    fi
    echo ""
    step_num=$((step_num + 1))
    
    # Step 3: Add key to ssh-agent if not already added
    echo "Step $step_num: Add Key to SSH Agent"
    if [ "$key_in_agent" = true ]; then
        echo "  ⏭️  Key already loaded in ssh-agent - skipping"
    else
        add_key_to_ssh_agent
    fi
    echo ""
    step_num=$((step_num + 1))
    
    # Step 4: Create SSH config entry if alias is configured and entry doesn't exist
    if [ ! -z "$SSH_ALIAS" ]; then
        echo "Step $step_num: Create SSH Config Entry"
        if [ "$config_entry_exists" = true ]; then
            echo "  ⏭️  SSH config entry for '$SSH_ALIAS' already exists - skipping"
        else
            create_ssh_config_entry
        fi
        echo ""
    fi
    
    echo "=========================================="
    echo "✅ SSH key setup complete!"
    echo "=========================================="
    if [ ! -z "$SSH_ALIAS" ]; then
        echo "Test with: ssh $SSH_ALIAS"
    else
        echo "Test with: ssh $SERVER_USER@$SERVER_HOST"
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Execute appropriate mode
if [ "$SANITY_CHECK_MODE" = true ]; then
    run_sanity_check
    exit 0
else
    run_setup
fi

# Uncomment the line below to reset the config file to defaults
# reset_config