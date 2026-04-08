# Phase 2: Host Orchestrator and Update - Context

**Gathered:** 2026-04-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Host-side orchestrator script (`ct/openMontage.sh`) that creates the LXC container with correct defaults, sources `build.func`, and provides a safe `update_script()` that preserves `.env`.

</domain>

<decisions>
## Implementation Decisions

### Container Defaults
- **D-01:** Default resources: 2 CPU, 2048 MB RAM, 12 GB disk (per CT-01)
- **D-02:** GPU passthrough defaults to off, exposed in advanced mode (per CT-03)
- **D-03:** Base OS: Debian 12, unprivileged container (per community-scripts standard)

### Update Mechanism
- **D-04:** Version detection via GitHub Releases API — compare installed version tag vs latest release
- **D-05:** After update: reinstall both pip and npm deps (ensures new requirements are met)
- **D-06:** No changelog display — keep update simple (pull + reinstall)
- **D-07:** `.env` must be preserved across updates — never overwritten

### Claude's Discretion
- How to structure the three mandatory terminal calls (header_info, base_settings, write_script)
- Exact `var_*` variable format (with `${var_name:-default}` pattern per CLAUDE.md)
- How `install_script()` passes API keys to the container (already partially implemented in Phase 1 fix)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Community-Scripts Framework
- `CLAUDE.md` — Full ct/ script structure, var_* variables, three mandatory terminal calls, update_script() requirements
- [ct/jellyfin.sh](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/jellyfin.sh) — Verified ct/ boilerplate
- [ct/node-red.sh](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/node-red.sh) — Verified ct/ boilerplate with update_script

### Existing Code
- `ct/openMontage.sh` — Already exists (77 lines from Phase 1 code review fixes), needs to be completed with defaults, build.func, and update_script()

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ct/openMontage.sh` already exists with header, `install_script()` function (API key collection + pct exec), and partial `update_script()` skeleton

### Established Patterns
- Phase 1 established: msg_info/msg_ok pairs, $STD prefix, version tracking at `/opt/OpenMontage_version.txt`
- API key collection already moves keys from host to container via `/root/.install_env`

### Integration Points
- `ct/openMontage.sh` calls `install/openMontage-install.sh` inside the container via build.func framework
- Version file at `/opt/OpenMontage_version.txt` is read by `update_script()` for comparison

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard community-scripts approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-host-orchestrator-and-update*
*Context gathered: 2026-04-08*
