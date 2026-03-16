#!/usr/bin/env bash
#
# 03-app.sh — Clone the repository, set up submodules, create venv, install deps
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/common.sh"

# ── Clone repository ────────────────────────────────────────
if [ -d "$APP_DIR/.git" ]; then
    log "Repository already exists at $APP_DIR, pulling latest for branch ${REPO_BRANCH}..."
    sudo -u "$SETUP_USER" bash -c "cd $APP_DIR && git fetch origin && git checkout \"$REPO_BRANCH\" && git pull --ff-only origin \"$REPO_BRANCH\""
else
    log "Cloning repository branch ${REPO_BRANCH} to $APP_DIR..."
    sudo -u "$SETUP_USER" git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$APP_DIR"
fi

# ── Ensure GitHub SSH for private submodules ────────────────
log "Ensuring GitHub SSH access for private GitHub repositories..."
sudo -u "$SETUP_USER" env HOME="$SETUP_HOME" bash "$ROOT_DIR/scripts/setup-github-ssh.sh"

# ── Submodules (public + private) ───────────────────────────
log "Initializing submodules (public + private) recursively..."
cd "$APP_DIR"
sudo -u "$SETUP_USER" env HOME="$SETUP_HOME" git submodule update --init --recursive

ok "Application repository deployed to $APP_DIR (Dockerized autolab stack)"
