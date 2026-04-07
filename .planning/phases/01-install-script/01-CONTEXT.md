# Phase 1: Install Script - Context

**Gathered:** 2026-04-07
**Status:** Ready for planning

<domain>
## Phase Boundary

In-container install script (`install/openMontage-install.sh`) that installs all dependencies on a fresh Debian 12 container and leaves a functional OpenMontage instance at `/opt/openmontage`.

</domain>

<decisions>
## Implementation Decisions

### API Key Prompt Flow
- **D-01:** Prompt for three API keys during install: FAL_KEY, ELEVENLABS_API_KEY, OPENAI_API_KEY
- **D-02:** All three prompts accept empty input (skip silently) — no re-prompting
- **D-03:** When a key is provided, write it to `.env` as `KEY=value`
- **D-04:** When a key is skipped (empty Enter), write a **commented-out placeholder** like `# FAL_KEY=your-key-here` so users can find and uncomment it later

### Install Order
- **D-05:** System dependencies first: Python (setup_uv) -> Node.js (setup_nodejs) -> FFmpeg (setup_ffmpeg) -> git clone OpenMontage -> pip install -> npm install -> .env setup
- **D-06:** All system tools are installed before application code is cloned or configured

### Progress Messaging
- **D-07:** One msg_info/msg_ok pair per major step (~8 pairs total). No sub-step messages.
- **D-08:** Major steps: Python, Node.js, FFmpeg, git clone, Python deps, Node deps, .env setup, final completion

### Claude's Discretion
- Version tracking method (git tag vs commit hash for `/opt/OpenMontage_version.txt`) — Claude picks based on community-scripts conventions
- Piper TTS handling — deferred to first run (not installed at install time, per STATE.md note)
- Python version number (3.11 or 3.12 — whichever setup_uv defaults to or is most stable)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Community-Scripts Framework
- `CLAUDE.md` — Full structure for ct/ and install/ scripts, framework functions, anti-patterns, PR checklist
- [community-scripts/ProxmoxVE misc/build.func](https://github.com/community-scripts/ProxmoxVE/blob/main/misc/build.func) — Framework source
- [tools.func wiki](https://github.com/community-scripts/ProxmoxVE/wiki/tools.func) — setup_nodejs, setup_uv, setup_ffmpeg docs

### Reference Install Scripts
- [install/jellyfin-install.sh](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/jellyfin-install.sh) — Verified install boilerplate
- [install/node-red-install.sh](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/node-red-install.sh) — Verified install with nodejs
- [install/gitea-install.sh](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/gitea-install.sh) — Verified install with fetch_and_deploy_gh_release

### OpenMontage
- [OpenMontage repo](https://github.com/calesthio/OpenMontage) — Source repo to clone; check `.env.example` for key names and `requirements.txt` for Python deps

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- No existing code in this repo yet — greenfield

### Established Patterns
- Community-scripts framework provides: `$STD` prefix, `msg_info`/`msg_ok`/`msg_error`, `catch_errors`, `motd_ssh`/`customize`/`cleanup_lxc`
- CLAUDE.md documents the full install script structure and anti-patterns to avoid

### Integration Points
- Script will be called by ct/openMontage.sh (Phase 2) via `$FUNCTIONS_FILE_PATH`
- Version file at `/opt/OpenMontage_version.txt` feeds into `update_script()` (Phase 2)

</code_context>

<specifics>
## Specific Ideas

- Commented-out placeholders for skipped keys (e.g., `# FAL_KEY=your-key-here`) so they're visible but inactive
- Three API key prompts keeps friction low while covering the most common premium providers

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-install-script*
*Context gathered: 2026-04-07*
