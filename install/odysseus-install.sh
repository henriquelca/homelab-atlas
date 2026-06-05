#!/usr/bin/env bash
# Copyright (c) 2026 henriquelca
# Author: henriquelca
# License: MIT
# Source: https://github.com/pewdiepie-archdaemon/odysseus

# ─── Bootstrap ────────────────────────────────────────────────────────────────
# Must run before sourcing install.func since curl may not exist yet
echo "  [DEBUG] Starting bootstrap — updating apt and installing curl"
apt-get update -qq
apt-get install -y -qq curl
echo "  [DEBUG] Bootstrap complete — curl installed"

source <(curl -fsSL https://raw.githubusercontent.com/henriquelca/homelab-atlas/main/misc/install.func)

# ─── Setup ────────────────────────────────────────────────────────────────────
app="odysseus"
catch_errors
setting_up_container
update_os

msg_debug "Starting Odysseus install — app=${app}"

msg_info "Installing system dependencies"
msg_debug "Running apt-get install for: git tmux python3 python3-pip python3-venv build-essential libssl-dev libffi-dev"
apt-get install -y -qq \
  git tmux \
  python3 python3-pip python3-venv \
  build-essential libssl-dev libffi-dev
msg_ok "Installed system dependencies"

msg_info "Cloning Odysseus repository"
msg_debug "Running: git clone https://github.com/pewdiepie-archdaemon/odysseus /opt/odysseus"
rm -rf /opt/odysseus
git clone -q https://github.com/pewdiepie-archdaemon/odysseus /opt/odysseus
msg_debug "Clone complete — files: $(ls /opt/odysseus)"
msg_ok "Cloned Odysseus repository"

msg_info "Setting up Python virtual environment"
msg_debug "Creating venv at /opt/odysseus/venv"
python3 -m venv /opt/odysseus/venv
source /opt/odysseus/venv/bin/activate
msg_debug "venv activated — pip version: $(pip --version)"
pip install --upgrade pip
pip install uvicorn
msg_debug "Installing requirements from /opt/odysseus/requirements.txt"
pip install -r /opt/odysseus/requirements.txt
msg_debug "Installing bcrypt explicitly"
pip install bcrypt
deactivate
msg_ok "Set up Python virtual environment"

msg_info "Running initial setup"
msg_debug "Running setup.py non-interactively via env vars"
cd /opt/odysseus
source /opt/odysseus/venv/bin/activate
# Set env vars so setup.py skips all prompts and uses defaults
SETUP_OUTPUT=$(ODYSSEUS_ADMIN_USER=admin timeout 60 python3 setup.py 2>&1 || true)
msg_debug "setup.py full output: ${SETUP_OUTPUT}"
# Extract password — it appears on a line after "Admin password:"
ADMIN_PASS=$(echo "$SETUP_OUTPUT" | grep -A1 -i "admin password" | tail -1 | tr -d ' 	' || true)
# Fallback: grab any standalone token that looks like a password (8+ chars, mixed case)
if [[ -z "$ADMIN_PASS" ]]; then
  ADMIN_PASS=$(echo "$SETUP_OUTPUT" | grep -i "password" | grep -oE "[A-Za-z0-9]{10,}" | tail -1 || true)
fi
msg_debug "Captured admin password: ${ADMIN_PASS:-<not captured>}"
deactivate
msg_ok "Ran initial setup"

msg_info "Setting up environment file"
msg_debug "Checking for /opt/odysseus/.env.example"
if [[ ! -f /opt/odysseus/.env.example ]]; then
  msg_warn ".env.example not found — skipping env file copy"
else
  if [[ ! -f /opt/odysseus/.env ]]; then
    cp /opt/odysseus/.env.example /opt/odysseus/.env
    msg_debug "Copied .env.example to .env"
  else
    msg_debug ".env already exists — skipping copy"
  fi
fi
msg_ok "Environment file ready"

msg_info "Creating systemd service"
msg_debug "Writing /etc/systemd/system/odysseus.service"
cat <<EOF >/etc/systemd/system/odysseus.service
[Unit]
Description=Odysseus AI Workspace
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/odysseus
EnvironmentFile=-/opt/odysseus/.env
ExecStart=/opt/odysseus/venv/bin/uvicorn app:app --host 0.0.0.0 --port 7000
Restart=on-failure
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
msg_debug "Enabling and starting odysseus service"
systemctl enable -q --now odysseus
msg_debug "Service status: $(systemctl is-active odysseus)"
msg_ok "Created and started systemd service"

if [[ -n "${ADMIN_PASS:-}" ]]; then
  echo "$ADMIN_PASS" >/root/.odysseus_admin_pass
  chmod 600 /root/.odysseus_admin_pass
  msg_debug "Admin password saved to /root/.odysseus_admin_pass"
  msg_ok "Admin credentials: username=admin  password=${ADMIN_PASS}"
else
  msg_warn "Could not capture admin password — check setup.py output above"
  msg_warn "You can rerun setup manually: cd /opt/odysseus && source venv/bin/activate && python3 setup.py"
fi

motd_ssh
msg_debug "motd_ssh complete"
customize
msg_debug "customize complete — update command installed at /usr/bin/update"

msg_ok "Odysseus installation complete"
