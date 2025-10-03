# Automated Remote SSH Key Setup

Scripts to automate the process of setting up passwordless SSH login to remote servers.  
This is useful for developers who want quick and secure access to servers from the terminal, VS Code, Cursor, or other tools without repeatedly entering passwords.

## 📋 Table of Contents

- [Automated Remote SSH Key Setup](#automated-remote-ssh-key-setup)
  - [📋 Table of Contents](#-table-of-contents)
  - [🚀 Features](#-features)
  - [📂 Files](#-files)
  - [🛠 Usage](#-usage)
    - [1. Clone the repo](#1-clone-the-repo)
    - [2. Configure Server Details (for automation only)](#2-configure-server-details-for-automation-only)
    - [3. Make scripts executable](#3-make-scripts-executable)
    - [4. Test config values (optional)](#4-test-config-values-optional)
    - [5. Run the script](#5-run-the-script)
    - [6. Test the connection](#6-test-the-connection)

---

## 🚀 Features

- Generates a new SSH key pair for this server (if one doesn’t exist).
- Copy the public key to a remote server.
- Add the private key to `ssh-agent` for passwordless use.
- Optionally create a neat alias in `~/.ssh/config`.
- Two usage modes:
  - **Interactive:** prompts for server and key details.
    - You will be asked for the:
      - Server Host (address/ip)
      - Server Port
      - Sever user name on the server you wish to login as
      - Key name (you want to give ssh key (usefull when setting up multiple servers))
      - Key Passphrase (Optional)
      - SSH Alias - this allows you to log in with `ssh my_easy_to_remember_server_alias` rather than `ssh user@my_not_so_easy_to_remember_server_name`
  - **Automated:** reads everything from a `ssh_setup.conf` file.

---

## 📂 Files

- `setup_ssh_auto.sh` → Automated setup using values from `ssh_setup.conf`.
- `test_ssh_config.sh` → Sanity-check that config values are read correctly.
- `ssh_setup.conf` → Example config file (fill with server details before running `setup_ssh_auto.sh`).

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

Before you run for the first time, run the following commands in the terminal(you don't need both `ssh_setup_auto.sh` and `setup_ssh.sh` to be executable, just the one you choose to run):

```bash
chmod +x setup_ssh_auto.sh
chmod +x setup_ssh.sh
chmod +x test_ssh_config.sh
```

### 4. Test config values (optional)

If you are running `setup_ssh_auto` and using the `ssh_setup.conf` file, you can run a sanity test with the following command (assuming you made `test_ssh_config.sh` executable in the previous step).

```bash
./test_ssh_config.sh
```

### 5. Run the script

When you are ready, run the chosen script (`setup_ssh.sh` or `setup_ssh_auto`.sh'):

```bash
./setup_ssh_auto.sh
```

You will be asked for the password of the remote user during the setup and possibly the passphrase.
or

```bash
./setup_ssh.sh
```

Doing it this way, you will be prompted for all values during the setup.

### 6. Test the connection

You should now be able to connect to the server via ssh either in the terminal or your ide or other tools by typing the command below with out entering any passwords or passphrases:

```bash
# If you have set an alias
ssh myserveralias
# If no alias set
ssh user@myserver
```
