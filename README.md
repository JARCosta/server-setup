# Server Setup

Automated deployment scripts for setting up a clean Ubuntu Server to run the experiments stack (Twitch bettors, Telegram bot, Discord bot).

## Quick Start

From a fresh Ubuntu Server install:

1. Log in once (password is fine the first time).
2. From **your local machine**, copy your SSH key to the server:

```bash
ssh-copy-id user@server-ip
```

3. On the server, run:

```bash
sudo apt install -y git
git clone https://github.com/JARCosta/server-setup.git ~/server-setup
cd ~/server-setup
sudo chmod +x setup.sh scripts/*.sh
sudo ./setup.sh
```

## What Gets Installed

| Step | Script | What it does |
|------|--------|-------------|
| 1 | `01-system.sh` | System update, essential packages, **Tailscale VPN**, SSH hardening, UFW firewall, fail2ban, timezone, swap, auto-updates |
| 2 | `02-python.sh` | Python 3.12 from deadsnakes PPA, dev headers, system libs |
| 3 | `03-app.sh` | Clone autolab repo to `~/autolab`, submodules, venv, pip install |
| 4 | `04-services.sh` | Systemd units `autolab` + `autolab-node`, daily reboot timer, `autolab` CLI |

## Tailscale Network Access

**Tailscale is now a core component** - it provides secure encrypted network access to your server.

### Connecting via Tailscale

1. **Login to Tailscale** on your local machine:
   ```bash
   tailscale login
   ```

2. **Connect to server** using Tailscale hostname (no public IP needed):
   ```bash
   ssh $USER@autolab
   ```

3. **Verify connection**:
   ```bash
   tailscale status
   ```

### Security Model

- **External access**: SSH key-only, no passwords (fail2ban protection)
- **Tailscale access**: Encrypted VPN tunnel (bypasses UFW restrictions)
- **Webapp**: Port 5000 accessible via Tailscale or LAN

**What's protected:**
- ✅ Brute force attacks (fail2ban, MaxAuthTries 3)
- ✅ Password authentication (disabled)
- ✅ Root login (disabled)
- ✅ Unnecessary services (X11 forwarding disabled)

**What Tailscale bypasses:**
- ✅ UFW incoming firewall rules
- ✅ SSH port restrictions (same encrypted network)

## Post-Install Steps

### 1. Start the application

```bash
autolab start
```

## Management Commands

The `autolab` helper is installed to `/usr/local/bin/autolab`:

```bash
# Main Autolab stack (Docker Compose, unit: autolab)
autolab start
autolab stop
autolab restart
autolab status          # may show `active (exited)` — normal: compose was started with `-d` and the unit stays “up” until stop
autolab logs          # journal: git pull + image build + container start only; then live `docker compose logs -f` for runtime
autolab journal       # systemd journal only

# Optional env: AUTOLAB_LOG_TAIL=1000  AUTOLAB_JOURNAL_BOOTSTRAP=200  autolab logs
# Manual equivalent from ~/autolab (lists running services, then follows all):
#   docker compose ps --services --status running | xargs -r docker compose logs -f --tail 500
# Hardware push node (Docker, unit: autolab-node — same as main: git pull + docker build on each start/restart)
autolab node start
autolab node stop
autolab node restart
autolab node status
autolab node logs   # journal bootstrap then docker logs -f, or journal -f if container down
autolab node journal
# Legacy alias: `autolab client …` does the same as `autolab node …`.
```

## Optional Components

Install extras individually or all at once:

```bash
sudo bash ~/server-setup/scripts/05-optional.sh ngrok       # ngrok tunneling
sudo bash ~/server-setup/scripts/05-optional.sh tesseract   # Tesseract OCR + Portuguese
sudo bash ~/server-setup/scripts/05-optional.sh ollama      # Ollama (LLM inference)
sudo bash ~/server-setup/scripts/05-optional.sh docker      # Docker CE
sudo bash ~/server-setup/scripts/05-optional.sh all         # Everything
```

## File Structure

```
server-setup/
├── setup.sh                          # Main entry point (run as root)
├── deploy/
│   └── linux/                        # systemd unit templates (__WORKDIR__, __SETUP_USER__)
├── config/
│   ├── requirements.txt              # Python dependencies
│   └── sshd_hardened.conf            # SSH hardening config (Tailscale-compatible)
└── scripts/
    ├── common.sh                     # Shared variables and helpers
    ├── 01-system.sh                  # System packages, **Tailscale**, SSH hardening, firewall, fail2ban
    ├── 02-python.sh                  # Python installation
    ├── 03-app.sh                     # App deployment
    ├── 04-services.sh                # Systemd services
    ├── 05-optional.sh                # Optional components (ngrok, tesseract, ollama)
    ├── disable-password-auth.sh      # Legacy helper (enforces key-only SSH)
    └── setup-github-ssh.sh           # GitHub SSH key helper
```

## Configuration

Override defaults by exporting environment variables before running `setup.sh`:

```bash
export REPO_URL="https://github.com/YourUser/YourRepo.git"
export APP_DIR="/opt/myapp"
export REPO_BRANCH="dev/jar"         # optional: branch name (defaults to main)
sudo -E ./setup.sh
```

## Module on/off

Autolab now runs as four docker-compose services (`autolab-web`,
`autolab-bettors`, `autolab-discord`, `autolab-wallapop`). The `autolab` unit
calls `scripts/start.sh` from the autolab repo, which reads
`data/modules.json` and starts only the enabled profiles.

Toggle modules from the home page (top-right of each card) and click
**Restart now**, or run `autolab restart` after editing `data/modules.json`
manually. `autolab-web` always runs (it hosts the toggle UI and Telegram
webhook).

## Firewall Ports

| Port | Service |
|------|---------|
| 22 | SSH |
| 5000 | Flask / Telegram webhook (`autolab-web`) |

## Logs

```bash
# Container streams (colors, like docker compose logs -f)
autolab logs
autolab node logs

# Or systemd journal only
autolab journal
sudo journalctl -u autolab -f
sudo journalctl -u autolab-node -f

# Setup log
cat /var/log/server-setup.log

# Fail2ban
sudo fail2ban-client status sshd
```
