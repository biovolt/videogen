# Phase 1: Install Script - Research

**Researched:** 2026-04-07
**Domain:** community-scripts ProxmoxVE install script, Python/Node.js/FFmpeg setup inside LXC
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Prompt for three API keys during install: FAL_KEY, ELEVENLABS_API_KEY, OPENAI_API_KEY
- **D-02:** All three prompts accept empty input (skip silently) — no re-prompting
- **D-03:** When a key is provided, write it to `.env` as `KEY=value`
- **D-04:** When a key is skipped (empty Enter), write a commented-out placeholder like `# FAL_KEY=your-key-here` so users can find and uncomment it later
- **D-05:** System dependencies first: Python (setup_uv) -> Node.js (setup_nodejs) -> FFmpeg (setup_ffmpeg) -> git clone OpenMontage -> pip install -> npm install -> .env setup
- **D-06:** All system tools are installed before application code is cloned or configured
- **D-07:** One msg_info/msg_ok pair per major step (~8 pairs total). No sub-step messages.
- **D-08:** Major steps: Python, Node.js, FFmpeg, git clone, Python deps, Node deps, .env setup, final completion

### Claude's Discretion

- Version tracking method (git tag vs commit hash for `/opt/OpenMontage_version.txt`) — Claude picks based on community-scripts conventions
- Piper TTS handling — deferred to first run (not installed at install time, per STATE.md note)
- Python version number (3.11 or 3.12 — whichever setup_uv defaults to or is most stable)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INST-01 | Python 3.10+ installed via `setup_uv` (PEP 668 safe) | tools.func wiki confirms `PYTHON_VERSION="3.12" setup_uv` provisions Python via uv |
| INST-02 | Node.js 18+ installed via `setup_nodejs` | tools.func wiki confirms `NODE_VERSION="22" setup_nodejs`; Remotion v4 minimum is Node 16 so 22 is safe |
| INST-03 | FFmpeg installed via `setup_ffmpeg` | tools.func wiki confirms `FFMPEG_TYPE="full" setup_ffmpeg`; Debian 12 apt FFmpeg may be 5.1.x — `full` build avoids this |
| INST-04 | OpenMontage cloned from GitHub to `/opt/openmontage` | git clone to `/opt/openmontage` then `git describe --tags` or commit hash for version file |
| INST-05 | Python dependencies installed (requirements.txt + piper-tts) | requirements.txt has 4 deps (pyyaml, pydantic, jsonschema, python-dotenv); piper-tts deferred to first run per CONTEXT.md |
| INST-06 | Node dependencies installed (remotion-composer/) | `cd /opt/openmontage/remotion-composer && $STD npm install` |
| INST-07 | `.env` created from `.env.example` | `cp .env.example .env` guarded by `[[ ! -f .env ]]` check |
| INST-08 | Optional FAL_KEY prompt during install (extended to all 3 keys per D-01) | `read -r` prompts for FAL_KEY, ELEVENLABS_API_KEY, OPENAI_API_KEY with conditional write |
</phase_requirements>

---

## Summary

The install script for Phase 1 is a standard community-scripts `install/openMontage-install.sh` that runs inside a fresh Debian 12 LXC container. It must follow the exact boilerplate pattern used by community-scripts (sourced from `$FUNCTIONS_FILE_PATH`, standard `catch_errors`/`update_os` preamble, `$STD` prefix on all commands, `msg_info`/`msg_ok` pairs, closing `motd_ssh`/`customize`/`cleanup_lxc`).

OpenMontage itself has a minimal Python footprint (4 pip packages) and uses a `remotion-composer/` subdirectory for Node.js/Remotion video rendering. The install sequence is straightforward: system runtimes first (Python via uv, Node.js, FFmpeg), then `git clone`, then deps, then `.env` setup with three optional API key prompts. Piper TTS is explicitly out of scope for install time per CONTEXT.md.

Version tracking for a git-cloned app uses `git describe --tags --always` to capture a human-readable version (falls back to commit hash if no tags exist) and writes it to `/opt/OpenMontage_version.txt`. This feeds Phase 2's `update_script()`.

