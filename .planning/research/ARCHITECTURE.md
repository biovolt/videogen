# Architecture Patterns: Proxmox Community-Scripts

**Domain:** Proxmox VE LXC installer using community-scripts framework
**Researched:** 2026-04-07
**Confidence:** HIGH — verified directly from source code in community-scripts/ProxmoxVE

---

## Recommended Architecture

Two shell scripts per application, running in two separate execution contexts (Proxmox host and LXC container), connected by `lxc-attach`.

```
USER TERMINAL (inside LXC, or Proxmox host shell)
        |
        | curl one-liner: bash -c "$(curl -fsSL .../ct/appname.sh)"
        v
┌─────────────────────────────────────────────────────────┐
│  ct/appname.sh  (runs on Proxmox HOST)                  │
│                                                         │
│  1. source build.func (curl)                            │
│  2. Set APP vars: APP, var_cpu, var_ram, var_disk,      │
│     var_os, var_version, var_unprivileged, var_gpu      │
│  3. header_info / variables / color / catch_errors      │
│  4. define update_script()                              │
│  5. start()          ← dispatch point                   │
│  6. build_container()                                   │
│  7. description()                                       │
└─────────────────────────────────────────────────────────┘
        |
        | lxc-attach -n $CTID -- bash -c "$(curl install/appname-install.sh)"
        v
┌─────────────────────────────────────────────────────────┐
│  install/appname-install.sh  (runs INSIDE LXC)          │
│                                                         │
│  1. source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"        │
│     (install.func content, injected from host)         │
│  2. setting_up_container / network_check / update_os    │
│  3. Install deps (apt)                                  │
│  4. Clone/download application                          │
│  5. Configure application                               │
│  6. motd_ssh / customize / cleanup_lxc                  │
└─────────────────────────────────────────────────────────┘
```

---

## Component Boundaries

| Component | Where It Runs | Responsibility | Communicates With |
|-----------|---------------|----------------|-------------------|
| `ct/appname.sh` | Proxmox host | Declare app defaults, dispatch install vs update | `build.func` (sourced via curl) |
| `misc/build.func` | Proxmox host | Orchestration engine: menus, validation, container creation, install execution | `core.func`, `error_handler.func`, `api.func`, `tools.func` (all sourced) |
| `misc/install.func` | Injected into LXC | In-container utility functions | Sourced at the top of every install script |
| `install/appname-install.sh` | LXC container | Install the actual application | `install.func` (injected via `$FUNCTIONS_FILE_PATH`) |
| `misc/core.func` | Proxmox host | Color codes, message functions (msg_info/ok/error), validation helpers | Sourced by `build.func` |
| `misc/error_handler.func` | Proxmox host | Trap-based error catching, recovery menus | Sourced by `build.func` |
| `misc/api.func` | Proxmox host | Telemetry / progress reporting to PocketBase API | Sourced by `build.func` |
| `ct/headers/appname` | N/A (display only) | ASCII art header for the app shown during install | Read by `header_info()` |
| JSON metadata | N/A (website) | Website display, resources shown on community-scripts.org | Not in repo — submitted via website form |

---

## Data Flow: End-to-End Installation

### Phase 1 — Host Setup (ct/appname.sh)

```
User runs one-liner on Proxmox host
  → bash fetches and executes ct/appname.sh
  → appname.sh sources build.func (curl, ~5000 lines)
  → build.func sources core.func, error_handler.func, api.func
  → APP vars are set (cpu, ram, disk, os, version, gpu flag, etc.)
  → variables() runs: normalises APP name to NSAPP, sets var_install="appname-install",
    generates SESSION_ID, creates BUILD_LOG path
  → start() checks context:
      IF running on Proxmox host → install_script()
      IF running inside LXC      → update_script()
```

### Phase 2 — Interactive Menu (install_script)

```
install_script() validates:
  - pve_check: is this a Proxmox host?
  - root_check: running as root?
  - arch_check: amd64 only
  - maxkeys_check: kernel keyring limits
  
Whiptail menu offers:
  1. Default Install  (uses app-declared vars, no prompts)
  2. Advanced Install (28-step wizard: CTID, hostname, CPU, RAM, disk, IP,
                       bridge, VLAN, MTU, MAC, IPv6, password, SSH key,
                       timezone, features, tags, GPU, etc.)
  3. User Defaults    (loads ~/.config/community-scripts/default.vars)
  4. Settings         (configure user defaults)
  
Chosen settings → base_settings() applies precedence:
  app-declared values > user defaults > framework defaults
```

