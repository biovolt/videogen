---
phase: 01-install-script
verified: 2026-04-07T14:39:27Z
status: human_needed
score: 4/5
overrides_applied: 0
re_verification: false
human_verification:
  - test: "Run install/openMontage-install.sh on a fresh Debian 12 container"
    expected: "Script completes without errors; Python 3.12, Node.js 22, FFmpeg, and git are installed; /opt/openmontage exists with Python and Node deps installed; /opt/openmontage/.env is created from .env.example"
    why_human: "Cannot execute inside a live Debian 12 LXC from this context; bash -n and ShellCheck confirm syntax but not runtime behavior (network fetches, framework functions, uv/npm execution)"
---

# Phase 1: Install Script Verification Report

**Phase Goal:** A working install/openMontage-install.sh that installs all dependencies and leaves a functional OpenMontage container
**Verified:** 2026-04-07T14:39:27Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Running the install script on a fresh Debian 12 container completes without errors | ? HUMAN | `bash -n` passes; ShellCheck 0 errors/warnings on install script; runtime behavior cannot be verified without a live container |
| 2 | Python 3.10+, Node.js 18+, FFmpeg, and git are available inside the container after install | ? HUMAN | `PYTHON_VERSION="3.12" setup_uv`, `NODE_VERSION="22" setup_nodejs`, `FFMPEG_TYPE="full" setup_ffmpeg`, `$STD apt-get install -y git ca-certificates` all present and correctly formed; framework invocations cannot be executed here |
| 3 | OpenMontage is cloned to /opt/openmontage and all Python and Node dependencies are installed | ✓ VERIFIED | `$STD git clone https://github.com/calesthio/OpenMontage /opt/openmontage` (line 35); `$STD uv venv /opt/openmontage/.venv` + `$STD uv pip install ... -r requirements.txt` (lines 46-47); `cd /opt/openmontage/remotion-composer || exit` + `$STD npm install` (lines 51-52). All wired and substantive. |
| 4 | A .env file exists at /opt/openmontage/.env (created from .env.example, not overwriting an existing one) | ✓ VERIFIED | Guard `if [[ ! -f /opt/openmontage/.env ]]` (line 56) wraps the entire env setup block; `.env.example` existence is also checked (line 57) with `msg_error` on missing; `cp /opt/openmontage/.env.example /opt/openmontage/.env` (line 61). Idempotent. |
| 5 | The FAL_KEY prompt appears during install and the supplied value is written to .env | ✓ VERIFIED | Prompts are in `ct/openMontage.sh` `install_script()` via `read -rsp` (lines 52, 55, 58); values written to `/root/.install_env` via `pct exec` heredoc (lines 67-71); install script sources `/root/.install_env` (line 13); Python block reads `os.environ.get('FAL_KEY', '')` and writes to `.env` via `re.sub` with lambda replacement (lines 78-90). Data flow is complete. |

**Score:** 4/5 truths verified (1 requires human runtime test)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `install/openMontage-install.sh` | Complete in-container installer for OpenMontage | ✓ VERIFIED | Exists, executable (`-rwxr-xr-x`), 103 lines, contains `source /dev/stdin` (line 8). ShellCheck passes with 0 errors and 0 warnings. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `install/openMontage-install.sh` | `/opt/OpenMontage_version.txt` | GitHub Releases API + git rev-parse fallback | ✓ WIRED | `curl` GitHub API for `tag_name` (line 36-37); fallback `git -C /opt/openmontage rev-parse --short HEAD` (line 39); `echo "${RELEASE}" >/opt/OpenMontage_version.txt` (line 41). Pattern `OpenMontage_version.txt` present. |
| `install/openMontage-install.sh` | `/opt/openmontage/.env` | cp .env.example .env guarded by existence check | ✓ WIRED | `if [[ ! -f /opt/openmontage/.env ]]` (line 56); `cp /opt/openmontage/.env.example /opt/openmontage/.env` (line 61). Pattern `! -f /opt/openmontage/.env` present. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `install/openMontage-install.sh` Python block | `FAL_KEY`, `ELEVENLABS_API_KEY`, `OPENAI_API_KEY` | `os.environ.get(var, '')` sourced from `/root/.install_env` written by `pct exec` in `ct/openMontage.sh` | Yes — real user input or empty string producing commented placeholder | ✓ FLOWING |
| `install/openMontage-install.sh` | `RELEASE` | GitHub Releases API (`curl -fsSL`) with `git rev-parse` fallback | Yes — real tag or commit hash | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Install script syntax valid | `bash -n install/openMontage-install.sh` | Exit 0 | ✓ PASS |
| Install script ShellCheck clean | `shellcheck install/openMontage-install.sh` | 0 errors, 0 warnings | ✓ PASS |
| ct/ script syntax valid | `bash -n ct/openMontage.sh` | Exit 0 | ✓ PASS |
| Boilerplate preamble order correct | grep line numbers | source(8), color(9), verb_ip6(10), catch_errors(11), setting_up_container(14), network_check(15), update_os(16) | ✓ PASS |
| Closing sequence correct | `tail -3 install/openMontage-install.sh` | `motd_ssh`, `customize`, `cleanup_lxc` | ✓ PASS |
| Exactly 8 msg_info + 8 msg_ok pairs | `grep -c msg_info` | 8 and 8 | ✓ PASS |
| No bare pip install | `grep 'pip install'` excluding `uv pip` | 0 matches | ✓ PASS |
| No `set -e` | `grep 'set -e'` | 0 matches | ✓ PASS |
| No `source build.func` | `grep 'source build.func'` | 0 matches | ✓ PASS |
| No piper-tts | `grep 'piper'` | 0 matches | ✓ PASS |
| Runtime install on Debian 12 | (requires live container) | N/A | ? SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| INST-01 | 01-01-PLAN.md | Python 3.10+ installed via `setup_uv` (PEP 668 safe) | ✓ SATISFIED | `PYTHON_VERSION="3.12" setup_uv` at line 23 |
| INST-02 | 01-01-PLAN.md | Node.js 18+ installed via `setup_nodejs` | ✓ SATISFIED | `NODE_VERSION="22" setup_nodejs` at line 27 |
| INST-03 | 01-01-PLAN.md | FFmpeg installed via `setup_ffmpeg` | ✓ SATISFIED | `FFMPEG_TYPE="full" setup_ffmpeg` at line 31 |
| INST-04 | 01-01-PLAN.md | OpenMontage cloned from GitHub to /opt/openmontage | ✓ SATISFIED | `$STD git clone https://github.com/calesthio/OpenMontage /opt/openmontage` at line 35; version at `/opt/OpenMontage_version.txt` |
| INST-05 | 01-01-PLAN.md | Python dependencies installed (requirements.txt) | ✓ SATISFIED | `$STD uv venv /opt/openmontage/.venv` + `$STD uv pip install --python ... -r requirements.txt` at lines 46-47 |
| INST-06 | 01-01-PLAN.md | Node dependencies installed (remotion-composer/) | ✓ SATISFIED | `cd /opt/openmontage/remotion-composer` + `$STD npm install` at lines 51-52 |
| INST-07 | 01-01-PLAN.md | .env created from .env.example | ✓ SATISFIED | Existence-guarded cp at line 61; `.env.example` presence verified with `msg_error` on missing |
| INST-08 | 01-01-PLAN.md | Optional FAL_KEY prompt during install | ✓ SATISFIED | Prompt in `ct/install_script()`; value forwarded to container via `/root/.install_env`; Python block writes to `.env` or inserts commented placeholder |

