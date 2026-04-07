# Feature Landscape: Proxmox Community-Script Installer for OpenMontage

**Domain:** Proxmox VE LXC container installer script
**Researched:** 2026-04-07
**Sources:** community-scripts/ProxmoxVE (frigate, n8n, ollama scripts + build.func/install.func), calesthio/OpenMontage (README, Makefile, requirements.txt, .env.example, package.json)

---

## Table Stakes

Features that must be present. Missing any of these means the script is broken or will be rejected by community-scripts maintainers.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| `ct/openmontage.sh` — sets `var_cpu`, `var_ram`, `var_disk`, `var_os`, `var_version`, `var_unprivileged`, `var_tags` | Framework contract — `build.func` reads these variables to build the container | Low | Defaults: 2 CPU, 2048 MB RAM, 8 GB disk, Debian 12, unprivileged=1, tags="media" |
| Sources `build.func` via curl | All community-scripts ct/ scripts do this — it provides `start`, `build_container`, `description`, `variables`, `color`, `catch_errors` | Low | URL pattern: `https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func` |
| `install/openmontage-install.sh` — separate from ct/ script | Framework two-layer pattern: ct/ orchestrates, install/ runs inside container | Low | Must match filename convention exactly |
| Sources `install.func` inside install script | Provides `color`, `verb_ip6`, `catch_errors`, `setting_up_container`, `network_check`, `update_os`, `motd_ssh`, `customize`, `cleanup_lxc` | Low | All install scripts use this |
| `setting_up_container` + `network_check` + `update_os` called at install script top | Standard boilerplate — sets up network, updates apt | Low | Every install script does this before anything else |
| Install Python 3.10+ | OpenMontage runtime requirement. Python 3.11 ships with Debian 12, satisfies >=3.10 | Low | `apt install -y python3 python3-pip python3-venv` |
| Install Node.js 18+ | Remotion compositor requirement. Community-scripts provides `setup_nodejs` helper | Low | Call `NODE_VERSION="20" setup_nodejs` — use LTS 20, not 18, for longevity |
| Install FFmpeg | Hard dependency — Remotion uses it for encoding, OpenMontage uses it directly | Low | `apt install -y ffmpeg` |
| Install git | Required for `git clone` during install and for the update mechanism | Low | `apt install -y git` |
| Git clone OpenMontage into `/opt/openmontage` | The application install itself | Low | `git clone https://github.com/calesthio/OpenMontage.git /opt/openmontage` |
| `pip install -r requirements.txt` | Installs PyYAML >=6.0, Pydantic >=2.0, jsonschema >=4.20, python-dotenv >=1.0 | Low | Run inside /opt/openmontage |
| `npm install` inside `remotion-composer/` | Installs Remotion 4.x, React 18, and compositor dependencies | Low | Run inside /opt/openmontage/remotion-composer |
| Install Piper TTS | Required for zero-key TTS. OpenMontage's `make setup` does `pip install piper-tts` | Low | `pip install piper-tts` — downloads ~50 MB model on first run |
| Copy `.env.example` to `.env` | Application won't start without a `.env` file present | Low | `cp .env.example .env` — preserving this on updates is critical |
| `motd_ssh` + `customize` + `cleanup_lxc` called at end of install script | Required boilerplate — sets MOTD, configures SSH, cleans up build artifacts | Low | All install scripts end with these three calls |
| `update_script()` function in ct/ script | Required for the community-scripts update mechanism to work | Medium | Must do git pull + pip install + npm install, must preserve .env |
| `msg_info` / `msg_ok` / `msg_error` for all steps | Community-scripts standard — colored progress output. Sourced from `core.func` | Low | Every step should be wrapped in msg_info/msg_ok pair |
| Privilege level: unprivileged=1 | Security standard. Frigate uses privileged=0 only because it needs raw USB/GPU device access. OpenMontage is API-only, so unprivileged is correct | Low | Override to 0 only if GPU passthrough requires it |

---

## Differentiators

