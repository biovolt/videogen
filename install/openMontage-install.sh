#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: calesthio
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/calesthio/OpenMontage

# shellcheck source=/dev/null
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y git ca-certificates
msg_ok "Installed Dependencies"

msg_info "Setting up Python"
PYTHON_VERSION="3.12" setup_uv
msg_ok "Set up Python"

msg_info "Setting up Node.js"
NODE_VERSION="22" setup_nodejs
msg_ok "Set up Node.js"

msg_info "Setting up FFmpeg"
FFMPEG_TYPE="full" setup_ffmpeg
msg_ok "Set up FFmpeg"

msg_info "Cloning OpenMontage"
$STD git clone https://github.com/calesthio/OpenMontage /opt/openmontage
RELEASE=$(cd /opt/openmontage && git describe --tags --always 2>/dev/null)
if [[ -z "${RELEASE}" ]]; then
  RELEASE=$(git -C /opt/openmontage rev-parse --short HEAD)
fi
echo "${RELEASE}" >/opt/OpenMontage_version.txt
msg_ok "Cloned OpenMontage ${RELEASE}"

msg_info "Installing Python Dependencies"
cd /opt/openmontage || { msg_error "Failed to change directory to /opt/openmontage"; exit 1; }
$STD uv venv /opt/openmontage/.venv
$STD uv pip install --python /opt/openmontage/.venv/bin/python -r requirements.txt
msg_ok "Installed Python Dependencies"

msg_info "Installing Node.js Dependencies"
cd /opt/openmontage/remotion-composer || { msg_error "Failed to change directory to remotion-composer"; exit 1; }
$STD npm install
msg_ok "Installed Node.js Dependencies"

msg_info "Configuring Environment"
if [[ ! -f /opt/openmontage/.env ]]; then
  if [[ ! -f /opt/openmontage/.env.example ]]; then
    msg_error ".env.example not found in repository — cannot configure environment"
    exit 1
  fi
  cp /opt/openmontage/.env.example /opt/openmontage/.env

  read -rp "Enter FAL_KEY (or press Enter to skip): " FAL_KEY_INPUT
  if [[ -n "${FAL_KEY_INPUT}" ]]; then
    sed -i "s|^FAL_KEY=.*|FAL_KEY=${FAL_KEY_INPUT}|" /opt/openmontage/.env
  else
    sed -i "s|^FAL_KEY=.*|# FAL_KEY=your-key-here|" /opt/openmontage/.env
  fi

  read -rp "Enter ELEVENLABS_API_KEY (or press Enter to skip): " ELEVENLABS_INPUT
  if [[ -n "${ELEVENLABS_INPUT}" ]]; then
    sed -i "s|^ELEVENLABS_API_KEY=.*|ELEVENLABS_API_KEY=${ELEVENLABS_INPUT}|" /opt/openmontage/.env
  else
    sed -i "s|^ELEVENLABS_API_KEY=.*|# ELEVENLABS_API_KEY=your-key-here|" /opt/openmontage/.env
  fi

  read -rp "Enter OPENAI_API_KEY (or press Enter to skip): " OPENAI_INPUT
  if [[ -n "${OPENAI_INPUT}" ]]; then
    sed -i "s|^OPENAI_API_KEY=.*|OPENAI_API_KEY=${OPENAI_INPUT}|" /opt/openmontage/.env
  else
    sed -i "s|^OPENAI_API_KEY=.*|# OPENAI_API_KEY=your-key-here|" /opt/openmontage/.env
  fi
fi
msg_ok "Configured Environment"

motd_ssh
customize
cleanup_lxc
