---
phase: 02-host-orchestrator-and-update
reviewed: 2026-04-07T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - ct/openMontage.sh
  - install/openMontage-install.sh
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-04-07
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Both scripts follow the community-scripts boilerplate correctly: shebang, copyright header, proper sourcing, `$STD` prefixes, `motd_ssh`/`customize`/`cleanup_lxc` at the end of the install script, and `${var:-default}` forms. The most significant issues are a version-tracking inconsistency between install and update that will cause spurious updates, a silent exit-0 on error in `update_script`, and a working-directory assumption in `update_script` that could silently use a stale `requirements.txt`.

---

## Warnings

### WR-01: `update_script` exits 0 on installation-not-found error

**File:** `ct/openMontage.sh:30`
**Issue:** `exit` with no argument exits with code 0, signaling success to the caller even though the update was aborted because no installation was found. Downstream tooling (or the user) cannot distinguish a successful no-op from an error.
**Fix:**
```bash
if [[ ! -f /opt/OpenMontage_version.txt ]]; then
  msg_error "No ${APP} installation found!"
  exit 1   # was: exit
fi
```

---

### WR-02: Version-tracking mismatch between install and update will trigger spurious upgrades

**File:** `install/openMontage-install.sh:33-39` / `ct/openMontage.sh:33-40`
**Issue:** The install script clones the default git branch (not a tagged release), then attempts to resolve a release tag from the GitHub API. If no releases exist, it falls back to a short commit SHA and writes that to `/opt/OpenMontage_version.txt`. The `update_script` in `ct/` fetches the latest release tag; if there are no releases it gets an empty string and exits with error — there is no matching fallback. If a release tag does exist but the cloned HEAD is a different commit, the stored version will be the tag string but the code is not pinned to it, so the update check will always show "already at RELEASE" while the code may actually be on a different commit.

The fix is to check out the release tag immediately after cloning if one exists:
```bash
$STD git clone https://github.com/calesthio/OpenMontage /opt/openmontage
RELEASE=$(curl -fsSL https://api.github.com/repos/calesthio/OpenMontage/releases/latest \
  | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -n "${RELEASE}" ]]; then
  $STD git -C /opt/openmontage checkout "${RELEASE}"
else
  RELEASE=$(git -C /opt/openmontage rev-parse --short HEAD)
fi
echo "${RELEASE}" >/opt/OpenMontage_version.txt
```

And in `ct/openMontage.sh`, add the same no-release fallback so both scripts agree:
```bash
RELEASE=$(curl -fsSL https://api.github.com/repos/calesthio/OpenMontage/releases/latest \
  | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "${RELEASE}" ]]; then
  msg_error "Could not fetch latest release from GitHub"
  exit 1
fi
```
If the project has no GitHub releases yet, both scripts need a consistent strategy (either always use git SHA, or always use tags).

---

### WR-03: `update_script` Python dependency reinstall uses relative `requirements.txt` after `cd` to a subdirectory

**File:** `ct/openMontage.sh:42-47`
**Issue:** Line 42 does `cd /opt/openmontage`. Line 47 runs `uv pip install ... -r requirements.txt`. Then line 51 does `cd /opt/openmontage/remotion-composer`. This sequence is correct as written. However, if the order is ever changed or an error causes a fallthrough, the relative `requirements.txt` path will silently resolve to the wrong file. Using an absolute path eliminates this fragility.
**Fix:**
```bash
$STD uv pip install --python /opt/openmontage/.venv/bin/python \
  -r /opt/openmontage/requirements.txt
```

---

### WR-04: Inline Python heredoc uses system `python3` instead of uv-managed Python

**File:** `install/openMontage-install.sh:62`
**Issue:** The `.env` configuration script is invoked with `python3 - <<'PYEOF'`. On Debian 12 the system `python3` may be 3.11 rather than the 3.12 installed by `setup_uv`. While the script only uses stdlib (`re`, `os`) and will work on either version, it is inconsistent and could cause confusion if a future maintainer adds imports that depend on the project's specific Python version.
**Fix:** Replace `python3` with the uv-managed interpreter:
```bash
/opt/openmontage/.venv/bin/python3 - <<'PYEOF'
```
If the venv does not exist at this point (it is created on line 44, before this block on line 62, so it does), or use:
```bash
uv run --python /opt/openmontage/.venv/bin/python3 - <<'PYEOF'
```

---

## Info

### IN-01: Copyright header appears after `source` call

**File:** `ct/openMontage.sh:2-6`
**Issue:** The `source <(curl ...)` line appears on line 2, before the copyright/author/license comment block on lines 3-6. Community-scripts PR examples (e.g., `ct/jellyfin.sh`) place the comment block immediately after the shebang and before `source`. This is a style issue with no runtime effect, but it may be flagged during PR review.
**Fix:** Move lines 3-6 to immediately after line 1:
```bash
#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: calesthio
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/calesthio/OpenMontage
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
```

---

### IN-02: `npm install` in `update_script` has no `--omit=dev` flag

**File:** `ct/openMontage.sh:52`
**Issue:** The Node.js dependency reinstall during update runs bare `npm install`, which installs all dependencies including devDependencies. In production this is typically undesirable. The install script has the same pattern. If the repo's `package.json` has large dev dependencies (e.g., Remotion's dev toolchain), updates will be slower and consume more disk than necessary.
**Fix:** If production-only deps are sufficient:
```bash
$STD npm install --omit=dev
```
If build steps require devDeps (e.g., Remotion rendering), keep as-is and document the reason.

---

### IN-03: No systemd service or process manager configured

**File:** `install/openMontage-install.sh` (overall)
**Issue:** The install script clones the repo, installs dependencies, and configures the `.env`, but does not install a systemd service unit to start the application on boot. Without this, users must start the application manually after each container restart. Community-scripts installers typically drop a `.service` file and `systemctl enable --now`.
**Fix:** Add a service unit if OpenMontage has a defined entry point, for example:
```bash
msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/openmontage.service
[Unit]
Description=OpenMontage
After=network.target

[Service]
WorkingDirectory=/opt/openmontage
EnvironmentFile=/opt/openmontage/.env
ExecStart=/opt/openmontage/.venv/bin/python -m openmontage
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now openmontage
msg_ok "Created Service"
```
Adjust `ExecStart` to match the actual entry point from the OpenMontage repository.

---

_Reviewed: 2026-04-07_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
