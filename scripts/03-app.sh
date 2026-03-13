#!/usr/bin/env bash
#
# 03-app.sh — Clone the repository, set up submodules, create venv, install deps
#
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/common.sh"

# ── Clone repository ────────────────────────────────────────
if [ -d "$APP_DIR/.git" ]; then
    log "Repository already exists at $APP_DIR, pulling latest for branch ${REPO_BRANCH}..."
    sudo -u "$SETUP_USER" bash -c "cd $APP_DIR && git fetch origin && git checkout \"$REPO_BRANCH\" && git pull --ff-only origin \"$REPO_BRANCH\""
else
    log "Cloning repository branch ${REPO_BRANCH} to $APP_DIR..."
    sudo -u "$SETUP_USER" git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$APP_DIR"
fi

# ── Submodules (public + private) ─────────────────────────────
log "Initializing submodules (this may require GitHub SSH access)..."
cd "$APP_DIR"
if ! sudo -u "$SETUP_USER" env HOME="$SETUP_HOME" git submodule update --init --recursive; then
    warn "Submodule initialization failed (likely missing GitHub SSH access for private repos)"
    warn "After fixing SSH, run: cd $APP_DIR && git submodule update --init --recursive"
fi

# ── Create virtual environment ──────────────────────────────
log "Creating Python virtual environment..."
sudo -u "$SETUP_USER" python3 -m venv "$VENV_DIR"

# ── Install pip dependencies ────────────────────────────────
log "Installing Python dependencies..."
REQUIREMENTS_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/requirements.txt"
sudo -u "$SETUP_USER" "$VENV_DIR/bin/pip" install --upgrade pip
sudo -u "$SETUP_USER" "$VENV_DIR/bin/pip" install -r "$REQUIREMENTS_FILE"

# Install submodule-specific requirements if they exist
for subdir in BoostBot ocr wheelchair_detector; do
    if [ -f "$APP_DIR/$subdir/requirements.txt" ]; then
        log "Installing $subdir dependencies..."
        sudo -u "$SETUP_USER" "$VENV_DIR/bin/pip" install -r "$APP_DIR/$subdir/requirements.txt" || warn "$subdir deps install had issues"
    fi
done

# ── Create resource directories ─────────────────────────────
log "Creating resource directories..."
sudo -u "$SETUP_USER" mkdir -p "$APP_DIR/telegramBot/resources"
sudo -u "$SETUP_USER" mkdir -p "$APP_DIR/streamElements/resources"

# ── Ensure startup.sh is executable ────────────────────────
chmod +x "$APP_DIR/startup.sh" 2>/dev/null || true

ok "Application deployed to $APP_DIR"
