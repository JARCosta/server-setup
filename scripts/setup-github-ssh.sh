#!/usr/bin/env bash
#
# setup-github-ssh.sh — Generate an SSH key and configure GitHub access
# Run as the application user (not root):
#   bash server-setup/scripts/setup-github-ssh.sh
#
set -euo pipefail

SSH_DIR="$HOME/.ssh"
KEY_FILE="$SSH_DIR/id_ed25519"

if [ -f "$KEY_FILE" ]; then
    echo "SSH key already exists at $KEY_FILE"
else
    echo "Generating SSH key..."
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "$(whoami)@$(hostname)"
    echo ""
    echo "SSH key generated."
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Add this public key to GitHub:"
echo "  https://github.com/settings/ssh/new"
echo "═══════════════════════════════════════════════════"
echo ""
cat "$KEY_FILE.pub"
echo ""
echo "═══════════════════════════════════════════════════"
echo ""

read -p "Press Enter after adding the key to GitHub..."

echo "Testing GitHub connection..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "GitHub SSH access confirmed!"
    echo ""
    echo "Now initialize all submodules:"
    echo "  cd ~/experiments && git submodule update --init --recursive"
else
    echo "GitHub SSH test failed. Check that you added the key correctly."
    exit 1
fi
