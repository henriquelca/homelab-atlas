#!/usr/bin/env bash
source /dev/stdin <<< "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/install.func)"
# Copyright (c) 2021-2026 community-scripts ORG
# Author: henriquelca
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/pewdiepie-archdaemon/odysseus

msg_info "Installing system dependencies"
$STD apt-get update
$STD apt-get install -y \
  git \
  curl \
  tmux \
  python3 \
  python3-pip \
  python3-venv \
  build-essential \
  libssl-dev \
  libffi-dev
msg_ok "Installed system dependencies"

msg_info "Cloning Odysseus repository"
rm -rf /opt/odysseus
$STD git clone https://github.com/pewdiepie-archdaemon/odysseus /opt/odysseus
msg_ok "Cloned Odysseus repository"

msg_info "Setting up Python virtual environment"
python3 -m venv /opt/odysseus/venv
source /opt/odysseus/venv/bin/activate
$STD pip install --upgrade pip
$STD pip install uvicorn
$STD pip install -r /opt/odysseus/requirements.txt
deactivate
msg_ok "Set up Python virtual environment"

msg_info "Running initial setup"
cd /opt/odysseus
source /opt/odysseus/venv/bin/activate
SETUP_OUTPUT=$(python3 setup.py 2>&1 || true)
ADMIN_PASS=$(echo "$SETUP_OUTPUT" | grep -oP '(?<=password:\s)\S+' || true)
deactivate
msg_ok "Ran initial setup"

msg_info "Setting up environment file"
if [[ ! -f /opt/odysseus/.env ]]; then
  cp /opt/odysseus/.env.example /opt/odysseus/.env
fi
msg_ok "Environment file ready"

msg_info "Creating systemd service"
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

$STD systemctl daemon-reload
systemctl enable -q --now odysseus
msg_ok "Created and started systemd service"

if [[ -n "$ADMIN_PASS" ]]; then
  echo "$ADMIN_PASS" >/root/.odysseus_admin_pass
  chmod 600 /root/.odysseus_admin_pass
fi
