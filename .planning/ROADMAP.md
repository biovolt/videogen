# Roadmap: OpenMontage Proxmox Installer

## Overview

Three phases deliver a PR-ready community-scripts installer. Phase 1 builds the in-container install script — testable on any Debian 12 box before touching Proxmox. Phase 2 wires the host orchestrator, container defaults, and update mechanism. Phase 3 applies the PR acceptance requirements and submits upstream.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Install Script** - In-container installer: all deps, OpenMontage clone, .env setup (completed 2026-04-07)
- [x] **Phase 2: Host Orchestrator and Update** - ct/ script with defaults, container creation, update_script() (completed 2026-04-08)
- [ ] **Phase 3: PR Polish** - ShellCheck, output conventions, ASCII header, PR submission

## Phase Details

### Phase 1: Install Script
**Goal**: A working install/openMontage-install.sh that installs all dependencies and leaves a functional OpenMontage container
**Depends on**: Nothing (first phase)
**Requirements**: INST-01, INST-02, INST-03, INST-04, INST-05, INST-06, INST-07, INST-08
**Success Criteria** (what must be TRUE):
  1. Running the install script on a fresh Debian 12 container completes without errors
  2. Python 3.10+, Node.js 18+, FFmpeg, and git are available inside the container after install
  3. OpenMontage is cloned to /opt/openmontage and all Python and Node dependencies are installed
  4. A .env file exists at /opt/openmontage/.env (created from .env.example, not overwriting an existing one)
  5. The FAL_KEY prompt appears during install and the supplied value is written to .env
**Plans**: 1 plan

Plans:
- [x] 01-01-PLAN.md -- Complete install script with all deps, .env setup, and API key prompts

### Phase 2: Host Orchestrator and Update
**Goal**: A working ct/openMontage.sh that creates the LXC container with correct defaults and provides a safe update_script() that preserves .env
**Depends on**: Phase 1
**Requirements**: CT-01, CT-02, CT-03, CT-04, UPD-01, UPD-02, UPD-03, UPD-04
**Success Criteria** (what must be TRUE):
  1. Running the ct/ script on Proxmox creates a Debian 12 LXC with 2 CPU, 2GB RAM, 12GB disk by default
  2. Advanced mode lets the user override CPU, RAM, disk, hostname, and network before container creation
  3. GPU passthrough option is exposed in advanced mode and defaults to off
  4. Running the update option detects whether a newer version is available before pulling
  5. After update, .env is unchanged and all dependencies reflect the new version
**Plans**: 1 plan

Plans:
- [x] 02-01-PLAN.md -- Rewrite ct/ script to canonical pattern, fix defaults, complete update_script, clean up install script dead code

### Phase 3: PR Polish
**Goal**: Scripts pass all community-scripts PR requirements and are submitted upstream
**Depends on**: Phase 2
**Requirements**: PR-01, PR-02, PR-03, PR-04
**Success Criteria** (what must be TRUE):
  1. ShellCheck reports zero warnings on both scripts
  2. Every install step is wrapped with msg_info / msg_ok / msg_error output
  3. The install script closes with motd_ssh, customize, and cleanup_lxc in the correct order
  4. All commands in the install script use the $STD prefix for output control
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Install Script | 1/1 | Complete   | 2026-04-07 |
| 2. Host Orchestrator and Update | 1/1 | Complete   | 2026-04-08 |
| 3. PR Polish | 0/? | Not started | - |