### Phase 3 — Container Creation (build_container → create_lxc_container)

```
build_container():
  - Downloads install.func content → stores in $FUNCTIONS_FILE_PATH env var
  - Builds NET_STRING (ip, gateway, mac, vlan, mtu, ipv6)
  - Builds FEATURES string (nesting, keyctl, fuse, tun)
  - Exports all config as env vars (CTID, APPLICATION, PASSWORD, VERBOSE, etc.)
  - Calls create_lxc_container()

create_lxc_container():
  - Validates CTID availability (pvesh /cluster/resources check)
  - Selects or downloads Debian/Ubuntu template (pveam download)
  - Runs: pct create $CTID $TEMPLATE_STORAGE:vztmpl/$TEMPLATE $PCT_OPTIONS
    (hostname, tags, features, network, cpu, memory, disk, unprivileged flag)
  - Starts container: pct start $CTID
  - Waits for network (polls pct exec $CTID ip addr)
  - Installs base packages inside container via pct exec: sudo, curl, mc, gnupg2, jq
  - Configures locale, timezone, DNS if needed
  - Optionally injects SSH authorized keys (pct push + pct exec)
```

### Phase 4 — Application Install (inside LXC)

```
build_container() executes the install script inside the container:

  lxc-attach -n $CTID -- bash -c "$(curl -fsSL .../install/appname-install.sh)"

The install script runs inside the LXC with $FUNCTIONS_FILE_PATH pre-loaded:

  appname-install.sh:
    source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"   # loads install.func
    color / verb_ip6 / catch_errors
    setting_up_container()    # removes Python EXTERNALLY-MANAGED, disables networkd-wait
    network_check()           # validates internet connectivity
    update_os()               # apt-get update/upgrade, optionally configure apt cacher
    
    # App-specific steps (entirely custom):
    msg_info "Installing Dependencies"
    apt install -y [packages]
    
    # Clone / download / configure the application
    # Set up systemd service
    # Configure env files
    
    motd_ssh()    # MOTD banner with app name, IP, OS; optional root SSH
    customize()   # passwordless login if no password, creates /usr/bin/update
    cleanup_lxc() # apt clean, remove temp files
```

### Phase 5 — Post-Install (back on host)

```
build_container() returns from lxc-attach
  - Checks error flag file in container (/root/.install-$SESSION_ID.failed)
  - On failure: shows recovery menu (retry, destroy, keep)
  - On success: configures GPU passthrough if var_gpu=yes
    (adds /dev/dri/renderDx and /dev/dri/cardx to LXC config)

description():
  - Gets container IP: pct exec $CTID ip a s dev eth0
  - Sets LXC description to HTML with community-scripts branding
  - Sets INSTALL_COMPLETE=true

ct/appname.sh continues:
  - Prints success message
  - Prints access URL: http://{IP}:{PORT}
```

### Update Flow (when run inside LXC)

```
User runs the same one-liner INSIDE the LXC container
  → start() detects no pveversion command → update mode
  → Shows whiptail: Silent/Verbose/Cancel
  → Calls update_script() (defined in ct/appname.sh)
  
update_script() is entirely app-specific:
  - Typical pattern: check for existing install, update packages/repos, restart service
  - For OpenMontage: git pull, pip install -r requirements.txt (skip .env), restart service
  
The /usr/bin/update shortcut (created by customize()) also triggers this same flow.
```

---

## Key Mechanics

### How install.func Reaches the Container

`FUNCTIONS_FILE_PATH` is the entire text content of `misc/install.func`, downloaded on the host and exported as an environment variable. `lxc-attach` passes environment variables into the container. The install script then does:

```bash
source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
```

This means the install script never makes a network call to fetch its utility functions — they arrive pre-loaded via the host's environment.

### Variable Naming Conventions

| Prefix | Meaning | Example |
|--------|---------|---------|
| `var_` | App defaults declared in ct/ script | `var_cpu`, `var_ram`, `var_gpu` |
| `APP_DEFAULT_` | Captured app defaults before user overrides | `APP_DEFAULT_CPU` |
| `PCT_` | Passed to pct create command | `PCT_OSTYPE`, `PCT_DISK_SIZE` |
| `CT_` | Runtime container config | `CT_ID`, `CT_TYPE` |
| `ENABLE_` | Feature flags | `ENABLE_GPU`, `ENABLE_FUSE`, `ENABLE_TUN` |
| `msg_` | Output functions | `msg_info`, `msg_ok`, `msg_error` |
| `$STD` | Output redirect (verbose=yes → tty, no → /dev/null) | `$STD apt install -y foo` |

