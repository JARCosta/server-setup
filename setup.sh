#!/usr/bin/env bash
#
# Main setup orchestrator for Ubuntu Server.
# Run this once on a clean Ubuntu Server install:
#   curl -sSL <raw-github-url>/setup.sh | bash
#   OR
#   git clone <repo> ~/server-setup && cd ~/server-setup && chmod +x setup.sh && ./setup.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/server-setup.log"

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG_FILE"; }
err()  { echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE"; }

run_step() {
    local script="$1"
    local name="$2"
    log "────────────────────────────────────────────"
    log "Running: ${name}"
    log "────────────────────────────────────────────"
    if bash "$SCRIPT_DIR/scripts/$script"; then
        ok "$name completed"
    else
        err "$name FAILED (exit code: $?)"
        err "Check $LOG_FILE for details"
        exit 1
    fi
}

# ── Pre-flight checks ──────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)"
    exit 1
fi

if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
    warn "This script is designed for Ubuntu. Proceed at your own risk."
fi

# Detect the actual user (the one who ran sudo)
export SETUP_USER="${SUDO_USER:-$(whoami)}"
export SETUP_HOME="$(eval echo ~$SETUP_USER)"
export APP_DIR="${APP_DIR:-${SETUP_HOME}/autolab}"
export VENV_DIR="${VENV_DIR:-${APP_DIR}/.venv}"
export REPO_URL="${REPO_URL:-git@github.com:JARCosta/autolab.git}"
export REPO_BRANCH="${REPO_BRANCH:-main}"

# Require SSH key-based login to be set up for the setup user
if ! [ -f "${SETUP_HOME}/.ssh/authorized_keys" ] || ! [ -s "${SETUP_HOME}/.ssh/authorized_keys" ]; then
    err "No SSH public key found for ${SETUP_USER} at ${SETUP_HOME}/.ssh/authorized_keys."
    err "Set up SSH keys from your local machine first, e.g.:"
    err "  ssh-copy-id ${SETUP_USER}@<server-ip>"
    exit 1
fi

log "Setup starting for user: $SETUP_USER"
log "Home directory: $SETUP_HOME"
log "Application directory: $APP_DIR"
log "Repository: $REPO_URL"
log "Branch: ${REPO_BRANCH}"
echo ""

# ── Run setup steps ────────────────────────────────────────
run_step "01-system.sh"   "System packages & hardening"
run_step "02-python.sh"   "Python environment"
run_step "03-app.sh"      "Application deployment"

# Optional: install Docker automatically if missing (so autolab.service can run)
if ! command -v docker >/dev/null 2>&1; then
    warn "Docker not detected; installing via optional docker component..."
    bash "$SCRIPT_DIR/scripts/05-optional.sh" docker || {
        err "Docker installation failed. You can retry later with:"
        err "  sudo bash $SCRIPT_DIR/scripts/05-optional.sh docker"
    }
else
    ok "Docker already installed"
fi

run_step "04-services.sh" "Systemd services"

echo ""
log "════════════════════════════════════════════"
ok  "Setup complete!"
log "════════════════════════════════════════════"
echo ""
log "Tailscale network access:"
log "  Login to Tailscale:    tailscale login"
log "  Check status:          tailscale status"
log "  Connect to server:     ssh $SETUP_USER@autolab"
echo ""
log "Quick reference:"
log "  SSH into server:     ssh $SETUP_USER@<server-ip>"
log "  App directory:       $APP_DIR"
log "  Manage main stack:   autolab {start|stop|restart|status|logs|journal}"
log "  Manage node:         autolab node {start|stop|restart|status|logs|journal}  (alias: autolab client)"
log "  View app logs:       autolab logs  (docker compose; colors)  or  autolab journal"
log "  Restart app:         sudo systemctl restart autolab"
log "  App status:          sudo systemctl status autolab"
log "  Node service:        sudo systemctl status autolab-node"
echo ""

