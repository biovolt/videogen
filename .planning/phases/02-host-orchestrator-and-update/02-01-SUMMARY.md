---
phase: 02-host-orchestrator-and-update
plan: 01
subsystem: infra
tags: [bash, proxmox, community-scripts, build.func, lxc, shellcheck]

# Dependency graph
requires:
  - phase: 01-install-script
    provides: install/openMontage-install.sh with motd_ssh/customize/cleanup_lxc footer and version tracking
provides:
  - ct/openMontage.sh: canonical community-scripts host orchestrator with working update mechanism
  - install/openMontage-install.sh: cleaned of dead .install_env sourcing
affects:
  - PR submission to community-scripts/ProxmoxVE

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ct/ script sources build.func with -fsSL on line 1 (before copyright header)"
    - "var_* variables use ${var_name:-default} form for override compatibility"
    - "update_script() ends with exit to prevent fall-through to build_container"
    - "$STD prefix on all output-producing commands in update_script"
    - "msg_info/msg_ok pairs wrap each logical step in update_script"

key-files:
  created: []
  modified:
    - ct/openMontage.sh
    - install/openMontage-install.sh

key-decisions:
  - "Removed install_script() override from ct/ script — build.func's install_script() handles the full container creation flow; local override breaks pve_check, whiptail menus, and advanced settings"
  - "Removed pct exec API key injection — build_container() runs install script before returning, making pct exec a timing no-op; users edit .env post-install"
  - "Added empty RELEASE guard in update_script to prevent always-update behavior if GitHub releases API returns nothing (A1 assumption mitigation)"

patterns-established:
  - "No local install_script() in ct/ scripts — ever"
  - "No host-to-container env injection via pct exec after build_container"

requirements-completed: [CT-01, CT-02, CT-03, CT-04, UPD-01, UPD-02, UPD-03, UPD-04]

# Metrics
duration: 2min
completed: 2026-04-08
---

# Phase 02 Plan 01: Host Orchestrator and Update Summary

**Canonical community-scripts ct/ script with var_disk=12, var_gpu=no, working update_script, and removal of broken install_script override and pct exec API key injection**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-08T16:17:46Z
- **Completed:** 2026-04-08T16:19:21Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Rewrote ct/openMontage.sh to canonical community-scripts pattern — container creation flow now works correctly via build.func's install_script()
- Fixed var_disk to 12 GB and added var_gpu=no for GPU passthrough dialog in advanced mode
- Completed update_script() with $STD prefix on git pull, msg_info/msg_ok wrappers, and empty RELEASE guard
- Removed dead .install_env sourcing from install script and updated stale comment

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite ct/openMontage.sh to canonical pattern** - `244b365` (feat)
2. **Task 2: Clean up install script dead code** - `2bb697e` (chore)

## Files Created/Modified

- `ct/openMontage.sh` - Rewritten to canonical community-scripts pattern; all 8 requirements satisfied
- `install/openMontage-install.sh` - Removed .install_env sourcing, updated stale comment

## Decisions Made

- Removed install_script() override — build.func's version handles the full creation flow; the local override was silently suppressing pve_check, whiptail menus, and advanced settings dialogs
- Removed pct exec injection — the timing is wrong (install script already ran inside build_container before pct exec runs); standard approach is users edit .env post-install
- Added empty RELEASE guard — if calesthio/OpenMontage has no GitHub releases the API returns empty string, which would cause the version compare to always trigger an update

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- shellcheck reports SC1090 on the `source <(curl -fsSL ...)` line — this is expected and acceptable for all community-scripts ct/ scripts; the canonical scripts all have this warning. ShellCheck exits 0 on install script (no warnings).

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced beyond what the plan's threat model covers.

## Known Stubs

None — both scripts are fully functional with no hardcoded placeholders.

## Next Phase Readiness

- Both scripts are PR-ready (ShellCheck passes, canonical patterns followed, all requirements met)
- Phase 03 (if any) can proceed — the installer and orchestrator are complete
- Open question from research (A1): calesthio/OpenMontage may not have GitHub releases yet; the empty RELEASE guard in update_script mitigates this

---
*Phase: 02-host-orchestrator-and-update*
*Completed: 2026-04-08*
