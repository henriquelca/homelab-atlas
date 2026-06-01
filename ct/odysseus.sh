#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/henriquelca/homelab-atlas/main/misc/build.func)
# Copyright (c) 2026 henriquelca
# Author: henriquelca
# License: MIT
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
  if [[ ! -d /opt/odysseus ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Checking for updates"
  CURRENT=$(git -C /opt/odysseus rev-parse HEAD)
  LATEST=$(git ls-remote https://github.com/pewdiepie-archdaemon/odysseus HEAD | cut -f1)

  if [[ "$CURRENT" == "$LATEST" ]]; then
    msg_ok "Already on latest version — nothing to do."
    exit 0
  fi
  msg_ok "Update available — proceeding"

  msg_info "Stopping service"
  systemctl stop odysseus
  msg_ok "Stopped"

  msg_info "Pulling latest changes"
  git -C /opt/odysseus pull origin main -q
  msg_ok "Pulled"

  msg_info "Updating dependencies"
  source /opt/odysseus/venv/bin/activate
  pip install --upgrade -r /opt/odysseus/requirements.txt -q
  deactivate
  msg_ok "Dependencies updated"

  msg_info "Starting service"
  systemctl start odysseus
  msg_ok "Started"

  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${TAB}${BOLD}Access ${APP} at:${CL}"
IP=$(pvesh get /nodes/$(hostname)/lxc --output-format json 2>/dev/null \
  | grep -oP '"ip":\s*"\K[^"]+' | head -n1 || echo "your-container-ip")
echo -e "${TAB}${GN}http://${IP}:7000${CL}\n"
