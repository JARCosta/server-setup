#!/usr/bin/env bash
#
# disable-password-auth.sh — Run after setting up SSH keys to disable password login
#
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/common.sh"

if [[ $EUID -ne 0 ]]; then
    err "Run as root: sudo bash $0"
    exit 1
fi

CONF="/etc/ssh/sshd_config.d/99-hardened.conf"

if [ -f "${SETUP_HOME}/.ssh/authorized_keys" ] && [ -s "${SETUP_HOME}/.ssh/authorized_keys" ]; then
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' "$CONF"
    systemctl restart sshd
    ok "Password authentication disabled. SSH key login only."
else
    err "No SSH keys found in ${SETUP_HOME}/.ssh/authorized_keys"
    err "Add your key first:  ssh-copy-id ${SETUP_USER}@<server-ip>"
    exit 1
fi
