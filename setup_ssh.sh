#!/bin/bash
# Interactive SSH passwordless setup script

# --- Prompt for information ---
read -p "Enter server host (e.g., server.example.com or ip address): " SERVER_HOST
read -p "Enter server port [22]: " SERVER_PORT
SERVER_PORT=${SERVER_PORT:-22}
read -p "Enter server username: " SERVER_USER
read -p "Enter SSH key filename (will be stored in ~/.ssh/): " KEY_NAME
KEY_PATH="$HOME/.ssh/$KEY_NAME"
read -s -p "Enter passphrase for the key (leave empty for none): " KEY_PASSPHRASE
echo

# Optional SSH alias for ~/.ssh/config
read -p "Enter SSH alias for config (optional, e.g., myserver): " SSH_ALIAS

# --- 1. Generate SSH key if it doesn't exist ---
if [ ! -f "$KEY_PATH" ]; then
    echo "Generating SSH key..."
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
echo "You will be prompted for your password on the server."
ssh-copy-id -i "${KEY_PATH}.pub" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST"

# --- 3. Add key to ssh-agent ---
echo "Adding key to ssh-agent..."
eval "$(ssh-agent -s)"
ssh-add "$KEY_PATH"

# --- 4. (Optional) Create SSH config entry ---
if [ ! -z "$SSH_ALIAS" ]; then
    CONFIG_FILE="$HOME/.ssh/config"
    if ! grep -q "Host $SSH_ALIAS" "$CONFIG_FILE" 2>/dev/null; then
        echo "Adding SSH config entry..."
        cat <<EOL >> "$CONFIG_FILE"

Host $SSH_ALIAS
    HostName $SERVER_HOST
    User $SERVER_USER
    Port $SERVER_PORT
    IdentityFile $KEY_PATH
EOL
    else
        echo "SSH config entry for $SSH_ALIAS already exists."
    fi
fi

echo "✅ SSH key setup complete! Test with: ssh $SSH_ALIAS (or ssh $SERVER_USER@$SERVER_HOST)"