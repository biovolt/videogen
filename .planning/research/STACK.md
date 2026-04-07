# Technology Stack: Proxmox Community-Script for OpenMontage

**Project:** OpenMontage Proxmox LXC Installer
**Researched:** 2026-04-07
**Confidence:** HIGH — sourced directly from live repo files and official docs

---

## What This Stack Is

Two bash scripts following the community-scripts/ProxmoxVE framework:

| Layer | File | Runs On |
|-------|------|---------|
| Orchestrator | `ct/openMontage.sh` | Proxmox host |
| Installer | `install/openMontage-install.sh` | Inside the LXC container |

These are the only two files required. All shared infrastructure (container creation, interactive UI, color output, validation) comes from `build.func` and its sub-libraries, fetched at runtime from the community-scripts GitHub CDN.

---

## Exact File Naming Convention

| File | Convention | Example |
|------|-----------|---------|
| CT orchestrator | `ct/<AppName>.sh` | `ct/openMontage.sh` |
| Install script | `install/<appname>-install.sh` | `install/openMontage-install.sh` |
| Version tracking | `/opt/${APP}_version.txt` (inside container) | `/opt/OpenMontage_version.txt` |

**Rules (verified from 466+ real scripts):**
- Lowercase with hyphens in install script names: `openMontage-install.sh`
- Mixed case is acceptable in ct/ scripts where `APP=` is set: `openMontage.sh`
- `.sh` extension always
- No underscores in filenames

---

## ct/openMontage.sh — Full Structure

This script runs on the Proxmox host. Its only jobs are: set defaults, provide an update function, and call three framework functions.

```bash
#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: YourGitHubUsername
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/calesthio/OpenMontage

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
  if [[ ! -d /opt/openMontage ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  # Update logic goes here — git pull, pip install, npm install
  # Preserve .env: update must never overwrite /opt/openMontage/.env
  msg_ok "Updated ${APP}"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
```

### Required Variables and Their Meaning

| Variable | Type | Purpose | OpenMontage Value |
|----------|------|---------|-------------------|
| `APP` | string | Display name — used in messages and version files | `"OpenMontage"` |
| `var_tags` | string | Semicolon-separated tags for website categorization | `"media;ai"` |
| `var_cpu` | int | Default CPU cores | `2` |
| `var_ram` | int | Default RAM in MB | `2048` |
| `var_disk` | int | Default disk in GB | `8` |
| `var_os` | string | Base OS | `"debian"` |
| `var_version` | string | OS version | `"12"` |
| `var_unprivileged` | 0\|1 | Unprivileged container (1=yes) | `1` |
| `var_gpu` | string | GPU passthrough option | `"yes"` (if GPU support wanted) |

**Use the `${var:-default}` form** for every variable. This allows users to override defaults via environment variables before running the script — required for community-scripts compatibility and unattended deployments.

### The Three Mandatory Terminal Calls

Every ct/ script ends with exactly these three lines (no exceptions in the repo):

```bash
start           # Interactive wizard: default vs advanced mode, collects settings
build_container # Creates the LXC, runs the install script inside it
description     # Displays final info from app metadata
```

These are provided by `build.func`. You never implement them.

### update_script() Requirements

The `update_script()` function runs when the script is executed inside an already-running container. Required pattern:

1. Call `header_info`, `check_container_storage`, `check_container_resources` at the top
2. Verify the app is installed (check for directory or binary) — exit with `msg_error` if not
3. Perform the actual update
4. Call `exit` at the end (do not fall through to `start`/`build_container`)

For OpenMontage: git pull in `/opt/openMontage`, re-run `pip install -r requirements.txt`, re-run `npm install` in the Remotion subdirectory. Never touch `.env`.

---

## install/openMontage-install.sh — Full Structure

This script runs inside the freshly created LXC container. It has no access to the Proxmox host. The framework injects helper functions via `$FUNCTIONS_FILE_PATH`.

```bash
#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: YourGitHubUsername
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/calesthio/OpenMontage

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing System Dependencies"
$STD apt install -y \
  git \
  curl \
  ca-certificates \
  build-essential
msg_ok "Installed System Dependencies"

# Node.js 18+ (Remotion requires 18, current LTS is 22/24)
NODE_VERSION="22" setup_nodejs

# Python 3.10+ via uv (fast, handles EXTERNALLY-MANAGED)
PYTHON_VERSION="3.12" setup_uv

# FFmpeg (full build for video encoding)
FFMPEG_TYPE="full" setup_ffmpeg

msg_info "Cloning OpenMontage"
git clone -q https://github.com/calesthio/OpenMontage /opt/openMontage
msg_ok "Cloned OpenMontage"

msg_info "Installing Python Dependencies"
cd /opt/openMontage
$STD uv pip install -r requirements.txt
msg_ok "Installed Python Dependencies"

msg_info "Installing Node Dependencies"
cd /opt/openMontage
$STD npm install
msg_ok "Installed Node Dependencies"

msg_info "Creating .env"
cp /opt/openMontage/.env.example /opt/openMontage/.env
chmod 600 /opt/openMontage/.env
msg_ok "Created .env"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/openMontage.service
[Unit]
Description=OpenMontage
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/openMontage
ExecStart=/usr/bin/python3 main.py
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now openMontage
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
```

