#!/usr/bin/env bash
#
# setup-github-ssh.sh — Generate an SSH key and configure GitHub access
# Designed to be run interactively as the application user (not root).
#
set -euo pipefail

SSH_DIR="$HOME/.ssh"
KEY_FILE="$SSH_DIR/id_ed25519"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [ -f "$KEY_FILE" ]; then
    echo "SSH key already exists at $KEY_FILE"
else
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "$(whoami)@$(hostname)"
    echo ""
    echo "SSH key generated."
fi

chmod 600 "$KEY_FILE"
[ -f "$KEY_FILE.pub" ] && chmod 644 "$KEY_FILE.pub"

while true; do
    echo ""
    echo "Testing GitHub SSH connection using $KEY_FILE..."
    # GitHub prints "successfully authenticated" but still exits with status 1
    # because it doesn't provide an interactive shell. With `set -o pipefail`
    # enabled, that non-zero status would make the pipeline fail even when
    # authentication is actually working. Capture the output and ignore the
    # SSH exit code; treat the presence of the success message as success.
    ssh_output="$(ssh -i "$KEY_FILE" \
                        -o BatchMode=yes \
                        -o StrictHostKeyChecking=accept-new \
                        -T git@github.com 2>&1 || true)"
    echo "$ssh_output"
    if printf '%s\n' "$ssh_output" | grep -q "successfully authenticated"; then
        echo ""
        echo "GitHub SSH access confirmed!"
        echo "You are ready to clone private repositories and submodules."
        exit 0
    fi

    echo ""
    echo "GitHub SSH test failed."
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
    read -r -p "After adding the key to GitHub, press ENTER to re-test (Ctrl+C to abort)..." _
done
