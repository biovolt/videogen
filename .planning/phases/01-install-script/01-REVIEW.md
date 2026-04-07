---
phase: 01-install-script
reviewed: 2026-04-07T00:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - install/openMontage-install.sh
findings:
  critical: 1
  warning: 5
  info: 1
  total: 7
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-04-07
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Reviewed `install/openMontage-install.sh` against community-scripts conventions (from CLAUDE.md) and general shell script correctness. The script follows the required boilerplate structure and uses the correct framework functions (`setup_uv`, `setup_nodejs`, `setup_ffmpeg`, `motd_ssh`, `customize`, `cleanup_lxc`). However, there are several issues that will cause the script to malfunction in real deployments: interactive prompts that hang when there is no TTY, a uv virtual environment that is created but never activated before use, API keys echoed in plaintext, and bare `exit` calls that mask failures.

## Critical Issues

### CR-01: API keys echoed in plaintext during `read` prompts

**File:** `install/openMontage-install.sh:56,63,70`
**Issue:** All three `read -rp` invocations print the API key characters to the terminal as the user types. API keys (FAL_KEY, ELEVENLABS_API_KEY, OPENAI_API_KEY) should never be displayed.
**Fix:**
```bash
read -rsp "Enter FAL_KEY (or press Enter to skip): " FAL_KEY_INPUT
echo  # move to next line after silent input
```
Apply the `-s` (silent) flag to all three `read` calls on lines 56, 63, and 70.

## Warnings

### WR-01: Interactive `read` prompts will hang or silently skip without a TTY

**File:** `install/openMontage-install.sh:56,63,70`
**Issue:** Community-scripts install scripts run inside the container over a non-interactive `bash -c` pipe invoked from the Proxmox host. There is no TTY at that point. `read` will either block indefinitely or return immediately with empty input (no key configured). The correct pattern is to collect user input in the `ct/openMontage.sh` orchestrator (which runs on the host with a TTY) and pass the values into the container as environment variables, then reference them inside the install script.
**Fix:** Move the three `read` prompts to `ct/openMontage.sh` inside the `install_script` function, export the variables, and in the install script reference them:
```bash
# In ct/openMontage.sh install_script():
read -rsp "Enter FAL_KEY (or press Enter to skip): " FAL_KEY
echo
export FAL_KEY

# In install/openMontage-install.sh:
if [[ -n "${FAL_KEY:-}" ]]; then
  sed -i "s|^FAL_KEY=.*|FAL_KEY=${FAL_KEY}|" /opt/openmontage/.env
fi
```

### WR-02: `uv venv` created but never activated before `uv pip install`

**File:** `install/openMontage-install.sh:43-44`
**Issue:** `uv venv` creates a `.venv` in `/opt/openmontage`, but the next line runs `uv pip install -r requirements.txt` without pointing uv at that venv. Without explicit activation or `--python .venv/bin/python`, uv may install into a global or unrelated environment, so the application will fail to find its dependencies at runtime.
**Fix:**
```bash
$STD uv venv /opt/openmontage/.venv
$STD uv pip install --python /opt/openmontage/.venv/bin/python -r requirements.txt
```

### WR-03: `cp .env.example` without checking the file exists

**File:** `install/openMontage-install.sh:54`
**Issue:** If the repository does not contain `.env.example`, the `cp` command fails silently (or errors) and all subsequent `sed` commands operate on a missing file, leaving the environment unconfigured with no diagnostic message.
**Fix:**
```bash
if [[ -f /opt/openmontage/.env.example ]]; then
  cp /opt/openmontage/.env.example /opt/openmontage/.env
else
  msg_error ".env.example not found in repository — cannot configure environment"
  exit 1
fi
```

### WR-04: `sed` substitution uses `|` as delimiter but API key values are not sanitized

**File:** `install/openMontage-install.sh:58,65,72`
**Issue:** The `sed -i "s|^KEY=.*|KEY=${VALUE}|"` pattern will silently produce a malformed `.env` if the user's key contains a `|` character, a `\`, or other sed metacharacters. While current provider key formats don't use these, the script provides no protection.
**Fix:** Use `printf '%s\n' "${VALUE}"` piped through `sed` escaping, or use a Python one-liner for safer substitution:
```bash
python3 -c "
import re, sys
content = open('/opt/openmontage/.env').read()
content = re.sub(r'^FAL_KEY=.*', 'FAL_KEY=' + sys.argv[1], content, flags=re.M)
open('/opt/openmontage/.env', 'w').write(content)
" "${FAL_KEY_INPUT}"
```
At minimum, document that keys must not contain `|` or `\`.

### WR-05: `exit` without status code masks failures

**File:** `install/openMontage-install.sh:42,48`
**Issue:** `cd /opt/openmontage || exit` exits with code 0 on failure, which signals success to the calling framework. The framework's error handler may not catch this, and the failure will be invisible in logs.
**Fix:**
```bash
cd /opt/openmontage || { msg_error "Failed to change directory to /opt/openmontage"; exit 1; }
cd /opt/openmontage/remotion-composer || { msg_error "Failed to change directory to remotion-composer"; exit 1; }
```

## Info

### IN-01: `APP` variable never declared — version file path is hardcoded

**File:** `install/openMontage-install.sh:38`
**Issue:** The project convention (per CLAUDE.md) is to reference `/opt/${APP}_version.txt`. The install script never declares `APP`, so line 38 hardcodes the path as `/opt/OpenMontage_version.txt`. This works as written but is inconsistent with the pattern and will silently diverge if the app name changes.
**Fix:**
```bash
APP="OpenMontage"
# ...
echo "${RELEASE}" > "/opt/${APP}_version.txt"
```

---

_Reviewed: 2026-04-07_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