All 8 requirement IDs from plan frontmatter accounted for. No orphaned requirements for Phase 1 in REQUIREMENTS.md (CT-*, UPD-*, PR-* are assigned to Phases 2 and 3).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `ct/openMontage.sh` | 67-71 | Unquoted heredoc `<<EOF` embeds API key values wrapped in single quotes: `export FAL_KEY='${FAL_KEY}'` — a key containing a literal single quote will produce invalid shell syntax in `/root/.install_env` | ⚠️ Warning | If a user enters a key with a `'` character, sourcing `.install_env` in the install script fails or produces a parse error. Does not affect users with well-formed API keys. ct/ is formally Phase 2 scope. |
| `ct/openMontage.sh` | 7 | SC1090 warning: `source <(curl -s ...)` — ShellCheck cannot follow non-constant source | ℹ️ Info | Standard community-scripts pattern; zero-warning cleanup is Phase 3 scope (PR-04). Not a functional defect. |
| `ct/openMontage.sh` | 37 | `git pull` has no `|| exit` error handling inside `update_script()` | ⚠️ Warning | Update would silently continue if pull fails, then re-install deps from stale code. Phase 2 scope (update_script ownership). |

No blockers found in `install/openMontage-install.sh`. The anti-patterns above are in `ct/openMontage.sh`, which was created during Phase 1 code review but is formally owned by Phase 2.

### Human Verification Required

#### 1. End-to-End Runtime Test

**Test:** On a fresh Debian 12 container (or VM), set `FUNCTIONS_FILE_PATH` to a stub that provides `color`, `verb_ip6`, `catch_errors`, `setting_up_container`, `network_check`, `update_os`, `msg_info`, `msg_ok`, `msg_error`, `motd_ssh`, `customize`, `cleanup_lxc`, `setup_uv`, `setup_nodejs`, `setup_ffmpeg`, and `$STD`. Then run `bash install/openMontage-install.sh`.

**Expected:**
- Script completes without error
- `/opt/openmontage/` exists and contains the cloned repository
- `/opt/openmontage/.venv/` exists with Python packages installed
- `/opt/openmontage/remotion-composer/node_modules/` exists
- `/opt/openmontage/.env` exists (created from `.env.example`)
- `/opt/OpenMontage_version.txt` contains a non-empty string

**Why human:** Cannot execute network-dependent framework functions (`setup_uv`, `setup_nodejs`, `setup_ffmpeg`, `git clone`, `npm install`) in this verification context. `bash -n` and ShellCheck confirm syntax only.

### Gaps Summary

No gaps blocking the Phase 1 goal. The install script (`install/openMontage-install.sh`) is complete, structurally correct, ShellCheck-clean, and all 8 INST-* requirements are implemented and wired.

Two warnings exist in `ct/openMontage.sh` (single-quote injection risk in API key heredoc, unguarded `git pull` in `update_script`), but `ct/` is formally Phase 2 scope. These should be tracked as input requirements for the Phase 2 plan.

One item (SC1) requires human runtime verification — the script cannot be executed in this context to confirm the framework functions succeed on a live Debian 12 container.

---

_Verified: 2026-04-07T14:39:27Z_
_Verifier: Claude (gsd-verifier)_
