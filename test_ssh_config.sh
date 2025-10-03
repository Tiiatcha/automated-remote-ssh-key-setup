# Test script to read ssh_setup.conf and display values in terminal

CONFIG_FILE="./ssh_setup.conf"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found: $CONFIG_FILE"
    exit 1
fi

# Load config
source "$CONFIG_FILE"

# Output values for confirmation
echo "=== SSH Setup Config Check ==="
echo "Server host      : $SERVER_HOST"
echo "Server port      : $SERVER_PORT"
echo "Server user      : $SERVER_USER"
echo "SSH key filename : $KEY_NAME"
if [ -z "$KEY_PASSPHRASE" ]; then
    echo "SSH key passphrase: (none)"
else
    echo "SSH key passphrase: (set)"
fi
if [ -z "$SSH_ALIAS" ]; then
    echo "SSH alias        : (none)"
else
    echo "SSH alias        : $SSH_ALIAS"
fi
echo "=============================="