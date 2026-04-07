# Requirements: OpenMontage Proxmox Installer

**Defined:** 2026-04-07
**Core Value:** One-command install of OpenMontage on Proxmox — from bare hypervisor to working video production pipeline in minutes.

## v1 Requirements

### Container Creation

- [ ] **CT-01**: Script creates Debian 12 LXC with defaults (2 CPU, 2GB RAM, 12GB disk)
- [ ] **CT-02**: Advanced mode allows custom CPU, RAM, disk, hostname, and network settings
- [ ] **CT-03**: User can optionally enable GPU passthrough during advanced setup
- [ ] **CT-04**: Script uses `build.func` framework for container creation

### Application Install

- [x] **INST-01**: Python 3.10+ installed via `setup_uv` (PEP 668 safe)
- [x] **INST-02**: Node.js 18+ installed via `setup_nodejs`
- [x] **INST-03**: FFmpeg installed via `setup_ffmpeg`
- [x] **INST-04**: OpenMontage cloned from GitHub to `/opt/openmontage`
- [x] **INST-05**: Python dependencies installed (requirements.txt + piper-tts)
- [x] **INST-06**: Node dependencies installed (remotion-composer/)
- [x] **INST-07**: `.env` created from `.env.example`
- [x] **INST-08**: Optional FAL_KEY prompt during install

### Update Mechanism

- [ ] **UPD-01**: `update_script()` detects current vs upstream version
- [ ] **UPD-02**: Git pull fetches latest OpenMontage code
- [ ] **UPD-03**: Dependencies re-installed after pull (pip + npm)
- [ ] **UPD-04**: `.env` file preserved across updates

### PR Compatibility

- [ ] **PR-01**: All commands use `$STD` prefix for output control
- [ ] **PR-02**: Progress messages use `msg_info`/`msg_ok`/`msg_error`
- [ ] **PR-03**: Install script uses `motd_ssh` + `customize` + `cleanup_lxc` closing sequence
- [ ] **PR-04**: Scripts pass ShellCheck with zero warnings

## v2 Requirements

### Enhanced Install

- **EINST-01**: Multiple API key prompts during install (ElevenLabs, OpenAI, etc.)
- **EINST-02**: Post-install health check verifying all components work
- **EINST-03**: Systemd service for scheduled video production jobs

### Community

- **COMM-01**: JSON metadata entry for community-scripts website
- **COMM-02**: ASCII art header for container MOTD

## Out of Scope

| Feature | Reason |
|---------|--------|
| VM creation | LXC is lighter; GPU passthrough in LXC covers most use cases |
| Automatic GPU driver install | Requires host-side Proxmox configuration outside LXC scope |
| All 16 API key prompts | Too much friction during install; users edit `.env` post-install |
| Web UI for management | OpenMontage is agent-driven, no server mode |
| Multi-node deployment | Single Proxmox host only for v1 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INST-01 | Phase 1 | Complete |
| INST-02 | Phase 1 | Complete |
| INST-03 | Phase 1 | Complete |
| INST-04 | Phase 1 | Complete |
| INST-05 | Phase 1 | Complete |
| INST-06 | Phase 1 | Complete |
| INST-07 | Phase 1 | Complete |
| INST-08 | Phase 1 | Complete |
| CT-01 | Phase 2 | Pending |
| CT-02 | Phase 2 | Pending |
| CT-03 | Phase 2 | Pending |
| CT-04 | Phase 2 | Pending |
| UPD-01 | Phase 2 | Pending |
| UPD-02 | Phase 2 | Pending |
| UPD-03 | Phase 2 | Pending |
| UPD-04 | Phase 2 | Pending |
| PR-01 | Phase 3 | Pending |
| PR-02 | Phase 3 | Pending |
| PR-03 | Phase 3 | Pending |
| PR-04 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-07*
*Last updated: 2026-04-07 after roadmap creation*
