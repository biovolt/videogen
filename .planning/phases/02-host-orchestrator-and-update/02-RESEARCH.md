# Phase 2: Host Orchestrator and Update - Research

**Researched:** 2026-04-07
**Domain:** community-scripts/ProxmoxVE ct/ script pattern — `build.func` framework, `var_*` variables, `update_script()`, GPU passthrough, API key injection
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Default resources: 2 CPU, 2048 MB RAM, 12 GB disk (per CT-01)
- **D-02:** GPU passthrough defaults to off, exposed in advanced mode (per CT-03)
- **D-03:** Base OS: Debian 12, unprivileged container (per community-scripts standard)
- **D-04:** Version detection via GitHub Releases API — compare installed version tag vs latest release
- **D-05:** After update: reinstall both pip and npm deps (ensures new requirements are met)
- **D-06:** No changelog display — keep update simple (pull + reinstall)
- **D-07:** `.env` must be preserved across updates — never overwritten

### Claude's Discretion
- How to structure the three mandatory terminal calls (header_info, base_settings, write_script)
- Exact `var_*` variable format (with `${var_name:-default}` pattern per CLAUDE.md)
- How `install_script()` passes API keys to the container (already partially implemented in Phase 1 fix)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CT-01 | Script creates Debian 12 LXC with defaults (2 CPU, 2GB RAM, 12GB disk) | `var_*` defaults with `${var_name:-N}` pattern; canonical pattern verified in jellyfin.sh |
| CT-02 | Advanced mode allows custom CPU, RAM, disk, hostname, and network settings | `advanced_settings()` invoked by build.func's `install_script()` when user picks option 2 — no ct/ work needed |
| CT-03 | User can optionally enable GPU passthrough during advanced setup | `var_gpu="${var_gpu:-no}"` triggers GPU detection in `build.func`; advanced_settings shows GPU dialog |
| CT-04 | Script uses `build.func` framework for container creation | `source <(curl -fsSL …/build.func)` is the framework entry; `start` + `build_container` + `description` is the full call sequence |
| UPD-01 | `update_script()` detects current vs upstream version | GitHub Releases API + `/opt/OpenMontage_version.txt` compare; current implementation correct |
| UPD-02 | Git pull fetches latest OpenMontage code | `git pull` inside update_script (runs inside container); correct |
| UPD-03 | Dependencies re-installed after pull (pip + npm) | `uv pip install` + `npm install` in update_script; current implementation correct |
| UPD-04 | `.env` file preserved across updates | Explicit guard: check if `.env` exists before writing; update_script must not touch `.env` |
</phase_requirements>

---

## Summary

`ct/openMontage.sh` already exists (77 lines from Phase 1) and has the right skeleton, but contains three bugs that must be fixed before the script will function correctly. The most critical bug is that a locally-defined `install_script()` overrides `build.func`'s `install_script()`, which is the function responsible for the full container-creation flow (pve_check, whiptail menu, default/advanced settings, calling `build_container` internally via `start()`). Removing this override is the single most important change.

The second bug is `var_disk` set to 8 instead of the required 12 GB (D-01). The third is the absence of `var_gpu`, which is required for the GPU passthrough dialog in advanced mode (CT-03, D-02). Beyond these bugs, the API key injection mechanism needs to be removed or redesigned because the `pct exec` that writes `/root/.install_env` runs after `build_container` has already executed the install script inside the container, making it a no-op.

