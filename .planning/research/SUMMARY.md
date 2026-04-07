# Project Research Summary

**Project:** OpenMontage Proxmox LXC Installer
**Domain:** Proxmox VE community-script installer (bash, two-file pattern)
**Researched:** 2026-04-07
**Confidence:** HIGH

## Executive Summary

This project is a two-file bash installer following the community-scripts/ProxmoxVE framework — `ct/openMontage.sh` (runs on the Proxmox host) and `install/openMontage-install.sh` (runs inside the LXC container). The framework provides all orchestration, container creation, interactive wizard, and output functions via `build.func` and `install.func`. The author's only job is to declare container defaults, install the application's dependencies, and implement an update function. This is a well-documented, heavily precedented domain with 400+ reference scripts in the repo.

The recommended approach is to build the install script first (testable on any Debian 12 container), then wire it to the host orchestrator, then add the ASCII header. The install script must handle three non-obvious concerns: use `setup_uv` or a venv for Python (Debian 12 blocks system pip via PEP 668), install `gpg` before NodeSource setup, and default disk size to 12GB (not 8GB) to accommodate the full Python + Node.js + FFmpeg stack. GPU passthrough should be declared via `var_gpu="yes"` to expose the option in advanced mode but default to off.

The critical risk is PR rejection: community-scripts maintainers enforce hard requirements including a functioning `update_script()`, ShellCheck passing, exact filename conventions, `$STD` prefixes on all commands, and `motd_ssh`/`customize`/`cleanup_lxc` at the end of every install script. These are not style suggestions — missing any one of them blocks merge. The update function must never overwrite `.env` (which contains user API keys). Design the config-preservation contract before writing install logic.

## Key Findings

### Recommended Stack

Two bash scripts consuming the community-scripts framework. All tooling (container creation, menus, color output, error handling, telemetry) comes from framework functions fetched at runtime — no dependencies to manage. The install script handles: Debian 12 system packages via apt, Python via `setup_uv` (handles PEP 668 correctly), Node.js via `NODE_VERSION="22" setup_nodejs`, and FFmpeg via `FFMPEG_TYPE="full" setup_ffmpeg`.

**Core technologies:**
- `build.func` / `install.func`: Framework engine — provides all orchestration, not owned by this project
- Debian 12 (Bookworm): Base OS — community-scripts standard, lighter than Ubuntu
- `setup_uv` (PYTHON_VERSION="3.12"): Python install — handles Debian 12's EXTERNALLY-MANAGED enforcement correctly
- `NODE_VERSION="22" setup_nodejs`: Node.js install — framework helper, avoids GPG bootstrap issues
- `FFMPEG_TYPE="full" setup_ffmpeg`: FFmpeg install — framework helper, most compatible build

### Expected Features

**Must have (table stakes):**
- `ct/openMontage.sh` with all `var_*` defaults using `${var:-default}` form — framework contract, PR rejected without it
- `install/openMontage-install.sh` with mandatory boilerplate top/bottom sequences — every install script requires this
- Python 3.10+, Node.js 18+, FFmpeg, git installed in-container — hard OpenMontage runtime deps
- Git clone of OpenMontage + `pip install -r requirements.txt` + `npm install` — the actual application install
- `.env` copied from `.env.example` (guarded — only if not already present) — app won't start without it
- `update_script()` in ct/ script with `.env` preservation — hard PR requirement, not optional
- `msg_info`/`msg_ok` wrapping on every install step — community-scripts standard output

**Should have (differentiators):**
- `var_gpu="yes"` in ct/ script — exposes GPU passthrough option in advanced mode without forcing it
- Optional `FAL_KEY` prompt during install — single highest-value API key, makes install immediately production-capable
- `var_tags="media;ai"` — improves discoverability on community-scripts.org
- Version stored to `/opt/OpenMontage_version.txt` post-install — required for meaningful update detection

**Defer (v2+):**
- Systemd service unit — OpenMontage is invoked per-task by agents, not a daemon; no server mode today
- Prompting for additional API keys (ElevenLabs, Suno, HeyGen, etc.) — adds friction, diminishing returns
- GPU driver automation — requires host-side Proxmox config, out of LXC installer scope
- Local video model download — multi-GB downloads, GPU required, manual post-install step

### Architecture Approach

Two execution contexts connected by `lxc-attach`. The ct/ script runs on the Proxmox host, sets variables, and calls three framework functions (`start`, `build_container`, `description`). `build_container` creates the container, fetches `install.func` content as a string, exports it as `$FUNCTIONS_FILE_PATH`, and runs the install script inside the container via `lxc-attach`. The install script has no access to the host filesystem — everything must be downloaded from the internet or injected via env vars.

**Major components:**
1. `ct/openMontage.sh` — Host orchestrator; declares defaults, routes install vs update via `update_script()`
2. `install/openMontage-install.sh` — In-container installer; all application-specific logic lives here
3. `ct/headers/openMontage` — ASCII art header; zero dependencies, display only
4. Framework (`build.func`, `install.func`) — Consumed, not owned; fetched at runtime from official CDN

### Critical Pitfalls

1. **Missing `update_script()`** — Hard PR blocker. Write the update contract (git pull + pip install + npm install, never touch `.env`) before writing install logic. Store version as git SHA in `/opt/OpenMontage_version.txt`.

2. **Debian 12 PEP 668 blocks pip** — `pip3 install` aborts with `externally-managed-environment`. Use `setup_uv` (framework helper) or a venv. Never use `--break-system-packages` — maintainer red flag.