### GPU Passthrough

`var_gpu="yes"` in `ct/appname.sh` enables GPU detection and passthrough. `build_container()` after container creation:
1. Detects Intel/AMD/NVIDIA GPU on the host via `lspci`
2. Shows a whiptail prompt asking which GPU devices to pass through
3. Appends `lxc.cgroup2.devices.allow` and `lxc.mount.entry` lines to `/etc/pve/lxc/$CTID.conf`

For OpenMontage, `var_gpu` should default to `"no"` — most users use cloud APIs and GPU passthrough in LXC on Debian 12 has additional complexity. Offer it in Advanced mode only.

### The `$STD` Pattern

All install steps use `$STD` before commands:
- `VERBOSE=yes` → `$STD` is empty (output shown on tty)
- `VERBOSE=no` → `$STD` redirects to log file

This lets the same script work in both silent and verbose modes without any conditional logic in the install script itself.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Running install steps directly in ct/ script
**What goes wrong:** Logic that should run inside the container ends up on the host.
**Why bad:** Wrong filesystem, wrong user context, hard to debug.
**Instead:** Everything application-specific goes in `install/appname-install.sh`.

### Anti-Pattern 2: Skipping `$STD` on apt/long-running commands
**What goes wrong:** Output always shown regardless of verbose mode.
**Instead:** Prefix all apt/configure commands with `$STD`.

### Anti-Pattern 3: Hardcoding container ID
**What goes wrong:** Conflicts with existing containers.
**Instead:** Use `NEXTID=$(pvesh get /cluster/nextid)` — this is done automatically by `install_script()`.

### Anti-Pattern 4: Overwriting .env on update
**What goes wrong:** User-configured API keys and settings are wiped.
**Instead:** In `update_script()`, only run `git pull` and `pip install` / `npm ci`. Never touch `.env`. If `.env` doesn't exist (first run of update on legacy install), generate a fresh one from `.env.example`.

### Anti-Pattern 5: Not calling cleanup_lxc at the end of install script
**What goes wrong:** Container has leftover apt cache, temp files, unnecessary packages.
**Instead:** Always end install script with `motd_ssh`, `customize`, `cleanup_lxc`.

---

## Component Build Order

This is the order to develop the components, because each depends on the previous:

1. **`install/openmontage-install.sh`** — Core value. Can be tested independently by spinning up a Debian 12 container and running it manually. No framework dependency during development.

2. **`ct/openmontage.sh`** — The host-side orchestrator. Depends on install script existing at the expected URL (or local path for testing). Can be tested in a real Proxmox environment.

3. **`ct/headers/openmontage`** — ASCII art header. Zero dependencies, trivial to generate.

4. **JSON metadata** — Not a file in the repo. Submitted via the community-scripts website after PR is merged. No development work needed; prepare the data but don't create a JSON file.

The framework itself (`build.func`, `install.func`, etc.) is consumed, not owned. No development work needed there.

---

## File Inventory for OpenMontage

| File | Location | Purpose |
|------|----------|---------|
| `ct/openmontage.sh` | repo root | Host-side orchestrator; declares defaults, routes install vs update |
| `install/openmontage-install.sh` | repo root | In-container installer; git clone, pip, npm, piper, .env, systemd |
| `ct/headers/openmontage` | repo root | ASCII art shown during install |
| JSON metadata | submitted via website | Powers community-scripts.org listing |

---

## Scalability Considerations

This architecture runs once per install. No scalability concern. The only performance consideration is install time: Python deps + Node deps + Piper TTS model download = potentially 5-10 minutes. This is normal for community-scripts — no action needed, but the install script should use `msg_info`/`msg_ok` to give feedback during each stage so the user knows it hasn't hung.

---

## Sources

- Source code: `misc/build.func` lines 30-100 (variables), 2968-3060 (install_script), 3472-3530 (start), 3533-3740 (build_container), 4280-4340 (lxc-attach execution), 5159-5400 (create_lxc_container), 5874-5920 (description)
- Source code: `ct/jellyfin.sh`, `ct/debian.sh` — real app examples
- Source code: `install/jellyfin-install.sh` — real install script example
- Source code: `misc/install.func` — in-container utility functions
- Docs: `docs/contribution/templates_json/AppName.md` — JSON metadata guide (HIGH confidence — official repo docs)
- PR template: `.github/pull_request_template.md` — contribution requirements
