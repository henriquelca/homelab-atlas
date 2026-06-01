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
    exit
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
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"

if [[ -f /root/.odysseus_admin_pass ]]; then
  PASS=$(cat /root/.odysseus_admin_pass)
  echo -e "${INFO}${YW} Admin password:${CL} ${BGN}${PASS}${CL}"
  echo -e "${INFO}${YW} (Saved to /root/.odysseus_admin_pass — delete after noting it)${CL}"
fi

echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:7000${CL}"
