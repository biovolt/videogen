---
phase: 03-pr-polish
plan: "01"
subsystem: installer-scripts
tags:
  - shellcheck
  - pr-polish
  - community-scripts
dependency_graph:
  requires: []
  provides:
    - PR-01
    - PR-02
    - PR-03
    - PR-04
  affects:
    - ct/openMontage.sh
    - install/openMontage-install.sh
tech_stack:
  added: []
  patterns:
    - "git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD for version normalization"
    - "shellcheck disable=SC1090 for dynamic source directives"
key_files:
  modified:
    - ct/openMontage.sh
    - install/openMontage-install.sh
decisions:
  - "Use grouped brace { cmd1 || cmd2; } >file redirect instead of echo $(...) to satisfy SC2005"
  - "Version tracking uses git describe --tags --exact-match with short SHA fallback in both scripts — prevents spurious re-updates when API returns tag but install stored SHA"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-08"
  tasks_completed: 2
  files_modified: 2
---

# Phase 03 Plan 01: PR Polish — Review Warnings and ShellCheck Summary

**One-liner:** Resolved all 5 Phase 2 review warnings and SC1090 ShellCheck warning across both scripts, with consistent version-format normalization using `git describe --tags --exact-match` with short SHA fallback.

## What Was Built

Both `ct/openMontage.sh` and `install/openMontage-install.sh` are now fully PR-ready for community-scripts/ProxmoxVE submission. Zero ShellCheck warnings. All checklist items pass.

## Tasks Completed

### Task 1: Fix ct/openMontage.sh (commit b6f86b4)

Seven targeted fixes applied:

| Fix | Issue | Change |
|-----|-------|--------|
| IN-01 | Copyright header after source line | Reordered: copyright → SC1090 directive → source |
| SC1090 | ShellCheck can't follow dynamic source | Added `# shellcheck disable=SC1090` before source |
| WR-01a | Bare `exit` on error path | Changed to `exit 1` |
| WR-01b | Bare `exit` at end of update_script | Changed to `exit 0` |
| WR-02 | No checkout after git pull | Added `git -C /opt/openmontage checkout "${RELEASE}"` |
| WR-03 | Relative requirements.txt path | Changed to `/opt/openmontage/requirements.txt` |
| VERSION | Raw RELEASE written to version.txt | Normalized with `{ git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD; }` |

### Task 2: Fix install/openMontage-install.sh (commit 24bb827)

Three targeted fixes applied:

| Fix | Issue | Change |
|-----|-------|--------|
| WR-04 | System `python3` used instead of venv | Changed to `/opt/openmontage/.venv/bin/python3` |
| WR-02 | No checkout after clone | Added `git -C /opt/openmontage checkout "${RELEASE}"` guarded by `-n "${RELEASE}"` check |
| VERSION | Raw RELEASE written to version.txt | Normalized with `{ git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD; }` after checkout |

PR checklist verified — all items pass:

- [x] Shebang `#!/usr/bin/env bash` — both files
- [x] build.func from official URL — ct/ script
- [x] Copyright header — both files
- [x] Author line — both files
- [x] License line — both files
- [x] Source line — both files
- [x] All `var_*` use `${var_name:-default}` form — ct/ script
- [x] All commands prefixed with `$STD` — install script
- [x] `motd_ssh`, `customize`, `cleanup_lxc` closing sequence — install script
- [x] Version saved to `/opt/${APP}_version.txt` — install script
- [x] `update_script()` implemented — ct/ script

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] SC2005: echo $(...) replaced with brace-grouped redirect**
- **Found during:** Task 1 verification (ShellCheck run after initial write)
- **Issue:** `echo "$(git describe ... || git rev-parse ...)"` triggers SC2005 "Useless echo? Instead of 'echo $(cmd)', just use 'cmd'". Initial fix `cmd1 || cmd2 >file` was also wrong — redirect only applied to `cmd2`.
- **Fix:** Used `{ cmd1 || cmd2; } >file` to correctly redirect the full `||` expression output to the version file
- **Files modified:** `ct/openMontage.sh` (line 57), `install/openMontage-install.sh` (line 41)
- **Commit:** Included in b6f86b4 and 24bb827

## Known Stubs

None — both scripts wire real data sources. Version tracking reads from live git state.

## Self-Check: PASSED

- [x] `ct/openMontage.sh` exists and modified
- [x] `install/openMontage-install.sh` exists and modified
- [x] Commit b6f86b4 exists
- [x] Commit 24bb827 exists
- [x] ShellCheck passes on both files with zero warnings
- [x] All PR checklist items verified passing