**Primary recommendation:** Write the script in a single pass following the node-red-install.sh structure, replacing npm global install with git clone + uv venv pip install + npm install in subdirectory. Keep prompts simple `read -r` calls, not whiptail (install scripts use whiptail only for complex UI; simple key prompts use read).

---

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| `setup_uv` | framework function | Install uv + provision Python | PEP 668 safe on Debian 12; handles EXTERNALLY-MANAGED |
| `setup_nodejs` | framework function | Install Node.js via NodeSource | Standard for all Node apps in community-scripts |
| `setup_ffmpeg` | framework function | Install FFmpeg full build | Avoids Debian 12 apt FFmpeg (5.1.x) codec gaps |
| `uv pip install` | via setup_uv | Install Python requirements.txt | uv replaces pip inside the container |
| `npm install` | via setup_nodejs | Install Node deps in remotion-composer/ | Standard npm, no yarn or pnpm needed |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `git` | system | Clone OpenMontage repo | Installed via `$STD apt install -y git` |
| `ca-certificates` | system | HTTPS for git clone | Required for secure TLS connections |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `setup_uv` + `uv pip install` | `apt install python3-pip` | apt pip breaks on Debian 12 PEP 668; uv is the correct approach |
| `setup_ffmpeg` full build | `apt install ffmpeg` | Debian 12 provides FFmpeg 5.1.x which may lack codecs OpenMontage needs |
| `git clone` | `fetch_and_deploy_gh_release` | OpenMontage has no GitHub releases; git clone is the only option |

**Installation (inside install script):**
```bash
$STD apt install -y git ca-certificates
PYTHON_VERSION="3.12" setup_uv
NODE_VERSION="22" setup_nodejs
FFMPEG_TYPE="full" setup_ffmpeg
```

**Version notes:** [VERIFIED: tools.func wiki] Node 22 is community-scripts default LTS. Remotion v4 minimum is Node 16 [CITED: remotion.dev/docs/4-0-migration], so Node 22 is safe. Python 3.12 is the recommended version per tools.func docs.

---

## Architecture Patterns

### Recommended File Location

```
install/
└── openMontage-install.sh   # This phase's output
```

Container layout after install:
```
/opt/
└── openmontage/             # git clone target
    ├── requirements.txt
    ├── .env.example
    ├── .env                 # Created during install
    ├── tools/               # 48 Python tools
    ├── pipeline_defs/
    ├── skills/
    └── remotion-composer/   # npm install runs here
        ├── package.json
        └── node_modules/
/opt/OpenMontage_version.txt # Version tracking
```

### Pattern 1: Mandatory Boilerplate Top

**What:** Every install script must source `$FUNCTIONS_FILE_PATH` and call these six init functions in order.
**When to use:** Always — this is required, not optional.
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
```
[VERIFIED: node-red-install.sh, jellyfin-install.sh — both use this exact sequence]

### Pattern 2: msg_info / msg_ok Wrapping

**What:** Every major step is wrapped in matching msg_info/msg_ok calls; `$STD` prefixes all commands.
**When to use:** Every command that produces output.
```bash
# Source: node-red-install.sh pattern
msg_info "Installing Dependencies"
$STD apt install -y \
  git \
  ca-certificates
msg_ok "Installed Dependencies"
```
[VERIFIED: node-red-install.sh, n8n-install.sh, wger-install.sh]

### Pattern 3: setup_uv + uv pip install in venv

**What:** `setup_uv` installs uv, then `uv venv` + `uv pip install` handles Python packages inside a virtual environment.
**When to use:** Any Python app — required for PEP 668 compliance on Debian 12.
```bash
# Source: wger-install.sh pattern
PYTHON_VERSION="3.12" setup_uv

