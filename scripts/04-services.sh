#!/usr/bin/env bash
#
# 04-services.sh — Create systemd services for the application
#
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/common.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

has_nonempty_env_var() {
    local env_file="$1"
    local key="$2"
    # Accept KEY=value or KEY="value" (ignores comments and blanks)
    local val
    val="$(awk -F= -v k="$key" '
        $0 ~ /^[[:space:]]*#/ { next }
        $0 ~ /^[[:space:]]*$/ { next }
        $1 == k { $1=""; sub(/^=/,""); gsub(/^[ \t"]+|[ \t"]+$/,""); print; exit }
    ' "$env_file" 2>/dev/null || true)"
    [[ -n "${val:-}" ]]
}

autolab_credentials_ready() {
    local env_file="${APP_DIR}/.env"
    [[ -f "$env_file" ]] || return 1

    # Minimal set required for the bot features to function in practice.
    # (If you want stricter/looser checks, adjust this list.)
    has_nonempty_env_var "$env_file" "TELEGRAM_NOTIFICATION_TOKEN" || return 1
    has_nonempty_env_var "$env_file" "TELEGRAM_USER_ID" || return 1
    return 0
}

docker_ready_for_user() {
    command -v docker >/dev/null 2>&1 || return 1
    systemctl is-active --quiet docker 2>/dev/null || return 1
    sudo -u "$SETUP_USER" docker info >/dev/null 2>&1 || return 1
    return 0
}

# Install unit templates from deploy/linux/ (__WORKDIR__, __SETUP_USER__)
DEPLOY_LINUX="${SCRIPT_DIR}/deploy/linux"

install_rendered_unit() {
    local template_name="$1"
    local workdir="$2"
    local dest="/etc/systemd/system/${template_name}"
    sed -e "s|__WORKDIR__|${workdir}|g" -e "s|__SETUP_USER__|${SETUP_USER}|g" \
        "${DEPLOY_LINUX}/${template_name}" >"$dest"
}

# If already running, restart so unit file edits and daemon-reload actually take effect (start is a no-op).
start_or_restart_unit() {
    local unit="$1"
    if systemctl is-active --quiet "$unit" 2>/dev/null; then
        log "$unit already active; restarting to apply unit changes..."
        systemctl restart "$unit"
    else
        systemctl start "$unit"
    fi
}

NODE_DIR="${APP_DIR}/autolab-node"

# ── Main application service (autolab via Docker) ───────────
log "Installing systemd units from ${DEPLOY_LINUX}..."
install_rendered_unit "autolab.service" "$APP_DIR"

# ── Legacy unit (replaced by autolab-node) ──────────────────
if [[ -f /etc/systemd/system/autolab-client.service ]]; then
    log "Disabling legacy autolab-client.service (use autolab-node.service)..."
    systemctl disable --now autolab-client.service 2>/dev/null || true
    rm -f /etc/systemd/system/autolab-client.service
fi

# ── Hardware push node (Docker) ─────────────────────────────
install_rendered_unit "autolab-node.service" "$NODE_DIR"

# ── Daily system reboot (06:10) ──────────────────────────────
log "Installing daily reboot timer (06:10)..."
cp -a "${DEPLOY_LINUX}/daily-reboot.service" /etc/systemd/system/daily-reboot.service
cp -a "${DEPLOY_LINUX}/daily-reboot.timer" /etc/systemd/system/daily-reboot.timer

# ── Enable services ─────────────────────────────────────────
log "Enabling services..."
log "Running systemctl daemon-reload (pick up unit files under /etc/systemd/system)..."
systemctl daemon-reload
systemctl enable autolab.service
systemctl enable autolab-node.service
systemctl enable --now daily-reboot.timer

# Auto-start if credentials + Docker permissions are ready
if autolab_credentials_ready && docker_ready_for_user; then
    log "Credentials detected and Docker access OK for ${SETUP_USER}; starting autolab..."
    if start_or_restart_unit autolab.service; then
        ok "Service 'autolab' is up"
    else
        warn "autolab failed to start or restart; see: systemctl status autolab"
    fi
else
    warn "Service 'autolab' is enabled but NOT started."
    if ! [[ -f "${APP_DIR}/.env" ]]; then
        warn "Missing ${APP_DIR}/.env (create it from .env.example)"
    elif ! autolab_credentials_ready; then
        warn "Credentials in ${APP_DIR}/.env look incomplete (need TELEGRAM_NOTIFICATION_TOKEN and TELEGRAM_USER_ID at minimum)"
    elif ! docker_ready_for_user; then
        warn "Docker may not be ready for user ${SETUP_USER} (daemon inactive or user lacks permission)."
        warn "Fix: ensure Docker is installed/running and ${SETUP_USER} is in the 'docker' group, then re-run: sudo systemctl start autolab"
    fi
fi

# Auto-start node when Docker is ready and node .env exists (unit runs git pull + docker build like autolab)
if [[ -f "${NODE_DIR}/.env" ]] && docker_ready_for_user; then
    log "autolab-node .env present; starting autolab-node..."
    if start_or_restart_unit autolab-node.service; then
        ok "Service 'autolab-node' is up"
    else
        warn "autolab-node failed to start (check: journalctl -u autolab-node -b; verify ${NODE_DIR} has a Dockerfile and git remote)"
    fi
else
    warn "Service 'autolab-node' is enabled but NOT started."
    if ! [[ -f "${NODE_DIR}/.env" ]]; then
        warn "Missing ${NODE_DIR}/.env — create it before starting the node."
    elif ! docker_ready_for_user; then
        warn "Docker not ready for ${SETUP_USER}; fix Docker permissions, then: sudo systemctl start autolab-node"
    fi
fi

# ── Management script ──────────────────────────────────────
log "Creating management helper..."
rm -f /usr/local/bin/exp
cp -a "${DEPLOY_LINUX}/autolab-cli.sh" /usr/local/bin/autolab
sed -i "s|__AUTOLAB_APP_DIR__|${APP_DIR//|/\\|}|g" /usr/local/bin/autolab
chmod +x /usr/local/bin/autolab

ok "Systemd services configured"
ok "Use 'autolab' for quick management (main stack + 'autolab node …' for the hardware node; 'autolab client' is an alias)"