3. **ShellCheck failures block merge** — CI runs ShellCheck on all scripts. Quote all variables, use `[[ ]]` not `[ ]`, prefix all commands with `$STD`. Run ShellCheck locally before opening any PR.

4. **Update function overwrites `.env`** — User loses API keys on every update. Guard all config writes: `[[ ! -f /opt/openMontage/.env ]] && cp .env.example .env`. Back up `.env` before `git pull`.

5. **Default 8GB disk too small** — Full stack (Debian base + Python venv + Node/Remotion + FFmpeg + source) exceeds 8GB. Set `var_disk="${var_disk:-12}"` as the minimum default.

## Implications for Roadmap

### Phase 1: Script Scaffold and Install Core
**Rationale:** The install script can be developed and tested independently on any Debian 12 container before touching Proxmox. Getting framework boilerplate, naming conventions, and dependency install correct first prevents rework. ShellCheck compliance and `update_script()` must be designed from day one.
**Delivers:** Working `install/openMontage-install.sh` that installs all deps, clones OpenMontage, sets up `.env`, and leaves a functional container. Correct file naming. ShellCheck passing.
**Addresses:** All table-stakes features
**Avoids:** Pitfalls 1 (missing update function design), 2 (PEP 668), 3 (Node.js GPG), 6 (ShellCheck), 7 (.env overwrite), 8 (disk size), 12 (filename conventions), 14 (cleanup_lxc)

### Phase 2: Host Orchestrator and Update Mechanism
**Rationale:** Once the install script is proven, wire it to the ct/ script. The `update_script()` function is complex enough (version detection, `.env` preservation, rate-limit-resilient checks) to deserve its own phase.
**Delivers:** `ct/openMontage.sh` with proper defaults, `update_script()` with `.env` preservation and `git ls-remote` version detection, tested end-to-end on Proxmox.
**Avoids:** Pitfalls 1 (update function), 7 (.env overwrite), 10 (GitHub API rate limiting)

### Phase 3: Polish and PR Submission
**Rationale:** After functional testing, focus on PR acceptance requirements: ASCII header, `var_gpu` option with documentation, `FAL_KEY` prompt, tags, final ShellCheck run, PR checklist.
**Delivers:** PR-ready submission to community-scripts/ProxmoxVE. ASCII header. Optional FAL_KEY prompt. GPU passthrough warning documentation.
**Avoids:** Pitfalls 4 (NVIDIA driver mismatch), 11 (GPU/VM passthrough conflict), 15 (telemetry calls)

### Phase Ordering Rationale

- Install script first because it can be tested without a full Proxmox environment — faster iteration
- Update function in Phase 2 (not Phase 1) because it requires understanding what "installed" means — must see the install script complete first
- GPU left to Phase 3 because it's optional and the conflict with VM passthrough (Pitfall 11) requires careful documentation rather than automation

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (update function):** Version detection strategy (git SHA vs tags vs GitHub releases) needs validation against actual OpenMontage release cadence
- **Phase 3 (GPU option):** NVIDIA driver version matching inside LXC is complex — if automated, needs testing against specific host driver versions

Phases with standard patterns (skip research-phase):
- **Phase 1 (install script):** Fully documented with real script examples in the repo. STACK.md contains exact code patterns ready to use.
- **Phase 3 (PR submission):** PR checklist is explicit; ShellCheck is deterministic.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified directly from live community-scripts repo source files and official docs |
| Features | HIGH | Cross-referenced with actual OpenMontage repo and 400+ reference scripts |
| Architecture | HIGH | Verified from build.func source (5995 lines) and multiple real script examples |
| Pitfalls | MEDIUM | community-scripts wiki + forum threads verified; GPU pitfalls from official Proxmox forum |

**Overall confidence:** HIGH

### Gaps to Address

- **FFmpeg version requirement**: Debian 12 apt provides FFmpeg 5.1.x. Verify against actual OpenMontage usage before writing install code — if 6.x needed, use static binary from johnvansickle.com.
- **OpenMontage .env.example completeness**: The FAL_KEY prompt assumes `.env.example` documents this key. Verify against the repo before writing install code.
- **Piper TTS model download timing**: Piper downloads ~50MB model on first run, not at install time. Document in post-install notes to avoid user confusion.
- **`setup_uv` vs manual venv**: Both are valid. Prefer `setup_uv` (framework helper, cleaner) and be consistent throughout.

## Sources

### Primary (HIGH confidence)
- community-scripts/ProxmoxVE — build.func, install.func, ct/jellyfin.sh, ct/node-red.sh, install/jellyfin-install.sh, install/node-red-install.sh
- calesthio/OpenMontage — README, Makefile, requirements.txt, .env.example, package.json
- community-scripts/ProxmoxVE wiki — tools.func docs, CONTRIBUTING guide, api.func docs

### Secondary (MEDIUM confidence)
- Proxmox wiki: Unprivileged LXC containers — UID/GID mapping behavior
- Proxmox forum threads — GPU passthrough to LXC, FFmpeg hardware acceleration in LXC
- GitHub issues — NodeSource GPG fix (#1688), PatchMon update bug (#12884), runc AppArmor issue (#4972)

### Tertiary (LOW confidence)
- Jeff Geerling blog — PEP 668 pip fix (corroborates primary sources)

---
*Research completed: 2026-04-07*
*Ready for roadmap: yes*