msg_info "Installing Python Dependencies"
cd /opt/openmontage
$STD uv venv
$STD uv pip install -r requirements.txt
msg_ok "Installed Python Dependencies"
```
[VERIFIED: wger-install.sh uses `$STD uv venv` + `$STD uv pip install`]

### Pattern 4: npm install in Subdirectory

**What:** Change to subdirectory and run npm install — not a global install.
**When to use:** App ships with its own package.json in a subdirectory.
```bash
msg_info "Installing Node.js Dependencies"
cd /opt/openmontage/remotion-composer
$STD npm install
msg_ok "Installed Node.js Dependencies"
```
[ASSUMED — inferred from standard npm install patterns; community-scripts has no identical subdirectory example verified]

### Pattern 5: .env Creation with Idempotency Guard

**What:** Copy `.env.example` to `.env` only if `.env` does not already exist (update safety).
**When to use:** Any app with `.env` configuration — prevents overwriting user config on re-install/update.
```bash
msg_info "Configuring Environment"
if [[ ! -f /opt/openmontage/.env ]]; then
  cp /opt/openmontage/.env.example /opt/openmontage/.env
fi
msg_ok "Configured Environment"
```
[VERIFIED: CLAUDE.md anti-patterns section — "Writing to .env during updates: Destroys user config — Check if .env exists before writing; skip if so"]

### Pattern 6: API Key Prompts with Commented Placeholder

**What:** `read -r` prompts for optional API keys; non-empty input writes `KEY=value`, empty input writes `# KEY=your-key-here`.
**When to use:** Optional API keys during install per D-01 through D-04.
```bash
# Per D-01 through D-04 (CONTEXT.md)
read -rp "Enter FAL_KEY (or press Enter to skip): " FAL_KEY_INPUT
if [[ -n "${FAL_KEY_INPUT}" ]]; then
  echo "FAL_KEY=${FAL_KEY_INPUT}" >>/opt/openmontage/.env
else
  echo "# FAL_KEY=your-key-here" >>/opt/openmontage/.env
fi
```
[ASSUMED — `read -r` prompt pattern is standard bash; the commented-placeholder behavior is from CONTEXT.md D-04]

### Pattern 7: Version Tracking for Git-Cloned Apps

**What:** After `git clone`, capture the current version with `git describe --tags --always` and write to `/opt/OpenMontage_version.txt`.
**When to use:** Git-cloned apps without GitHub Releases — `git describe --tags --always` returns a tag if one exists, falls back to commit hash.
```bash
# After git clone
RELEASE=$(cd /opt/openmontage && git describe --tags --always 2>/dev/null || git rev-parse --short HEAD)
echo "${RELEASE}" >/opt/OpenMontage_version.txt
```
[ASSUMED — community-scripts CONTRIBUTING wiki does not show a git-clone-specific example; this pattern is inferred from the `fetch_and_deploy_gh_release` version file convention + standard git tooling]

### Pattern 8: Mandatory Boilerplate Bottom

**What:** Three required closing calls — always last three lines of the script.
**When to use:** Always — missing these breaks MOTD and container state.
```bash
motd_ssh
customize
cleanup_lxc
```
[VERIFIED: node-red-install.sh, jellyfin-install.sh, wger-install.sh, n8n-install.sh — all end with exactly these three]

### Anti-Patterns to Avoid

- **`pip install -r requirements.txt` bare:** Breaks on Debian 12 PEP 668. Use `uv venv` + `uv pip install` instead.
- **`set -e` at top of file:** Interferes with `catch_errors` custom trap. Never add this.
- **Commands without `$STD` prefix:** Breaks quiet mode and fails PR review. Every command needs `$STD`.
- **Writing `.env` unconditionally:** Destroys user config on update. Always guard with `[[ ! -f .env ]]`.
- **Hardcoding `node 18.x`:** Scripts go stale. Use `NODE_VERSION="22" setup_nodejs`.
- **`source build.func` inside install script:** `build.func` is for the Proxmox host. Use `source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"` only.
- **Skipping `motd_ssh; customize; cleanup_lxc`:** Leaves dirty container and breaks MOTD.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Python install on Debian 12 | Custom pip workarounds | `PYTHON_VERSION="3.12" setup_uv` | Handles PEP 668/EXTERNALLY-MANAGED automatically |
| Node.js install | Manual NodeSource setup | `NODE_VERSION="22" setup_nodejs` | Handles NodeSource DEB822 repo, GPG key, package install |
| FFmpeg install | `apt install ffmpeg` | `FFMPEG_TYPE="full" setup_ffmpeg` | Ensures codec-complete build, not Debian 5.1.x limited package |
| Progress output | Custom echo/printf | `msg_info`/`msg_ok`/`msg_error` | Consistent styling, required for PR acceptance |
| Command output suppression | `/dev/null` redirects | `$STD` prefix | Framework standard, required for quiet/verbose mode switching |

