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
  msg_debug "update_script() called inside container"

  if [[ ! -d /opt/odysseus ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_debug "Found /opt/odysseus"

  msg_info "Checking for updates"
  CURRENT=$(git -C /opt/odysseus rev-parse HEAD)
  LATEST=$(git ls-remote https://github.com/pewdiepie-archdaemon/odysseus HEAD | cut -f1)
  msg_debug "Current commit: ${CURRENT}"
  msg_debug "Latest commit:  ${LATEST}"

  if [[ "$CURRENT" == "$LATEST" ]]; then
    msg_ok "Already on latest version — nothing to do."
    exit 0
  fi
  msg_ok "Update available — proceeding"

  msg_info "Stopping service"
  msg_debug "Running: systemctl stop odysseus"
  systemctl stop odysseus
  msg_ok "Stopped"

  msg_info "Pulling latest changes"
  msg_debug "Running: git pull origin main in /opt/odysseus"
  git -C /opt/odysseus pull origin main -q
  msg_debug "Git pull complete — current commit: $(git -C /opt/odysseus rev-parse HEAD)"
  msg_ok "Pulled"

  msg_info "Updating dependencies"
  msg_debug "Activating venv and running pip install --upgrade"
  source /opt/odysseus/venv/bin/activate
  pip install --upgrade -r /opt/odysseus/requirements.txt -q
  deactivate
  msg_ok "Dependencies updated"

  msg_info "Starting service"
  msg_debug "Running: systemctl start odysseus"
  systemctl start odysseus
  msg_debug "Service status: $(systemctl is-active odysseus)"
  msg_ok "Started"

  msg_ok "Updated successfully!"
  exit
}

msg_debug "Calling start()"
start
msg_debug "Calling build_container()"
build_container
msg_debug "Calling description()"
description

msg_ok "Completed successfully!\n"
echo -e "${TAB}${BOLD}Access ${APP} at:${CL}"
CTID="${CT_ID:-$NEXTID}"
IP=$(pct exec "$CTID" -- hostname -I 2>/dev/null | awk '{print $1}' || echo "")
msg_debug "Resolved IP: ${IP}"
if [[ -n "$IP" ]]; then
  echo -e "${TAB}${GN}http://${IP}:7000${CL}\n"
else
  echo -e "${TAB}${YW}Could not resolve IP. Check container with: pct exec ${CTID} -- hostname -I${CL}\n"
fi

echo -e "${TAB}${DIM}Register your admin account on first visit.${CL}\n"
