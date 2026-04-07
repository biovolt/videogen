---
phase: 01-install-script
fixed_at: 2026-04-07T00:00:00Z
review_path: .planning/phases/01-install-script/01-REVIEW.md
iteration: 2
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 01: Code Review Fix Report

**Fixed at:** 2026-04-07
**Source review:** .planning/phases/01-install-script/01-REVIEW.md
**Iteration:** 2

**Summary:**
- Findings in scope: 6 (CR-01, CR-02, WR-01, WR-02, WR-03, WR-04)
- Fixed: 6
- Skipped: 0

## Fixed Issues

### CR-01: API keys exported on host are not forwarded into the LXC container

**Files modified:** `ct/openMontage.sh`, `install/openMontage-install.sh`
**Commit:** 60493f0
**Applied fix:** Removed `export` calls from `install_script()`. After `build_container`, added a `pct exec` call that writes the three API key values to `/root/.install_env` inside the container. In the install script, added `[[ -f /root/.install_env ]] && source /root/.install_env` immediately after `catch_errors` so the keys are available to the Python env-config block.

---

### CR-02: `re.sub` replacement is not escaped — API keys with `&` or `\` are silently corrupted

**Files modified:** `install/openMontage-install.sh`
**Commit:** 53fdf1c
**Applied fix:** Replaced the bare `re.sub(pattern, string_replacement, ...)` calls with `re.sub(pattern, lambda m, r=replacement: r, ...)` to bypass template expansion entirely. The `else` branch (comment-out path) is safe as-is (no user data in replacement) and was left as a plain string. Also converted both `open()` calls to `with` context managers (addresses WR-04 simultaneously).

---

### WR-01: `update_script()` missing `$STD` prefix on `uv pip install` and `npm install`

**Files modified:** `ct/openMontage.sh`
**Commit:** cd7a625
**Applied fix:** Prefixed both `uv pip install` and `npm install` lines inside `update_script()` with `$STD`.

---

### WR-02: `update_script()` `cd` has no error handling

**Files modified:** `ct/openMontage.sh`
**Commit:** 1bf3f2d
**Applied fix:** Added `|| { msg_error "..."; exit 1; }` guards to both `cd` calls inside `update_script()`.

---

### WR-03: Version string format mismatch causes perpetual false-update detection

**Files modified:** `install/openMontage-install.sh`
**Commit:** 27dc33b
**Applied fix:** Replaced `git describe --tags --always` with the same GitHub Releases API query used by `update_script()`. Kept the existing `git rev-parse --short HEAD` as a fallback for when no releases have been published yet.

---

### WR-04: Python inline script opens files without `with` — write failure leaves `.env` truncated

**Files modified:** `install/openMontage-install.sh`
**Commit:** 53fdf1c (fixed together with CR-02)
**Applied fix:** Both `open()` calls converted to `with` context managers as part of the CR-02 fix. The read and write are now properly resource-managed.

---

_Fixed: 2026-04-07_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