**Key insight:** The community-scripts framework's tool functions (`setup_uv`, `setup_nodejs`, `setup_ffmpeg`) exist precisely because the naive approaches break in LXC containers on Debian 12. Using them is not optional — it is required for PR acceptance.

---

## Common Pitfalls

### Pitfall 1: piper-tts Installation

**What goes wrong:** Attempting to `pip install piper-tts` during install — it downloads ~50MB voice model and may fail due to GPU/platform requirements.
**Why it happens:** piper-tts is in OpenMontage's manual install instructions but has large runtime dependencies.
**How to avoid:** Per CONTEXT.md and STATE.md — defer piper-tts entirely. Do not include it in `requirements.txt` install step. It initializes on first run.
**Warning signs:** Install hangs downloading model files, or fails with CUDA/platform errors.

### Pitfall 2: uv pip install Without venv

**What goes wrong:** Running `uv pip install -r requirements.txt` without first running `uv venv` may fail or install to unexpected locations.
**Why it happens:** uv's pip interface requires an active virtual environment unless `--system` is passed.
**How to avoid:** Run `$STD uv venv` in the app directory first, then `$STD uv pip install -r requirements.txt`. (wger pattern confirmed.)
**Warning signs:** uv error: "No virtual environment found".

### Pitfall 3: .env Key Names

**What goes wrong:** Prompting for wrong key names or writing incorrect variable names to `.env`.
**Why it happens:** `.env.example` has many keys (FAL_KEY, GOOGLE_API_KEY, OPENAI_API_KEY, ELEVENLABS_API_KEY, etc.) — easy to get the exact variable name wrong.
**How to avoid:** The three keys from D-01 are: `FAL_KEY`, `ELEVENLABS_API_KEY`, `OPENAI_API_KEY`. These are the exact names confirmed in `.env.example`. [VERIFIED: fetched `.env.example` from calesthio/OpenMontage]
**Warning signs:** OpenMontage tools fail to find API credentials despite user entering them.

### Pitfall 4: remotion-composer npm install Path

**What goes wrong:** Running `npm install` in `/opt/openmontage/` instead of `/opt/openmontage/remotion-composer/`.
**Why it happens:** The root repo has a `package.json` only in the `remotion-composer/` subdirectory — not at the repo root.
**How to avoid:** `cd /opt/openmontage/remotion-composer && $STD npm install`. [VERIFIED: OpenMontage repo structure shows `remotion-composer/` as a distinct subdirectory]
**Warning signs:** npm error: "package.json not found" at root level.

### Pitfall 5: Version File Case Sensitivity

**What goes wrong:** Writing version to `/opt/openmontage_version.txt` (lowercase) when Phase 2's `update_script()` expects `/opt/OpenMontage_version.txt` (mixed case per APP variable).
**Why it happens:** The install directory is lowercase (`/opt/openmontage`) but the version file uses `APP` variable casing.
**How to avoid:** Per CLAUDE.md: version tracking uses `/opt/${APP}_version.txt` where `APP="OpenMontage"`. Write to `/opt/OpenMontage_version.txt`.
**Warning signs:** Phase 2's `update_script()` always shows "no update available" or fails to detect installed version.

---

## Code Examples

### Complete Script Skeleton (verified patterns)

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

msg_info "Installing Dependencies"
$STD apt install -y \
  git \
  ca-certificates
msg_ok "Installed Dependencies"

PYTHON_VERSION="3.12" setup_uv

NODE_VERSION="22" setup_nodejs

FFMPEG_TYPE="full" setup_ffmpeg

msg_info "Cloning OpenMontage"
$STD git clone https://github.com/calesthio/OpenMontage /opt/openmontage
RELEASE=$(cd /opt/openmontage && git describe --tags --always 2>/dev/null || git rev-parse --short HEAD)
echo "${RELEASE}" >/opt/OpenMontage_version.txt
msg_ok "Cloned OpenMontage"

msg_info "Installing Python Dependencies"
cd /opt/openmontage
$STD uv venv
$STD uv pip install -r requirements.txt
msg_ok "Installed Python Dependencies"

