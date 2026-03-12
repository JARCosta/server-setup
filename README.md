# Server Setup

Automated deployment scripts for setting up a clean Ubuntu Server to run the experiments stack (Twitch bettors, Telegram bot, Discord bot).

## Quick Start

From a fresh Ubuntu Server install, SSH in and run:

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
| 1 | `01-system.sh` | System update, essential packages, SSH hardening, UFW firewall, fail2ban, timezone, swap, auto-updates |
| 2 | `02-python.sh` | Python 3.12 from deadsnakes PPA, dev headers, system libs |
| 3 | `03-app.sh` | Clone repo to `~/experiments`, submodules, venv, pip install |
| 4 | `04-services.sh` | Systemd service with auto-restart, daily update timer, `exp` management command |

## Post-Install Steps

### 1. Set up SSH keys (from your local machine)

```bash
ssh-copy-id user@server-ip
```

Then disable password auth on the server:

```bash
sudo bash ~/server-setup/scripts/disable-password-auth.sh
```

### 2. Set up GitHub SSH (for private submodules)

```bash
bash ~/server-setup/scripts/setup-github-ssh.sh
```

This generates an ed25519 key, shows you the public key to add to GitHub, then tests the connection.

### 3. Clone credentials submodule

```bash
cd ~/experiments
git submodule update --init --recursive
```

### 4. Start the application

```bash
exp start
```

## Management Commands

The `exp` utility is installed to `/usr/local/bin/exp`:

```bash
exp start     # Start the application
exp stop      # Stop the application
exp restart   # Restart the application
exp status    # Show service status
exp logs      # Follow live logs (journalctl)
exp update    # Git pull and restart
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
├── config/
│   ├── requirements.txt              # Python dependencies
│   └── sshd_hardened.conf            # SSH hardening config
└── scripts/
    ├── common.sh                     # Shared variables and helpers
    ├── 01-system.sh                  # System packages & hardening
    ├── 02-python.sh                  # Python installation
    ├── 03-app.sh                     # App deployment
    ├── 04-services.sh                # Systemd services
    ├── 05-optional.sh                # Optional components
    ├── disable-password-auth.sh      # Lock down SSH after key setup
    └── setup-github-ssh.sh           # GitHub SSH key helper
```

## Configuration

Override defaults by exporting environment variables before running `setup.sh`:

```bash
export REPO_URL="https://github.com/YourUser/YourRepo.git"
export APP_DIR="/opt/myapp"
sudo -E ./setup.sh
```

## Firewall Ports

| Port | Service |
|------|---------|
| 22 | SSH |
| 5000 | Flask / Telegram webhook |

## Logs

```bash
# Application logs
sudo journalctl -u experiments -f

# Setup log
cat /var/log/server-setup.log

# Fail2ban
sudo fail2ban-client status sshd
```
