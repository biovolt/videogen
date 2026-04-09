#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: calesthio
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/calesthio/OpenMontage
# shellcheck disable=SC1090
# TODO: Change back to community-scripts/ProxmoxVE before PR submission
source <(curl -fsSL https://raw.githubusercontent.com/biovolt/ProxmoxVE/main/misc/build.func)

APP="OpenMontage"
var_tags="${var_tags:-media;ai}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-12}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"
var_gpu="${var_gpu:-no}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /opt/OpenMontage_version.txt ]]; then
    msg_error "No ${APP} installation found!"
    exit 1
  fi

  RELEASE=$(curl -fsSL https://api.github.com/repos/calesthio/OpenMontage/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

  if [[ -z "${RELEASE}" ]]; then
    msg_error "Could not fetch latest release from GitHub"
    exit 1
  fi

  if [[ "${RELEASE}" != "$(cat /opt/OpenMontage_version.txt)" ]]; then
    msg_info "Updating ${APP} to ${RELEASE}"
    cd /opt/openmontage || { msg_error "Cannot find /opt/openmontage"; exit 1; }
    $STD git pull
    $STD git -C /opt/openmontage checkout "${RELEASE}"
    msg_ok "Pulled ${APP} ${RELEASE}"

    msg_info "Reinstalling Python dependencies"
    $STD uv pip install --python /opt/openmontage/.venv/bin/python -r /opt/openmontage/requirements.txt
    msg_ok "Reinstalled Python dependencies"

    msg_info "Reinstalling Node.js dependencies"
    cd /opt/openmontage/remotion-composer || { msg_error "Cannot find remotion-composer"; exit 1; }
    $STD npm install
    msg_ok "Reinstalled Node.js dependencies"

    { git -C /opt/openmontage describe --tags --exact-match 2>/dev/null || git -C /opt/openmontage rev-parse --short HEAD; } >/opt/OpenMontage_version.txt
    msg_ok "Updated ${APP} to ${RELEASE}"
  else
    msg_ok "No update required. ${APP} is already at ${RELEASE}"
  fi
  exit 0
}

start
build_container
description

# Append API key instructions to the Proxmox container notes
pct set "$CTID" -description "$(pct config "$CTID" | sed -n 's/^description: //p' | sed 's/%0A/\n/g')
<p><b>API Keys:</b> <code>nano /opt/openmontage/.env</code><br/>Supports: FAL_KEY, ELEVENLABS_API_KEY, OPENAI_API_KEY</p>"

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Add your API keys: nano /opt/openmontage/.env${CL}"
echo -e "${INFO}${YW} Supported: FAL_KEY, ELEVENLABS_API_KEY, OPENAI_API_KEY${CL}"
