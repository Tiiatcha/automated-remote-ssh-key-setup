#!/bin/bash
# Fully automated SSH key setup reading from a config file

# --- Config file location ---
CONFIG_FILE="./ssh_setup.conf"

# --- Backup SSH config function ---
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

# --- Load config ---
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# Paths
KEY_PATH="$HOME/.ssh/$KEY_NAME"

# --- 1. Generate SSH key if it doesn't exist ---
if [ ! -f "$KEY_PATH" ]; then
    echo "Generating SSH key at $KEY_PATH..."
    if [ -z "$KEY_PASSPHRASE" ]; then
        ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$USER@$HOSTNAME" -N ""
    else
        ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$USER@$HOSTNAME" -N "$KEY_PASSPHRASE"
    fi
else
    echo "SSH key already exists at $KEY_PATH"
fi

# --- 2. Copy public key to server ---
echo "Copying public key to $SERVER_USER@$SERVER_HOST..."
ssh-copy-id -i "${KEY_PATH}.pub" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST"

# --- 3. Add key to ssh-agent ---
echo "Adding key to ssh-agent..."
# eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain "$KEY_PATH"

# --- 4. (Optional) Create SSH config entry ---
if [ ! -z "$SSH_ALIAS" ]; then    
    CONFIG_SSH="$HOME/.ssh/config"
    if ! grep -q "Host $SSH_ALIAS" "$CONFIG_SSH" 2>/dev/null; then
        # Backup SSH config before modification
        backup_ssh_config
        echo "Adding SSH config entry..."
        cat <<EOL >> "$CONFIG_SSH"

Host $SSH_ALIAS
  HostName $SERVER_HOST
  User $SERVER_USER
  Port $SERVER_PORT
  UseKeychain yes
  AddKeysToAgent yes
  IdentityFile $KEY_PATH
EOL
    else
        echo "SSH config entry for $SSH_ALIAS already exists."
    fi
fi

# --- 5. Reset config file to default template ---
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
KEY_PASSPHRASE=""

# Optional SSH alias
SSH_ALIAS="myserver"
EOL
    echo "✅ Config file has been reset to default values."
}

reset_config

echo "✅ SSH key setup complete! Test with: ssh $SSH_ALIAS (or ssh $SERVER_USER@$SERVER_HOST)"