# Phase 3: PR Polish - Context

**Gathered:** 2026-04-08
**Status:** Ready for planning
**Mode:** Infrastructure phase — discuss skipped

<domain>
## Phase Boundary

Ensure both scripts (`ct/openMontage.sh` and `install/openMontage-install.sh`) pass all community-scripts PR requirements: ShellCheck zero warnings, consistent msg_info/msg_ok/msg_error wrapping, correct closing sequence, $STD prefix on all commands, and address code review findings from Phases 1 and 2.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure/compliance phase. Use ROADMAP phase goal, success criteria, PR checklist from CLAUDE.md, and code review findings from prior phases to guide decisions.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Community-Scripts PR Requirements
- `CLAUDE.md` — PR Submission Checklist (comprehensive), anti-patterns, output conventions
- [community-scripts CONTRIBUTING wiki](https://github.com/community-scripts/ProxmoxVE/wiki/CONTRIBUTING) — Contribution guidelines

### Prior Phase Reviews
- `.planning/phases/01-install-script/01-REVIEW.md` — Phase 1 code review findings (some may persist)
- `.planning/phases/02-host-orchestrator-and-update/02-REVIEW.md` — Phase 2 code review findings (4 warnings)

</canonical_refs>

<code_context>
## Existing Code Insights

### Files to Polish
- `ct/openMontage.sh` — 70 lines, canonical pattern, 4 warnings from Phase 2 review
- `install/openMontage-install.sh` — ~100 lines, framework-compliant, ShellCheck clean

### Known Issues from Code Reviews
- WR-01: `exit` with no argument in ct/ (should be `exit 1`)
- WR-02: Version tracking inconsistency (install vs update)
- WR-03: Relative path fragility in ct/
- WR-04: System python3 vs uv-managed interpreter
- IN-01: Copyright header placement after source line

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-pr-polish*
*Context gathered: 2026-04-08*