Features that go beyond the bare minimum. Not required for the script to function, but they meaningfully improve the user experience or position the script well for community-scripts acceptance.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Advanced mode defaults bump (4 CPU, 4 GB RAM, 20 GB disk) | Power users doing local rendering need more resources. Simple mode stays lean for API-only use | Low | Advanced mode is handled by `build.func`'s `advanced_settings()` — just set sensible `var_*` defaults |
| `var_gpu="yes"` with hardware acceleration hint | Signals to the framework that GPU passthrough is an option. Useful for users who want local video generation (`VIDEO_GEN_LOCAL_ENABLED=true`) | Medium | Frigate and Ollama both use this. LXC GPU passthrough requires host-side config — script documents it but can't do it automatically |
| Prompt for `FAL_KEY` during install | `FAL_KEY` unlocks 5 major tools (image gen, video gen). Single most valuable API key. With just this key OpenMontage goes from demo-only to production-capable | Medium | Ask y/n: "Enter FAL_KEY for enhanced AI capabilities (optional, press Enter to skip):" — write to .env if provided |
| `update_script()` that preserves `.env` | Without this, every update wipes API keys. Users won't update if it means re-entering all keys | Medium | Backup .env, git pull, restore .env, re-run pip/npm installs |
| Post-install access message with IP | Every community-scripts install script prints the access URL at the end. For OpenMontage, this is less obvious (it's a CLI tool, not a web UI) — print a usage tip instead | Low | Print: "OpenMontage installed at /opt/openmontage — run: cd /opt/openmontage && python3 main.py" |
| Systemd service (optional) | Provides auto-start on boot and a standard way to manage the process. Not required since OpenMontage is invoked by AI agents, not run as a daemon | High | Only add if there's a clear daemon mode in OpenMontage. Currently the app is invoked per-task. Skip for v1. |
| `var_tags="media;ai"` | Makes the script discoverable in community-scripts UI by relevant tags | Low | n8n uses "automation", frigate uses "nvr", ollama uses "ai" — use both "media" and "ai" |

---

## Anti-Features

Features to deliberately not build. Each has a reason.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Prompt for all 16 API keys during install | Creates friction. Most users won't have ElevenLabs, Suno, HeyGen, etc. keys ready at install time. Installer becomes an interrogation | Prompt for FAL_KEY only (highest value/lowest barrier). Document that all other keys can be added to `/opt/openmontage/.env` at any time |
| Systemd daemon service for v1 | OpenMontage is not a server — it's invoked by an AI agent per task. Creating a daemon that runs `python3 main.py` indefinitely would be misleading | Leave service creation out of v1. Re-evaluate after OpenMontage adds a server mode |
| Automatic API key provisioning | Out of scope per PROJECT.md. Keys are user-owned credentials | Document the .env file location and link to OpenMontage's .env.example |
| GPU driver installation | LXC GPU passthrough requires host-side Proxmox configuration (bind-mounting `/dev/dri`, kernel module loading). The container installer cannot do this | Print a post-install note directing users to Proxmox GPU passthrough documentation if they want local rendering |
| Local video model download | Local models (wan2.1, hunyuan, etc.) are multi-gigabyte downloads and require GPU. Default install is CPU/API only | Document `make install-gpu` as a post-install step in the MOTD/notes if user has GPU. Do not auto-download models |
| VM creation | LXC only per PROJECT.md | — |
| Multi-node / cluster deployment | Single host per PROJECT.md | — |
| Web UI for management | Out of scope per PROJECT.md | — |
| Pin to specific OpenMontage version | Pinning breaks the update mechanism. The project moves fast | Always clone HEAD of main. Update mechanism does `git pull` |
| Custom Remotion cloud rendering setup | Out of scope per PROJECT.md | — |

---

## Feature Dependencies

```
Node.js 18+    → npm install (remotion-composer)
Python 3.10+   → pip install requirements.txt
Python 3.10+   → pip install piper-tts
git            → git clone OpenMontage
FFmpeg         → required at runtime (not install-time)
.env.example   → .env (must exist before running)

update_script():
  .env backup  → git pull → .env restore → pip install → npm install
  (order matters — restore BEFORE pip/npm so dotenv loads correctly)

GPU passthrough (host-side, out of script scope):
  → VIDEO_GEN_LOCAL_ENABLED=true in .env
  → make install-gpu (manual post-install step)
```

---

## MVP Recommendation

**Build exactly these for v1:**

1. `ct/openmontage.sh` — standard framework boilerplate, `var_*` defaults (2/2048/8), `var_gpu="yes"`, `var_tags="media;ai"`, `update_script()` with .env preservation
2. `install/openmontage-install.sh` — install all deps (Python, Node 20, FFmpeg, git), clone repo, pip install, npm install, piper-tts, copy .env.example, single optional FAL_KEY prompt, motd_ssh + customize + cleanup_lxc
3. Proper `msg_info`/`msg_ok` wrapping on every step

**Defer these:**
- Systemd service — no clear daemon mode in OpenMontage today
- Prompting for additional API keys beyond FAL_KEY — diminishing returns, add friction
- GPU driver automation — requires host-side work, out of LXC installer scope
