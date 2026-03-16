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

# ── Main application service (autolab via Docker) ───────────
log "Creating systemd service for autolab (Docker Compose)..."

cat > /etc/systemd/system/autolab.service << EOF
[Unit]
Description=Autolab - Twitch Bettor, Telegram Bot, Discord Bot (Docker)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SETUP_USER}
Group=${SETUP_USER}
WorkingDirectory=${APP_DIR}

ExecStartPre=/usr/bin/bash -c 'cd ${APP_DIR} && git fetch origin && git pull --ff-only || true'
ExecStart=/usr/bin/docker compose up --build
ExecStop=/usr/bin/docker compose down

Restart=on-failure
RestartSec=30
StartLimitBurst=5
StartLimitIntervalSec=300

StandardOutput=journal
StandardError=journal
SyslogIdentifier=autolab

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=${APP_DIR}
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# ── Daily system reboot (06:10) ──────────────────────────────
log "Creating daily reboot timer (06:10)..."

cat > /etc/systemd/system/daily-reboot.service << EOF
[Unit]
Description=Daily system reboot

[Service]
Type=oneshot
ExecStart=/usr/sbin/reboot
EOF

cat > /etc/systemd/system/daily-reboot.timer << EOF
[Unit]
Description=Run daily system reboot at 06:10

[Timer]
OnCalendar=*-*-* 06:10:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# ── Enable services ─────────────────────────────────────────
log "Enabling services..."
systemctl daemon-reload
systemctl enable autolab.service
systemctl enable --now daily-reboot.timer

# Auto-start if credentials + Docker permissions are ready
if autolab_credentials_ready && docker_ready_for_user; then
    log "Credentials detected and Docker access OK for ${SETUP_USER}; starting autolab..."
    systemctl start autolab.service
    ok "Service 'autolab' started"
else
    warn "Service 'autolab' is enabled but NOT started."
    if ! [[ -f "${APP_DIR}/.env" ]]; then
        warn "Missing ${APP_DIR}/.env (create it from .env.example)"
    elif ! autolab_credentials_ready; then
        warn "Credentials in ${APP_DIR}/.env look incomplete (need TELEGRAM_NOTIFICATION_TOKEN and TELEGRAM_USER_ID at minimum)"
    fi
    if ! docker_ready_for_user; then
        warn "Docker may not be ready for user ${SETUP_USER} (daemon inactive or user lacks permission)."
        warn "Fix: ensure Docker is installed/running and ${SETUP_USER} is in the 'docker' group, then re-run: sudo systemctl start autolab"
    else
        warn "Start it manually:  sudo systemctl start autolab"
    fi
fi

# ── Management script ──────────────────────────────────────
log "Creating management helper..."
cat > /usr/local/bin/exp << 'MGMT'
#!/usr/bin/env bash
case "${1:-}" in
    start)   sudo systemctl start autolab ;;
    stop)    sudo systemctl stop autolab ;;
    restart) sudo systemctl restart autolab ;;
    status)  sudo systemctl status autolab ;;
    logs)    sudo journalctl -u autolab -f --no-hostname ;;
    *)
        echo "Usage: exp {start|stop|restart|status|logs}"
        echo ""
        echo "  start    Start the autolab Docker stack"
        echo "  stop     Stop the autolab Docker stack"
        echo "  restart  Restart the autolab Docker stack"
        echo "  status   Show autolab service status"
        echo "  logs     Follow live autolab logs"
        ;;
esac
MGMT
chmod +x /usr/local/bin/exp

ok "Systemd services configured"
ok "Use 'exp' command for quick management (exp start/stop/restart/status/logs/update)"