msg_info "Installing Node.js Dependencies"
cd /opt/openmontage/remotion-composer
$STD npm install
msg_ok "Installed Node.js Dependencies"

msg_info "Configuring Environment"
if [[ ! -f /opt/openmontage/.env ]]; then
  cp /opt/openmontage/.env.example /opt/openmontage/.env
fi
# API key prompts (D-01 through D-04)
read -rp "Enter FAL_KEY (or press Enter to skip): " FAL_KEY_INPUT
if [[ -n "${FAL_KEY_INPUT}" ]]; then
  echo "FAL_KEY=${FAL_KEY_INPUT}" >>/opt/openmontage/.env
else
  echo "# FAL_KEY=your-key-here" >>/opt/openmontage/.env
fi
# ... repeat for ELEVENLABS_API_KEY, OPENAI_API_KEY
msg_ok "Configured Environment"

motd_ssh
customize
cleanup_lxc
```

Source: Structure from [node-red-install.sh](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/node-red-install.sh) and [wger-install.sh](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/wger-install.sh). [VERIFIED: both fetched directly]

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `pip install` directly | `uv pip install` inside venv | Debian 12 PEP 668 | Prevents EXTERNALLY-MANAGED errors |
| `curl -sL nodesetup \| bash` | `NODE_VERSION="X" setup_nodejs` | community-scripts v2 | Standardized, GPG-verified repo setup |
| `apt install ffmpeg` | `FFMPEG_TYPE="full" setup_ffmpeg` | community-scripts tooling | Codec-complete FFmpeg vs limited Debian package |
| `/bin/bash` shebang | `#!/usr/bin/env bash` | PR requirement | PATH-independent, required for ShellCheck |

**Deprecated/outdated:**
- `pip install --break-system-packages`: Works but is a hack; uv venv is the correct approach
- NodeSource setup scripts via curl-pipe: Replaced by `setup_nodejs` framework function

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `git describe --tags --always` is the correct version tracking method for git-cloned apps (no releases) | Architecture Patterns: Pattern 7 | Phase 2 update_script() may not parse the version string correctly — easy to fix in Phase 2 |
| A2 | `read -r` prompt (not whiptail) is appropriate for API key input during install | Architecture Patterns: Pattern 6 | If community-scripts requires whiptail for all prompts, script will fail PR review; adjust to whiptail inputbox |
| A3 | `uv pip install -r requirements.txt` after `uv venv` installs into `.venv/` without needing `--system` | Architecture Patterns: Pattern 3 | If uv requires explicit venv activation, deps may not be on PATH — mitigated by activating venv before pip install |
| A4 | piper-tts should not be installed at install time (deferred to first run) | INST-05, Pitfall 1 | REQUIREMENTS.md INST-05 says "requirements.txt + piper-tts" — if piper-tts must be installed at install time, add separate step |

---

## Open Questions

1. **piper-tts — install time or first run?**
   - What we know: STATE.md says "Piper TTS downloads ~50MB model on first run (not at install time)"; REQUIREMENTS.md INST-05 says "requirements.txt + piper-tts"
   - What's unclear: INST-05 literally lists piper-tts as an install requirement, but STATE.md records it as deferred
   - Recommendation: CONTEXT.md (D-05 order) does not include piper-tts in the install sequence. Treat STATE.md as the authoritative deferral decision. If piper-tts is required by v1, it becomes a separate step in the plan flagged for user confirmation.

2. **uv venv activation for subsequent commands**
   - What we know: `uv venv` creates `.venv/` directory; `uv pip install` targets active venv
   - What's unclear: Whether OpenMontage tools need to be invoked with the venv active, and whether install script needs to configure anything to make that happen (e.g., add venv to PATH, create activation wrapper)
   - Recommendation: Phase 1 only installs deps. Phase 1 does not need to configure runtime venv activation — that's a concern for the systemd service or run scripts in Phase 2/3.

---

## Environment Availability

Phase 1 produces an install script that runs inside an LXC container on Proxmox VE. The container does not exist until Phase 2's `ct/openMontage.sh` creates it. Environment availability cannot be probed on the current machine.

