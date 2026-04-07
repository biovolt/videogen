#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: calesthio
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/calesthio/OpenMontage

source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

APP="OpenMontage"
var_tags="${var_tags:-media;ai}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

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
    exit
  fi

  RELEASE=$(curl -fsSL https://api.github.com/repos/calesthio/OpenMontage/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  if [[ "${RELEASE}" != "$(cat /opt/OpenMontage_version.txt)" ]]; then
    msg_info "Updating ${APP} to ${RELEASE}"
    cd /opt/openmontage
    git pull
    # Preserve .env — do not overwrite user config
    $STD uv pip install --python /opt/openmontage/.venv/bin/python -r requirements.txt
    cd /opt/openmontage/remotion-composer
    $STD npm install
    echo "${RELEASE}" >/opt/OpenMontage_version.txt
    msg_ok "Updated ${APP} to ${RELEASE}"
  else
    msg_ok "No update required. ${APP} is already at ${RELEASE}"
  fi
  exit
}

function install_script() {
  # Collect API keys here on the host where a TTY is available.
  read -rsp "Enter FAL_KEY (or press Enter to skip): " FAL_KEY
  echo

  read -rsp "Enter ELEVENLABS_API_KEY (or press Enter to skip): " ELEVENLABS_API_KEY
  echo

  read -rsp "Enter OPENAI_API_KEY (or press Enter to skip): " OPENAI_API_KEY
  echo
}

install_script
start
build_container

# Pass API keys into container filesystem before install runs
pct exec "$CTID" -- bash -c "cat > /root/.install_env" <<EOF
export FAL_KEY='${FAL_KEY}'
export ELEVENLABS_API_KEY='${ELEVENLABS_API_KEY}'
export OPENAI_API_KEY='${OPENAI_API_KEY}'
EOF

description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the IP of your LXC Container.${CL}"
