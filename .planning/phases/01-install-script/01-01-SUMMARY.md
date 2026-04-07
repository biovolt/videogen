---
phase: 01-install-script
plan: "01"
subsystem: install-script
tags: [installer, community-scripts, proxmox, lxc, debian12]
dependency_graph:
  requires: []
  provides: [install/openMontage-install.sh]
  affects: [Phase 2 ct/ orchestrator, Phase 2 update_script()]
tech_stack:
  added: [shellcheck, uv, setup_uv, setup_nodejs, setup_ffmpeg]
  patterns: [community-scripts boilerplate, msg_info/msg_ok wrapping, $STD prefix, uv venv + uv pip install, idempotent .env guard]
key_files:
  created: [install/openMontage-install.sh]
  modified: []
decisions:
  - D-01 through D-04: Three API key prompts (FAL_KEY, ELEVENLABS_API_KEY, OPENAI_API_KEY) with commented-placeholder fallback on skip
  - D-05: Install order Python -> Node.js -> FFmpeg -> git clone -> pip install -> npm install -> .env
  - D-06: All system tools installed before application code cloned
  - D-07/D-08: Eight msg_info/msg_ok pairs, one per major step
  - SC1091: Added shellcheck source=/dev/null directive for the mandatory FUNCTIONS_FILE_PATH source pattern
  - SC2015: Replaced A && B || C with explicit if/then for git describe fallback to avoid non-if-then-else risk
metrics:
  duration: "~1 minute"
  completed: "2026-04-07"
  tasks_completed: 2
  files_created: 1
  files_modified: 0
---

# Phase 1 Plan 1: Install Script — Summary

**One-liner:** Community-scripts-compliant in-container installer using setup_uv (Python 3.12) + setup_nodejs (Node 22) + setup_ffmpeg (full), with three optional API key prompts and idempotent .env guard.

## What Was Built

`install/openMontage-install.sh` — the complete in-container installer for OpenMontage on Debian 12 LXC. The script:

1. Sources the community-scripts function library via `$FUNCTIONS_FILE_PATH`
2. Runs the mandatory six-function preamble (color, verb_ip6, catch_errors, setting_up_container, network_check, update_os)
3. Installs git and ca-certificates via `apt-get`
4. Provisions Python 3.12 via `PYTHON_VERSION="3.12" setup_uv`
5. Provisions Node.js 22 via `NODE_VERSION="22" setup_nodejs`
6. Provisions FFmpeg full build via `FFMPEG_TYPE="full" setup_ffmpeg`
7. Clones OpenMontage to `/opt/openmontage` and writes version to `/opt/OpenMontage_version.txt` via `git describe --tags --always`
8. Installs Python dependencies with `uv venv` + `uv pip install -r requirements.txt`
9. Installs Node.js dependencies with `npm install` in `/opt/openmontage/remotion-composer`
10. Creates `.env` from `.env.example` (guarded by existence check), then prompts for FAL_KEY, ELEVENLABS_API_KEY, and OPENAI_API_KEY with commented-placeholder fallback on skip
11. Ends with `motd_ssh`, `customize`, `cleanup_lxc`

## Requirements Coverage

| ID | Description | Status |
|----|-------------|--------|
| INST-01 | Python 3.10+ via setup_uv | Done — Python 3.12 |
| INST-02 | Node.js 18+ via setup_nodejs | Done — Node.js 22 |
| INST-03 | FFmpeg via setup_ffmpeg | Done — full build |
| INST-04 | OpenMontage cloned to /opt/openmontage, version tracked | Done |
| INST-05 | Python deps via uv venv + uv pip install | Done |
| INST-06 | Node deps via npm install in remotion-composer/ | Done |
| INST-07 | .env created from .env.example, idempotent | Done |
| INST-08 | Three API key prompts with skip/placeholder behavior | Done |

## Commits

| Task | Description | Commit |
|------|-------------|--------|
| Tasks 1+2 | Write install script + ShellCheck fixes | 09157b2 |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed SC2015 info warning in RELEASE version capture**
- **Found during:** Task 2 (ShellCheck validation)
- **Issue:** `RELEASE=$(cd /opt/openmontage && git describe ... 2>/dev/null || git rev-parse --short HEAD)` triggers SC2015 because `A && B || C` is not if-then-else — C can run when A is true
- **Fix:** Replaced with explicit `if [[ -z "${RELEASE}" ]]; then RELEASE=$(git -C /opt/openmontage rev-parse --short HEAD); fi`
- **Files modified:** install/openMontage-install.sh
- **Commit:** 09157b2

**2. [Rule 2 - Missing] Added shellcheck source=/dev/null directive**
- **Found during:** Task 2 (ShellCheck validation)
- **Issue:** SC1091 info: "Not following: /dev/stdin was not specified as input" — expected for the mandatory community-scripts `source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"` pattern
- **Fix:** Added `# shellcheck source=/dev/null` directive above the source line — standard approach for community-scripts patterns
- **Files modified:** install/openMontage-install.sh
- **Commit:** 09157b2

Note: Both Task 1 and Task 2 are committed together as 09157b2 since the ShellCheck fixes were applied during the same writing pass before the first commit.

## Known Stubs

None — all data flows are wired. The API key prompts correctly read from stdin and write to `.env` via sed. The version file is written from `git describe`. No placeholder values flow to any output.

## Threat Flags

No new security surface beyond what was modeled in the plan's threat_model. The `sed -i` pipe-delimiter approach (T-01-01 mitigation) is implemented as specified. The .env existence guard (T-01-05 partial mitigation) is implemented.

## Self-Check

- [x] install/openMontage-install.sh exists
- [x] install/openMontage-install.sh is executable
- [x] ShellCheck passes with zero errors and zero warnings
- [x] Commit 09157b2 exists in git log
- [x] 8 msg_info + 8 msg_ok pairs
- [x] 3 read -rp prompts
- [x] Last 3 lines: motd_ssh, customize, cleanup_lxc
- [x] No set -e, no bare pip install, no source build.func, no piper-tts