The `update_script()` body is architecturally correct — it runs inside the container (build.func's `start()` routes to `update_script()` when `pveversion` is not available), uses `$STD` on `uv pip install` and `npm install`, and correctly reads the version file. Minor structural improvements needed: proper `msg_info`/`msg_ok` wrapping around `git pull` and the dep installs.

**Primary recommendation:** Remove the local `install_script()` definition entirely, fix `var_disk` to 12, add `var_gpu="${var_gpu:-no}"`, remove the `pct exec` API key injection, and align the script termination sequence with the canonical `start` / `build_container` / `description` pattern.

---

## Standard Stack

### Core (ct/ script layer only — no new packages)

| Component | Source | Purpose | Why Standard |
|-----------|--------|---------|--------------|
| `build.func` | `https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func` | Framework: pve checks, whiptail menus, `install_script()`, `start()`, `build_container()`, `description()` | Required for PR acceptance; must be official URL [VERIFIED: raw content fetched] |
| `var_*` variables | local ct/ script | Container defaults exposed to `default_settings()` and `advanced_settings()` | Framework reads these variables by name; no alternatives [VERIFIED: build.func line 1057] |

No new packages are needed for Phase 2. All tooling (`uv`, `npm`, `git`) is installed inside the container by Phase 1's install script.

---

## Architecture Patterns

### Canonical ct/ Script Structure

Verified from `ct/jellyfin.sh` and `ct/node-red.sh` (fetched directly): [VERIFIED: raw.githubusercontent.com]

```bash
#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: <GitHubUsername>
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: <upstream project URL>

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
  # ... (see below)
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the IP of your LXC Container.${CL}"
```

**Key rules confirmed by canonical scripts:**
1. `source <(curl -fsSL …/build.func)` is line 1 — before the copyright header [VERIFIED: jellyfin.sh]
2. `header_info "$APP"` / `variables` / `color` / `catch_errors` — always these four, in this order [VERIFIED: both scripts]
3. NO local `install_script()` definition — `build.func` provides this [VERIFIED: jellyfin.sh, gitea.sh]
4. Script ends with `start` / `build_container` / `description` then success echo [VERIFIED: both scripts]

### How `start()` Routes Execution

`start()` in `build.func` distinguishes host from container by probing `pveversion`: [VERIFIED: build.func lines 3468–3510]

```
Host (pveversion present):
  start() -> install_script()  (the build.func version, not any local override)
           -> returns

Container (no pveversion):
  start() -> shows "Update/Setting" whiptail menu
           -> update_script()
```

This is why defining a local `install_script()` is destructive: on the host, `start()` calls the overridden version (which only collects API keys) and returns. The host-side container creation flow (`pve_check`, `advanced_settings`, etc.) never runs.

### How `build.func`'s `install_script()` Handles CT-02 (Advanced Mode)

`install_script()` shows a whiptail menu: "Default Install" / "Advanced Install" / "User Defaults". When the user picks Advanced (option 2), `advanced_settings()` is called, which presents dialogs for CPU, RAM, disk, hostname, network, and — if `var_gpu` is set — a GPU passthrough toggle. [VERIFIED: build.func lines 3006–3060, 2495]

The ct/ script does not need to implement CT-02 or CT-03 logic. Setting `var_gpu="${var_gpu:-no}"` is sufficient; `build.func` handles the GPU dialog in advanced mode automatically.

### GPU Passthrough Pattern

```bash
var_gpu="${var_gpu:-no}"   # default off; advanced mode shows "Enable GPU Passthrough?" dialog
```

`build.func` detects Intel/AMD/NVIDIA GPUs via `lspci` and configures `/etc/pve/lxc/${CTID}.conf` with `dev0:` entries. No additional code in the ct/ script is needed. [VERIFIED: build.func lines 2495, 3751–3858]

### update_script() Pattern (container context)

Verified from `ct/gitea.sh` and `ct/node-red.sh`: [VERIFIED: raw content fetched]

```bash
function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /opt/OpenMontage_version.txt ]]; then
    msg_error "No ${APP} installation found!"
    exit
  fi

  RELEASE=$(curl -fsSL https://api.github.com/repos/calesthio/OpenMontage/releases/latest \
    | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

  if [[ "${RELEASE}" != "$(cat /opt/OpenMontage_version.txt)" ]]; then
    msg_info "Updating ${APP} to ${RELEASE}"

    cd /opt/openmontage || { msg_error "Cannot find /opt/openmontage — aborting update"; exit 1; }
    $STD git pull

    msg_ok "Pulled ${APP} ${RELEASE}"

    msg_info "Reinstalling Python dependencies"
    $STD uv pip install --python /opt/openmontage/.venv/bin/python -r requirements.txt
    msg_ok "Reinstalled Python dependencies"

    msg_info "Reinstalling Node.js dependencies"
    cd /opt/openmontage/remotion-composer || { msg_error "Cannot find remotion-composer — aborting update"; exit 1; }
    $STD npm install
    msg_ok "Reinstalled Node.js dependencies"

    echo "${RELEASE}" >/opt/OpenMontage_version.txt
    msg_ok "Updated ${APP} to ${RELEASE}"
  else
    msg_ok "No update required. ${APP} is already at ${RELEASE}"
  fi
  exit
}
```

**Why this is correct:**
- `update_script()` runs inside the container (no `pveversion`), so `uv` and `npm` are available
- `.env` is never touched (D-07 satisfied by omission — no git reset/clean, no .env.example copy)
- `$STD git pull` suppresses output in quiet mode (PR-01 compatibility)
- `msg_info`/`msg_ok` pairs wrap each logical step (PR-02 compatibility)
- `exit` at the end is required — prevents fall-through to `build_container` [VERIFIED: jellyfin.sh, gitea.sh]

### API Key Injection — The Broken Pattern (Must Be Removed)

The current `ct/openMontage.sh` has:

```bash
# BROKEN — runs after install script already executed in build_container
pct exec "$CTID" -- bash -c "cat > /root/.install_env" <<EOF
export FAL_KEY='${FAL_KEY}'
...
EOF
```

**Why it does not work:**
`build_container()` (line ~4330 in build.func) runs the install script via `lxc-attach` before returning control to the ct/ script. By the time `pct exec` runs on line 67 of the current ct/ script, the install script has already executed and already sourced `/root/.install_env` (which didn't exist yet). [VERIFIED: build.func line 4330]

**Correct approach for Phase 2:** Remove `install_script()` override and `pct exec` entirely. The install script already creates `.env` from `.env.example` with commented placeholders for missing keys. Users edit `.env` post-install. This is the standard community-scripts approach for secrets — confirmed by the "All 16 API key prompts" being out-of-scope in REQUIREMENTS.md.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Container creation | Custom `pct create` logic | `build.func` `start` + `build_container` + `description` | Framework handles storage selection, network config, unprivileged setup, GPU passthrough, template downloads, error recovery [VERIFIED] |
| Advanced mode dialogs | Local `whiptail` calls for CPU/RAM/disk | `var_*` defaults + let `advanced_settings()` run | build.func already implements all dialogs; CPU/RAM/disk/hostname/network/GPU all handled [VERIFIED: build.func 2495] |
| GPU detection/config | Manual lspci + lxc.conf edits | `var_gpu="${var_gpu:-no}"` | build.func detects Intel/AMD/NVIDIA and writes all required lxc.conf entries [VERIFIED: build.func 3757–3960] |
| Version comparison | Custom semver logic | Direct string compare with GitHub API tag | Tags are exact strings; string equality is sufficient and is the community pattern [VERIFIED: gitea.sh] |

---

## Common Pitfalls

### Pitfall 1: Overriding `install_script()` in the ct/ Script

**What goes wrong:** The local function completely replaces `build.func`'s `install_script()`. When `start()` runs on the host and calls `install_script()`, the override runs instead — no pve_check, no whiptail menu, no default/advanced settings, no container creation flow.

**Why it happens:** Shell function definition order — the last definition wins. `build.func` is sourced before the ct/ script defines the override, so the ct/ definition prevails.

**How to avoid:** Never define `install_script()` in a ct/ script. No canonical community-script ct/ script does this. [VERIFIED: jellyfin.sh, node-red.sh, gitea.sh]

**Warning signs:** If the ct/ script defines `function install_script()` anywhere — remove it.

### Pitfall 2: `pct exec` After `build_container` Is Too Late for Install-Time Config

**What goes wrong:** Any file written to the container with `pct exec` after `build_container` returns is too late for install-time sourcing — the install script already ran inside `lxc-attach`.

**Why it happens:** `build_container()` is a single function that creates the container, starts it, AND runs the install script. There is no hook between creation and install execution.

**How to avoid:** Do not attempt host-to-container env injection in the ct/ script. If install-time secrets are needed, the install script must prompt for them inside the container, or secrets must be written to the host before `build_container` is called via a mechanism that `build_container` itself transfers (not currently supported by the framework).

### Pitfall 3: `var_disk` Default Too Small

**What goes wrong:** `var_disk="${var_disk:-8}"` (current) creates an 8 GB container. OpenMontage installs Python 3.12 (via uv), Node.js 22, FFmpeg (full), npm packages including Remotion, and git-clones the app. This exceeds 8 GB.

**How to avoid:** Set `var_disk="${var_disk:-12}"` per D-01.

### Pitfall 4: Missing `var_gpu` Prevents GPU Dialog in Advanced Mode

**What goes wrong:** `advanced_settings()` in build.func conditionally shows the GPU passthrough dialog based on whether `var_gpu` is set. If absent, the dialog is suppressed and GPU passthrough cannot be enabled in advanced mode.

**How to avoid:** Add `var_gpu="${var_gpu:-no}"` (default off per D-02).

### Pitfall 5: `update_script()` Must End With `exit`

**What goes wrong:** Without `exit` at the end of `update_script()`, execution falls through to `start` / `build_container` — which would attempt to create a new LXC container from inside an existing one.

**How to avoid:** Always end `update_script()` with `exit`. [VERIFIED: all canonical scripts do this]

### Pitfall 6: `$STD` Missing on Commands in `update_script()`

**What goes wrong:** Commands without `$STD` prefix print to stdout unconditionally, breaking quiet mode. PR review will reject scripts that violate this.

**How to avoid:** All commands that produce output must be prefixed with `$STD`. In `update_script()` this means: `$STD git pull`, `$STD uv pip install …`, `$STD npm install`.

---

## Code Examples

### Complete Canonical ct/ Script Shape (Verified)

```bash
#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: calesthio
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/calesthio/OpenMontage

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
    exit
  fi

  RELEASE=$(curl -fsSL https://api.github.com/repos/calesthio/OpenMontage/releases/latest \
    | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

  if [[ "${RELEASE}" != "$(cat /opt/OpenMontage_version.txt)" ]]; then
    msg_info "Updating ${APP} to ${RELEASE}"
    cd /opt/openmontage || { msg_error "Cannot find /opt/openmontage"; exit 1; }
    $STD git pull
    msg_ok "Pulled latest code"

    msg_info "Reinstalling Python dependencies"
    $STD uv pip install --python /opt/openmontage/.venv/bin/python -r requirements.txt
    msg_ok "Reinstalled Python dependencies"

    msg_info "Reinstalling Node.js dependencies"
    cd /opt/openmontage/remotion-composer || { msg_error "Cannot find remotion-composer"; exit 1; }
    $STD npm install
    msg_ok "Reinstalled Node.js dependencies"

    echo "${RELEASE}" >/opt/OpenMontage_version.txt
    msg_ok "Updated ${APP} to ${RELEASE}"
  else
    msg_ok "No update required. ${APP} is already at ${RELEASE}"
  fi
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the IP of your LXC Container.${CL}"
```

Source: synthesized from verified canonical scripts (jellyfin.sh, node-red.sh, gitea.sh) + build.func analysis.

### Current Script Problems vs Required State

| Line(s) | Current (broken) | Required | Requirement |
|---------|------------------|----------|-------------|
| 14 | `var_disk="${var_disk:-8}"` | `var_disk="${var_disk:-12}"` | D-01, CT-01 |
| (absent) | no `var_gpu` | `var_gpu="${var_gpu:-no}"` | D-02, CT-03 |
| 50–60 | `function install_script() { … }` | Remove entirely | CT-04 (framework breakage) |
| 62 | `install_script` (local call) | Remove | CT-04 |
| 67–71 | `pct exec … cat > /root/.install_env` | Remove (broken timing) | CT-04 |
| 39 | `git pull` (no $STD) | `$STD git pull` | PR-01 |
| 39–43 | missing msg_info/msg_ok wrappers around dep installs | Add wrappers per step | PR-02 |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `calesthio/OpenMontage` has GitHub releases (not just tags) for the API to return a `tag_name` | update_script() | If the repo has no releases, `RELEASE` will be empty and the version compare will always trigger an update. Mitigation: add a fallback `git rev-parse --short HEAD` (already present in install script). | [ASSUMED — repo access not verified in this session] |

---

## Open Questions

1. **Should FAL_KEY / ELEVENLABS_API_KEY / OPENAI_API_KEY prompts be removed from the ct/ script entirely?**
   - What we know: The `pct exec` injection is architecturally broken (too late). The install script already creates `.env` with commented placeholders for missing keys.
   - What's unclear: Whether the user expects key prompts during `ct/` execution (Phase 1 added them as INST-08).
   - Recommendation: Remove from ct/ script. Keys live in `.env`; users edit post-install. This matches community-scripts PR requirements and the out-of-scope decision for all 16 key prompts.

2. **What if OpenMontage has no GitHub releases (only commits)?**
   - What we know: The install script already has a fallback `git rev-parse --short HEAD` for this case.
   - What's unclear: Whether `update_script()` needs the same fallback.
   - Recommendation: Add the same fallback to `update_script()` if `RELEASE` is empty, to prevent always-update behavior.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 2 is a bash script editing task. No external tools are installed or invoked by this phase; the ct/ script targets the Proxmox host environment, not the developer's machine.

---

## Validation Architecture

No automated test framework applies to Proxmox bash scripts. Validation is manual:

| Req ID | Behavior | Test Type | How to Verify |
|--------|----------|-----------|---------------|
| CT-01 | Script creates Debian 12 LXC with 2 CPU, 2048 MB RAM, 12 GB disk by default | Manual smoke | Run on Proxmox, select "Default Install", verify `pct config <CTID>` shows correct values |
| CT-02 | Advanced mode allows override | Manual smoke | Run on Proxmox, select "Advanced Install", change CPU/RAM, verify `pct config` |
| CT-03 | GPU passthrough dialog appears in advanced mode | Manual smoke | Run advanced mode on GPU-equipped host; verify GPU dialog shown |
| CT-04 | Container created successfully | Manual smoke | Container exists, install script ran, app files at `/opt/openmontage` |
| UPD-01 | Version compare works | Manual smoke | Set version file to old value, run script from inside container, verify update triggered |
| UPD-02 | git pull runs | Manual smoke | Make a commit to upstream between install and update, verify new files appear |
| UPD-03 | Deps reinstalled | Manual smoke | Verify no error on `uv pip install` and `npm install` during update |
| UPD-04 | `.env` preserved | Manual smoke | Add a custom value to `.env`, run update, verify value persists |

ShellCheck is the automated check that applies (PR requirement):
```bash
shellcheck ct/openMontage.sh
```

---

## Sources

### Primary (HIGH confidence)
- `https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/jellyfin.sh` — canonical ct/ structure, three mandatory calls, no local install_script override, script termination pattern
- `https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/node-red.sh` — canonical update_script with msg_info/msg_ok, msg_menu, exit at end
- `https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/gitea.sh` — canonical update_script with version check pattern
- `https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func` — verified: start() routing logic (lines 3468–3510), install_script() (2975), build_container() lxc-attach execution (4330), var_gpu handling (1024, 2495, 3751), check_container_* functions (3178–3230)

### Secondary (MEDIUM confidence)
- Project `CLAUDE.md` — var_* format requirements, $STD prefix rule, anti-patterns table, PR checklist

### Tertiary (LOW confidence — see Assumptions Log)
- A1: OpenMontage GitHub releases existence [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all framework behavior verified from source
- Architecture patterns: HIGH — verified from three canonical ct/ scripts and build.func source
- Pitfalls: HIGH — all pitfalls derived from direct code analysis of build.func execution flow
- update_script correctness: HIGH — execution context confirmed (container-side), $STD/msg patterns verified

**Research date:** 2026-04-07
**Valid until:** 2026-06-01 (community-scripts framework is stable; check if build.func API changes)