| Dependency | Required By | Available | Notes |
|------------|-------------|-----------|-------|
| Debian 12 LXC (Proxmox) | Entire script | Not provable here | Provided by Proxmox VE when ct/ script runs |
| Internet access in container | git clone, apt, npm, uv | Required | network_check function verifies this |
| GitHub reachability | `git clone calesthio/OpenMontage` | Required | Standard — no special access needed |

---

## Project Constraints (from CLAUDE.md)

| Directive | Applies to This Phase |
|-----------|----------------------|
| Shebang must be `#!/usr/bin/env bash` | Yes — enforced in every install script |
| build.func sourced from official URL | N/A for install script — install script uses `$FUNCTIONS_FILE_PATH` |
| Copyright header: `# Copyright (c) 2021-2026 community-scripts ORG` | Yes |
| `# Author:` line | Yes |
| `# License: MIT` line | Yes |
| `# Source:` pointing to OpenMontage repo | Yes |
| All `var_*` use `${var_name:-default}` form | N/A — `var_*` variables are in ct/ script (Phase 2) |
| All commands prefixed with `$STD` | Yes — every command |
| `motd_ssh`, `customize`, `cleanup_lxc` at end | Yes — mandatory closing sequence |
| Version saved to `/opt/${APP}_version.txt` | Yes — `/opt/OpenMontage_version.txt` |
| No `set -e` at top | Yes — `catch_errors` sets its own trap |
| No bare `pip install` | Yes — use `uv pip install` inside venv |
| No writing to `.env` during updates | Yes — guard with `[[ ! -f .env ]]` |
| ShellCheck zero warnings | Yes — use `$STD`, quote variables, `[[ ]]` not `[ ]` |
| Application must be open-source | Yes — OpenMontage is open-source on GitHub |

---

## Sources

### Primary (HIGH confidence)
- [node-red-install.sh](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/node-red-install.sh) — Verified boilerplate, setup_nodejs, msg_info/msg_ok pattern, closing sequence
- [wger-install.sh](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/wger-install.sh) — Verified uv venv + uv pip install pattern
- [jellyfin-install.sh](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/jellyfin-install.sh) — Verified boilerplate top/bottom
- [tools.func wiki](https://github.com/community-scripts/ProxmoxVE/wiki/tools.func) — setup_uv, setup_nodejs, setup_ffmpeg function signatures
- [OpenMontage .env.example](https://raw.githubusercontent.com/calesthio/OpenMontage/main/.env.example) — Confirmed key names: FAL_KEY, ELEVENLABS_API_KEY, OPENAI_API_KEY
- [OpenMontage requirements.txt](https://raw.githubusercontent.com/calesthio/OpenMontage/main/requirements.txt) — 4 deps: pyyaml, pydantic, jsonschema, python-dotenv
- [OpenMontage remotion-composer/package.json](https://raw.githubusercontent.com/calesthio/OpenMontage/main/remotion-composer/package.json) — Remotion v4 deps, React 18, TypeScript; no engines field

### Secondary (MEDIUM confidence)
- [Remotion v4.0 Migration docs](https://www.remotion.dev/docs/4-0-migration) — Node.js minimum is 16; Node 22 is safe
- [community-scripts CONTRIBUTING wiki](https://github.com/community-scripts/ProxmoxVE/wiki/CONTRIBUTING) — version file convention documented
- CLAUDE.md (project file) — Full install script structure, anti-patterns, PR checklist

### Tertiary (LOW confidence)
- Version tracking via `git describe --tags --always` for git-cloned apps — inferred from CONTRIBUTING patterns, not directly shown in a community-scripts script example

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — tools.func wiki verified directly; reference scripts fetched and confirmed
- Architecture patterns: HIGH (boilerplate) / MEDIUM (uv venv) / LOW (version tracking, read prompts)
- OpenMontage structure: HIGH — .env.example, requirements.txt, and package.json all fetched directly
- Pitfalls: HIGH — most derived from CLAUDE.md anti-patterns (authoritative) + direct observation of repo structure

**Research date:** 2026-04-07
**Valid until:** 2026-05-07 (community-scripts framework is stable; OpenMontage is actively developed — re-check requirements.txt if more than 30 days pass)