### Mandatory Boilerplate Sequence (top of every install script)

```bash
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os
```

**Why this order:** `$FUNCTIONS_FILE_PATH` is a string containing the bash source of `install.func` (fetched by `build.func` before launching the container). The `source /dev/stdin <<<` pattern evaluates it without writing to disk. Every function used after this line depends on this being sourced first.

### Mandatory Boilerplate Sequence (bottom of every install script)

```bash
motd_ssh
customize
cleanup_lxc
```

**Why:** These finalize the container — set up SSH, MOTD with IP, and run `apt autoremove`/`apt clean`. Skipping them leaves the container dirty and breaks the community-scripts MOTD display.

### $STD Prefix Rule

Every `apt install`, `pip install`, `npm install`, `git clone` must be prefixed with `$STD`:

```bash
$STD apt install -y git curl
```

`$STD` is either empty (verbose mode) or redirects stdout to the log file (quiet mode). Using it is required for PR acceptance — it respects the user's verbosity setting from the wizard.

### Version Tracking (Required for Updates)

Save a version identifier at the end of installation so `update_script()` can detect staleness:

```bash
# After cloning from git:
git -C /opt/openMontage rev-parse HEAD > /opt/OpenMontage_version.txt

# Or for tagged releases:
echo "1.2.3" > /opt/OpenMontage_version.txt
```

---

## Framework Functions Available in Install Scripts

All provided by `install.func` and `tools.func` via `$FUNCTIONS_FILE_PATH`.

### Runtime Setup

| Function | Syntax | Notes |
|----------|--------|-------|
| `setup_nodejs` | `NODE_VERSION="22" setup_nodejs` | Default is 24 (current LTS). Use 22 for Remotion compatibility. |
| `setup_uv` | `PYTHON_VERSION="3.12" setup_uv` | Handles Debian 12's EXTERNALLY-MANAGED PEP 668. Replaces raw pip. |
| `setup_ffmpeg` | `FFMPEG_TYPE="full" setup_ffmpeg` | `binary` is fastest; `full` is most compatible. |
| `setup_hwaccel` | `setup_hwaccel "openMontage"` | Detects Intel/AMD/NVIDIA GPU, configures device access in LXC. |

### GitHub Release Management

```bash
# Download and deploy a GitHub release binary
fetch_and_deploy_gh_release "appname" "owner/repo" "tarball" "latest" "/opt/appname"

# Check if update available (for update_script in ct/)
check_for_gh_release "appname" "owner/repo"

# Get latest version string
RELEASE=$(get_latest_github_release "owner/repo")
```

### Repository Setup

```bash
# Modern DEB822 format (required for Debian 12+)
setup_deb822_repo \
  "reponame" \
  "https://example.com/gpg.key" \
  "https://repo.example.com/debian" \
  "$(get_os_info codename)"
```

### Messaging (use consistently)

```bash
msg_info "Installing Something"    # Shows spinner
$STD apt install -y something
msg_ok "Installed Something"       # Clears spinner, shows checkmark

msg_error "No Installation Found!" # Red X, exits
msg_warn "Config file missing"     # Yellow warning, continues
```

### Dependency Helper

```bash
ensure_dependencies libssl-dev libffi-dev   # Installs if missing, no-op if present
```

---

## Base OS Decision

**Use Debian 12 (Bookworm).** This is the community-scripts standard. Set `var_os="debian"` and `var_version="12"`.

Why not Ubuntu: Ubuntu 24.04 is used by Jellyfin/Plex specifically because of their Intel GPU driver requirements. OpenMontage has no such requirement. Debian 12 is lighter, more predictable, and what the vast majority of community-scripts use.

Why Debian 12 specifically matters: `setup_uv` exists precisely because Debian 12 enforces PEP 668 (EXTERNALLY-MANAGED) and blocks system-wide pip installs. Using `setup_uv` sidesteps this correctly without `--break-system-packages` hacks.

---

## GPU Passthrough

Set `var_gpu="${var_gpu:-yes}"` in the ct/ script if you want to offer GPU passthrough as an option. This triggers the advanced wizard to ask about GPU support.

Inside the install script, call `setup_hwaccel "openMontage"` after the main install. This function:
1. Detects whether GPU passthrough is configured in the container
2. Installs appropriate drivers (Intel media drivers, NVIDIA Container Toolkit, or AMD ROCm)
3. Adds the container user to the `video` and `render` groups

