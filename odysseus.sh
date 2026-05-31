#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: henriquelca
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/pewdiepie-archdaemon/odysseus

APP="Odysseus"
var_tags="${var_tags:-ai;workspace}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-20}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/odysseus ]]; then
    msg_error "No ${APP} Installation Found!"
    exit 1
  fi

  msg_info "Checking for updates"
  CURRENT=$(git -C /opt/odysseus rev-parse HEAD)
  LATEST=$(git ls-remote https://github.com/pewdiepie-archdaemon/odysseus HEAD | cut -f1)

  if [[ "$CURRENT" == "$LATEST" ]]; then
    msg_ok "No update available — already on latest commit."
    exit 0
  fi
  msg_ok "Update available — proceeding"

  msg_info "Stopping Odysseus Service"
  systemctl stop odysseus
  msg_ok "Stopped Service"

  msg_info "Pulling latest changes"
  cd /opt/odysseus
  $STD git pull origin main
  msg_ok "Pulled latest changes"

  msg_info "Updating Python dependencies"
  source /opt/odysseus/venv/bin/activate
  $STD pip install --upgrade -r /opt/odysseus/requirements.txt
  deactivate
  msg_ok "Updated Python dependencies"

  msg_info "Starting Odysseus Service"
  systemctl start odysseus
  msg_ok "Started Service"

  msg_ok "Updated successfully!"
  exit 0
}

function install_odysseus() {
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
  $STD git clone https://github.com/pewdiepie-archdaemon/odysseus /opt/odysseus
  msg_ok "Cloned Odysseus repository"

  msg_info "Setting up Python virtual environment"
  python3 -m venv /opt/odysseus/venv
  source /opt/odysseus/venv/bin/activate
  $STD pip install --upgrade pip
  $STD pip install -r /opt/odysseus/requirements.txt
  deactivate
  msg_ok "Set up Python virtual environment"

  msg_info "Running initial setup"
  cd /opt/odysseus
  source /opt/odysseus/venv/bin/activate
  ADMIN_PASS=$(python3 setup.py 2>&1 | grep -oP '(?<=password: )\S+' || true)
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
}

start
build_container
description

install_odysseus

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"

if [[ -f /root/.odysseus_admin_pass ]]; then
  PASS=$(cat /root/.odysseus_admin_pass)
  echo -e "${INFO}${YW} Admin password:${CL} ${BGN}${PASS}${CL}"
  echo -e "${INFO}${YW} (Saved to /root/.odysseus_admin_pass — delete after noting it)${CL}"
fi

echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:7000${CL}"
