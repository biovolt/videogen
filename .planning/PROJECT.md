# OpenMontage Proxmox Installer

## What This Is

A Proxmox VE community-script-compatible installer that creates an LXC container with OpenMontage (an agentic video production system) fully installed and configured. Follows the exact community-scripts pattern (`ct/` + `install/` structure, uses `build.func`) so it can be submitted as a PR to the community-scripts/ProxmoxVE repository.

## Core Value

One-command install of OpenMontage on Proxmox — from bare hypervisor to working video production pipeline in minutes.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] LXC container creation with sane defaults (2 CPU, 2GB RAM, 8GB disk)
- [ ] Advanced mode for custom container settings
- [ ] Optional GPU passthrough selection during install
- [ ] OpenMontage install inside container (git clone, Python deps, Node deps, Piper TTS)
- [ ] `.env` file setup with optional API key prompts
- [ ] Update mechanism (git pull + dependency re-install, preserving `.env`)
- [ ] Compatible with community-scripts framework (`build.func`, `create_lxc.sh`)
- [ ] Debian 12 base template

### Out of Scope

- VM creation — LXC only for v1
- Automatic API key provisioning — user supplies their own keys
- Web UI for management — CLI/script only
- Remotion cloud rendering setup — local rendering only
- Multi-node cluster deployment — single Proxmox host

## Context

- **OpenMontage** (github.com/calesthio/OpenMontage): Agent-first video production system. Python 3.10+ backend, Node.js 18+ Remotion compositor, FFmpeg for encoding. Works zero-key with Piper TTS + free stock media, or with API keys for premium providers (fal.ai, ElevenLabs, etc.).
- **Community-scripts** (community-scripts.org): 400+ Proxmox helper scripts. Two-layer pattern: `ct/<app>.sh` orchestrates container creation via shared `build.func`; `install/<app>-install.sh` runs inside the container.
- **Target users**: Proxmox homelab users who want to run OpenMontage without manually setting up Python, Node, FFmpeg, etc.

## Constraints

- **Framework**: Must use community-scripts `build.func` and `create_lxc.sh` patterns — required for PR compatibility
- **Base OS**: Debian 12 (standard for community-scripts)
- **Dependencies**: Python 3.10+, Node.js 18+, FFmpeg, git — all must be installed in-container
- **Updates**: Must preserve `.env` and user config when updating

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| LXC over VM | Lighter resource footprint, sufficient for API-only usage | — Pending |
| Debian 12 base | Most common in community-scripts, good compatibility | — Pending |
| Lean defaults (2/2/8) | API-only usage doesn't need much; advanced mode for more | — Pending |
| GPU passthrough optional | Let user choose — most will use cloud APIs | — Pending |
| Compatible with community-scripts PR | Enables upstream contribution, follows established patterns | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-07 after initialization*