**For OpenMontage v1:** GPU passthrough is optional (most users will use cloud APIs). Include `var_gpu` in the ct/ script to give users the choice, but `setup_hwaccel` will no-op gracefully if no GPU is present.

---

## What NOT to Do

| Anti-pattern | Why | Instead |
|---|---|---|
| `apt install -y pkg` without `$STD` | Breaks quiet mode, fails PR review | `$STD apt install -y pkg` |
| `pip install -r requirements.txt` bare | Breaks on Debian 12 PEP 668 | `$STD uv pip install -r requirements.txt` |
| Hardcoding versions (`node 18.x`) | Scripts go stale | `NODE_VERSION="22" setup_nodejs` |
| `source build.func` in install script | build.func is for the host, not container | `source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"` |
| Skipping `motd_ssh; customize; cleanup_lxc` | Leaves dirty container, breaks MOTD | Always end with these three |
| `var_cpu="2"` without `${var_cpu:-2}` | Breaks unattended/override deployments | `var_cpu="${var_cpu:-2}"` |
| Writing to `.env` during updates | Destroys user config | Check if `.env` exists before writing; skip if so |
| Generating passwords with `date` or `$RANDOM` | Weak entropy | `openssl rand -base64 18 | tr -dc 'a-zA-Z0-9'` |
| `set -e` at top of install script | `catch_errors` sets a custom trap — `set -e` interferes | Use `catch_errors` from `$FUNCTIONS_FILE_PATH` only |
| Sourcing build.func from a forked URL | Breaks if fork diverges; not accepted in PR | Always use official `https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func` |

---

## How build.func Wires the Two Scripts Together

Understanding this prevents confusion:

1. User runs `ct/openMontage.sh` on the Proxmox host shell
2. `build.func` is curl-sourced into that shell session
3. `header_info`/`variables`/`color`/`catch_errors` run in the host shell
4. `start` shows the interactive wizard (default vs advanced mode)
5. `build_container` creates the LXC via `pct create`, then:
   - Fetches `install.func` content as a string
   - Sets `FUNCTIONS_FILE_PATH` to that string
   - Exports `APP`, `NSAPP`, `CTID`, `VERBOSE`, `STD`, and other env vars
   - Runs `pct exec $CTID -- bash -c "$(cat install/openMontage-install.sh)"` (conceptually)
6. `install/openMontage-install.sh` runs inside the container
   - `source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"` loads the injected functions
   - The script installs everything
7. `description` on the host reads app metadata and prints the final summary

**Key implication:** The install script has no access to the host filesystem. It cannot read files from the Proxmox node. Everything it needs must be downloaded from the internet or injected via environment variables.

---

## PR Submission Checklist

For contributing to community-scripts/ProxmoxVE:

- [ ] Shebang is `#!/usr/bin/env bash` (not `/bin/bash`)
- [ ] build.func sourced from official URL (not a fork)
- [ ] Copyright header present with `# Copyright (c) 2021-2026 community-scripts ORG`
- [ ] `# Author:` line with GitHub username
- [ ] `# License: MIT` line
- [ ] `# Source:` line pointing to upstream project
- [ ] All `var_*` use `${var_name:-default}` form
- [ ] All commands in install script prefixed with `$STD`
- [ ] `motd_ssh`, `customize`, `cleanup_lxc` at end of install script
- [ ] Version saved to `/opt/${APP}_version.txt`
- [ ] `update_script()` implemented in ct/ script
- [ ] Application is open-source (GPL, MIT, Apache) — closed-source rejected
- [ ] Tested on Proxmox VE 8.x, both default and advanced mode
- [ ] ShellCheck passes with no errors

---

## Sources

- [community-scripts/ProxmoxVE — main repo](https://github.com/community-scripts/ProxmoxVE)
- [ct/jellyfin.sh — verified ct/ boilerplate](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/jellyfin.sh)
- [ct/node-red.sh — verified ct/ boilerplate with update_script](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/node-red.sh)
- [install/jellyfin-install.sh — verified install/ boilerplate](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/jellyfin-install.sh)
- [install/node-red-install.sh — verified install/ with nodejs](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/node-red-install.sh)
- [install/gitea-install.sh — verified install/ with fetch_and_deploy_gh_release](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/gitea-install.sh)
- [misc/build.func — framework source (5995 lines)](https://github.com/community-scripts/ProxmoxVE/blob/main/misc/build.func)
- [tools.func wiki — setup_nodejs, setup_uv, setup_ffmpeg, setup_hwaccel docs](https://github.com/community-scripts/ProxmoxVE/wiki/tools.func)
- [Creating Install Scripts — official developer docs](https://www.mintlify.com/community-scripts/ProxmoxVE/development/install-scripts)
- [Discussion #7565 — how FUNCTIONS_FILE_PATH works](https://github.com/community-scripts/ProxmoxVE/discussions/7565)
- [Contribution guidelines wiki](https://github.com/community-scripts/ProxmoxVE/wiki/CONTRIBUTING)
