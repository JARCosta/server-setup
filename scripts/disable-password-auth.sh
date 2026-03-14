#!/usr/bin/env bash
#
# disable-password-auth.sh — Legacy helper (setup.sh now enforces key-only SSH)
#
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/common.sh"

if [[ $EUID -ne 0 ]]; then
    err "Run as root: sudo bash $0"
    exit 1
fi

CONF="/etc/ssh/sshd_config.d/99-hardened.conf"

sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$CONF" || true
echo "PasswordAuthentication no" >> "$CONF"
systemctl restart ssh || systemctl restart sshd
ok "Password authentication disabled. SSH key login only."
