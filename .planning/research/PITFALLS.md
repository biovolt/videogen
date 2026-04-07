# Domain Pitfalls: Proxmox Community-Script LXC Installer

**Domain:** Proxmox LXC installer script for a Python/Node.js/FFmpeg application
**Researched:** 2026-04-07
**Confidence:** MEDIUM — community-scripts wiki verified, GPU/Python pitfalls from official forum threads and GitHub issues

---

## Critical Pitfalls

Mistakes that cause rewrites, unusable containers, or immediate PR rejection.

---

### Pitfall 1: Missing `update_script()` Function

**What goes wrong:** Any PR submitted without a functioning `update_script()` function in the `ct/` script is automatically rejected. The community-scripts maintainers treat an absent or no-op update function as a hard blocker.

**Why it happens:** Authors focus on the install path and treat the update path as secondary. The update function must: detect the current installed version (from `/opt/${APP}_version.txt`), compare it against upstream, skip if already current, perform the upgrade, and rewrite the version file.

**Consequences:** PR rejected. No merge path until a proper update function is added.

**Prevention:**
- Write the update function before writing install logic — it forces clarity on what "version" means for this app
- For OpenMontage: version is a git commit SHA or tag; store it in `/opt/openmontage_version.txt` post-install
- Update function must `git pull` and re-run `pip install -r requirements.txt` and `npm install` — but protect `.env` from overwrite (see Pitfall 7)

**Warning signs:** A script with `update_script() { echo "Not supported"; }` or no function at all.

**Phase:** Phase 1 (script scaffold) — design the update contract before writing install code.

---

### Pitfall 2: Debian 12 PEP 668 — `pip install` Fails System-Wide

**What goes wrong:** Debian 12 (Bookworm) implements PEP 668, marking the system Python environment as "externally managed". Running `pip3 install -r requirements.txt` directly produces: `error: externally-managed-environment`. This is a hard stop inside a non-interactive install script.

**Why it happens:** Debian decoupled apt-managed Python from pip-managed Python in Bookworm. The EXTERNALLY-MANAGED sentinel file at `/usr/lib/python3.*/EXTERNALLY-MANAGED` enforces this.

**Consequences:** Install script aborts mid-run, leaving a broken container. Silent failures are possible if the script ignores exit codes.

**Prevention:**
- Always install into a virtualenv: `python3 -m venv /opt/openmontage/venv && /opt/openmontage/venv/bin/pip install -r requirements.txt`
- Or install `python3-full` and `python3-venv` via apt first: `apt-get install -y python3 python3-venv python3-full`
- Never use `--break-system-packages` in a community script — this pollutes the system Python and is a maintainer red flag
- Do not delete the EXTERNALLY-MANAGED file — this is considered a hack and disallowed in community-scripts

**Warning signs:** Script calls `pip3 install` without first activating a venv or checking for `python3-venv`.

**Phase:** Phase 1 (install script) — establish venv path as the canonical Python runtime from day one.

---

### Pitfall 3: Node.js NodeSource GPG Key Bootstrap Failure

**What goes wrong:** Adding the NodeSource repository for Node.js 18+ on a minimal Debian 12 container fails with: `NO_PUBKEY 2F59B5F99B1BE0B4` because `gpg` is not present in a bare Debian 12 LXC image. The setup script silently skips repository import or fails, and subsequent `apt-get install nodejs` installs the ancient Debian-packaged version (18.19 from backports, or older).

**Why it happens:** NodeSource's setup script requires `gpg` to import the signing key. Minimal container images omit it. This was a confirmed bug in NodeSource distributions (issue #1688, fixed in 2024 via PR #1739) but fresh containers can still hit it if they pre-date the fix.

**Consequences:** Wrong Node.js version silently installed. Remotion (which requires Node.js 18+) may appear to install then fail at runtime.

**Prevention:**
- Explicitly install `gpg` before any NodeSource setup: `apt-get install -y gpg curl`
- Use the official NodeSource setup script with explicit key import: `curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg`
- After install, assert the version: `node --version | grep -qE '^v(18|19|20|21|22)' || { echo "Wrong Node version"; exit 1; }`

**Warning signs:** Install script calls nodesource setup without first checking/installing `gpg`. No version assertion post-install.

**Phase:** Phase 1 (install script) — Node.js installation order and assertion matters.

---

### Pitfall 4: NVIDIA GPU Passthrough — Driver Version Must Match Host Exactly

**What goes wrong:** NVIDIA GPU passthrough to LXC requires installing the identical driver version inside the container as is running on the Proxmox host. A mismatch of even a minor version produces cryptic CUDA errors at runtime or `nvidia-smi` appearing to work while actual GPU access fails with permission denied.

**Why it happens:** The LXC container shares the host's kernel modules but needs its own user-space libraries. If host runs driver 550.x and the container installs 560.x user-space libs, the ABI is incompatible.

**Consequences:** GPU silently unavailable; FFmpeg hardware encoding fails at runtime, not at install time.

**Prevention:**
- The install script must NOT install the NVIDIA driver into the container via apt (which pulls latest). It must detect the host driver version and install the same version with `--no-kernel-module`
- Add `var_gpu="yes"` metadata variable to the container script; only run GPU setup when the user opts in
- Container must be configured with cgroup device allowances in `/etc/pve/lxc/<CTID>.conf` before GPU is accessible:
  ```
  lxc.cgroup2.devices.allow: c 195:* rwm
  lxc.cgroup2.devices.allow: c 235:* rwm
  lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
  lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
  lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
  ```
- For NVIDIA 560+, the `--no-kernel-module` flag behavior changed. Test against the target driver version before shipping.
- For most OpenMontage users (API-based video generation via fal.ai etc.), GPU passthrough is optional. Default to no GPU and document manual setup.

**Warning signs:** Install script runs `apt-get install nvidia-driver` or `nvidia-smi` inside container during install.

**Phase:** Phase 2 (GPU option) — treat GPU as a post-install manual step documented in README rather than automated in the script, until the version-matching problem can be solved reliably.

---

### Pitfall 5: Unprivileged LXC UID/GID Mapping Breaks Service Users

**What goes wrong:** In an unprivileged LXC container, UIDs 0–65535 inside the container map to UIDs 100000–165535 on the host. If the install script creates a service user (e.g., `useradd -r openmontage`) with UID 1000 inside the container, host-side bind mounts or shared volumes owned by UID 1000 on the host will not be accessible — the container's UID 1000 is actually UID 101000 on the host.

**Why it happens:** Standard Proxmox unprivileged container behavior. Community-scripts default is `var_unprivileged="1"`.

**Consequences:** Files written by the service user inside the container appear owned by a high UID externally; bind-mount paths for output video files are inaccessible from the host without manual `chown`.

**Prevention:**
- Run OpenMontage as root inside the container for v1 (simplest and standard for community-scripts apps that don't need privilege separation)
- If a service user is needed, document the UID mapping requirement explicitly
- Do not use bind mounts for output in the initial script; keep output inside the container filesystem

**Warning signs:** Script creates a dedicated service user AND uses bind mounts, without addressing UID mapping.

**Phase:** Phase 1 (install script) — decide run-as-root vs service user before writing systemd unit.

---

### Pitfall 6: ShellCheck Failures Block Merge

**What goes wrong:** The community-scripts CI runs ShellCheck on all scripts. Common failures that block merge:
- Unquoted variables: `$VAR` instead of `"${VAR}"`
- Single-bracket conditionals: `[ -f $FILE ]` instead of `[[ -f "${FILE}" ]]`
- Unhandled command failures (missing `|| exit 1` or `set -e`)
- Using `$()` but ignoring its exit code in a pipeline

**Why it happens:** Authors familiar with simple bash scripts write idioms that work interactively but fail ShellCheck's stricter static analysis.

**Consequences:** CI fails, PR cannot be merged until all ShellCheck warnings at SC2 level and above are resolved.

**Prevention:**
- Run `shellcheck ct/openmontage.sh install/openmontage-install.sh` locally before opening any PR
- Use `$STD` prefix (provided by `build.func`) for suppressing expected command output rather than `>/dev/null 2>&1`
- Quote all variable expansions; use `[[ ]]` exclusively
- Required header in every file:
  ```bash
  #!/usr/bin/env bash
  # Copyright (c) 2021-2025 community-scripts ORG
  # Author: YourUsername
  # License: MIT
  # Source: https://github.com/calesthio/OpenMontage
  ```

**Warning signs:** Any `$VARIABLE` without quotes. Any `[ condition ]` using single brackets.

**Phase:** Phase 1 (script scaffold) — configure ShellCheck in editor/CI from the start.

---

### Pitfall 7: Update Script Overwrites `.env` / User Config

**What goes wrong:** A naive `git pull` in the update function resets tracked files including any `.env` or config that was committed to the repo. Even if `.env` is gitignored, the update function might re-run full installation steps that regenerate config files and overwrite user-set values.

**Why it happens:** Install scripts often place `.env` in the application directory and write defaults into it. On re-run, the same write command runs again.

**Consequences:** User loses API keys, custom settings. On next application start, it behaves as a fresh unconfigured install. Data loss from the user's perspective.

**Prevention:**
- Use guard: `[[ ! -f /opt/openmontage/.env ]] && cp /opt/openmontage/.env.example /opt/openmontage/.env`
- Never `cp` or `tee` to `.env` unconditionally in the update path
- Version file (stored in `/opt/openmontage_version.txt`) should be separate from application config
- Back up `.env` before any git operation: `cp /opt/openmontage/.env /opt/openmontage/.env.bak`

**Warning signs:** Update function contains `cp .env.example .env` or `echo "KEY=value" > .env` without an existence check.

**Phase:** Phase 1 (update function design) — establish the config-preservation contract as a hard requirement.

---

## Moderate Pitfalls

---

### Pitfall 8: Default Disk Size Too Small for the Stack

**What goes wrong:** The project defaults to `var_disk="8"` (8GB). The full stack — Debian 12 base (~1.5GB), Python venv with dependencies (~1–2GB), Node.js + Remotion + npm packages (~1–2GB), FFmpeg (~200MB), OpenMontage source, and generated video output — easily exceeds 8GB. The install script silently runs out of disk mid-install.

**Prevention:**
- Set `var_disk="12"` as the default minimum
- Add a disk space check early in the install script: `[[ $(df / --output=avail | tail -1) -lt 5000000 ]] && { echo "Need at least 5GB free"; exit 1; }`
- Document in advanced mode that users doing local video rendering need 20GB+

**Warning signs:** `var_disk="8"` in the container script with a full Python + Node.js dependency tree.

**Phase:** Phase 1 (container defaults) — set realistic defaults before any testing.

---

### Pitfall 9: FFmpeg Version from Debian 12 Repos is Too Old for Some Encoders

**What goes wrong:** `apt-get install ffmpeg` on Debian 12 installs FFmpeg 5.1.x. Some FFmpeg features used by video pipeline tools (including certain libav filters, HEVC encoding options, and hardware acceleration APIs) require FFmpeg 6.x or later.

**Prevention:**
- Verify which FFmpeg version OpenMontage actually requires before defaulting to apt install
- If 5.1.x is sufficient, apt install is simpler and more maintainable
- If 6.x+ is needed, use the official Debian backports or a pre-built static binary from johnvansickle.com (widely used in community-scripts)
- Do not compile FFmpeg from source inside the install script — build times exceed reasonable install windows and are fragile

**Warning signs:** Install script compiles FFmpeg from source.

**Phase:** Phase 1 (install script) — test FFmpeg version requirement against OpenMontage before writing install code.

---

### Pitfall 10: GitHub API Rate Limiting in Version Detection

**What goes wrong:** The `update_script()` function queries the GitHub API to detect the latest release version. On homelabs with many containers running the same script, or on shared NAT IP addresses, GitHub's unauthenticated API rate limit (60 req/hour) is hit. Version detection returns an error, and a naive script treats this as "already up to date" or crashes.

**Why it happens:** A real case in the community-scripts repo: issue #12884 showed the paginated releases endpoint sometimes omitting recent releases entirely, causing pinned version mismatches.

**Prevention:**
- Always handle a non-200 API response explicitly: `[[ -z "${latest}" ]] && { echo "Could not determine upstream version"; exit 1; }`
- Use both the paginated endpoint and the `/releases/latest` endpoint as fallback
- For git-based apps (like OpenMontage), prefer `git ls-remote` over GitHub API for version checking — no rate limit

**Warning signs:** `curl https://api.github.com/repos/.../releases/latest | jq .tag_name` with no error handling.

**Phase:** Phase 2 (update function) — build resilient version detection.

---

### Pitfall 11: LXC and VM GPU Passthrough Cannot Coexist

**What goes wrong:** Setting up PCIe/full GPU passthrough to a VM (which requires blacklisting the NVIDIA driver on the host) breaks LXC GPU passthrough (which requires the host to have NVIDIA drivers loaded). A homelab user who already has GPU passthrough to a Windows VM will break that VM if they enable LXC GPU sharing.

**Prevention:**
- Document this conflict clearly: GPU passthrough to LXC requires the driver loaded on the host — incompatible with exclusive VM passthrough
- The GPU option in the installer should print a prominent warning: "GPU passthrough to LXC is incompatible with VM PCIe passthrough on the same host"
- Default GPU option to disabled

**Warning signs:** Any documentation claiming GPU passthrough works universally without noting the VM exclusivity constraint.

**Phase:** Phase 2 (GPU option) — document the constraint before any implementation.

---

### Pitfall 12: Missing or Wrong Filenames Cause Immediate PR Rejection

**What goes wrong:** Community-scripts has strict naming conventions:
- `ct/OpenmontageAI.sh` (Title Case) — wrong
- `ct/openmontage.sh` (lowercase) — correct
- `install/Openmontage-Install.sh` — wrong
- `install/openmontage-install.sh` — correct
- The two filenames must reference the same app name; a mismatch is an automatic rejection

**Prevention:**
- Use lowercase only for both files
- The `APP` variable in the ct script should match the human-readable name: `APP="OpenMontage"` (display), but file is `openmontage.sh`

**Phase:** Phase 1 (scaffold) — get names right before writing any logic.

---

## Minor Pitfalls

---

### Pitfall 13: `python3-venv` Not Installed — Silent venv Failure

**What goes wrong:** `python3 -m venv /opt/openmontage/venv` silently exits with error if `python3-venv` is not installed on Debian 12. The venv directory is partially created, and subsequent `pip install` appears to run but installs into a broken environment.

**Prevention:** `apt-get install -y python3 python3-venv python3-full` before any venv creation. Assert venv was created: `[[ -f /opt/openmontage/venv/bin/python ]] || { echo "venv creation failed"; exit 1; }`

**Phase:** Phase 1.

---

### Pitfall 14: `cleanup_lxc` Must Be Called Before Exit

**What goes wrong:** Community-scripts install scripts must call `cleanup_lxc` as their final step before exiting. Scripts that skip this leave temporary files and apt caches, bloating the container image. PRs without this call are flagged in review.

**Prevention:** Always end the install script with `cleanup_lxc`. This is provided by `build.func` and runs `apt-get autoremove`, `apt-get clean`, and removes temp files.

**Phase:** Phase 1 (install script closing steps).

---

### Pitfall 15: Telemetry Integration (`api.func`) Is Expected

**What goes wrong:** Community-scripts uses `api.func` for anonymous telemetry on container creation and install success/failure. Scripts that omit `post_to_api` and `post_update_to_api` calls produce missing data in the project's dashboard and may be flagged in review for incomplete implementation of the shared framework.

**Prevention:** Include the standard telemetry calls using the variables provided by `build.func`. Users can opt out via `DIAGNOSTICS="no"` — the script author doesn't control this; just implement the calls correctly.

**Phase:** Phase 1 (script scaffold).

---

### Pitfall 16: Nesting Disabled by Default — Docker Won't Work

**What goes wrong:** If the install or update process later needs Docker (e.g., for a dependency that ships as a Docker image), it will fail in an LXC container with `var_unprivileged="1"` and nesting disabled. Additionally, runc 1.3.3+ breaks Docker in unprivileged LXC with nesting due to an AppArmor/procfs interaction.

**Prevention:** OpenMontage does not require Docker — avoid any dependencies that pull Docker as a prerequisite. If a future update of OpenMontage ships a Docker-based component, this becomes a critical issue requiring a VM instead.

**Warning signs:** Any dependency that requires Docker, Podman, or containerd inside the container.

**Phase:** Ongoing — monitor OpenMontage upstream for Docker dependency introduction.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| Initial install script | PEP 668 pip failure (Pitfall 2) | Use venv from the start |
| Initial install script | Node.js GPG key absent (Pitfall 3) | Install gpg before nodesource |
| Container defaults | 8GB disk too small (Pitfall 8) | Default to 12GB |
| Script scaffold | Missing update function (Pitfall 1) | Write update contract first |
| Script scaffold | ShellCheck failures (Pitfall 6) | Run ShellCheck locally in CI |
| Update function | `.env` overwritten on update (Pitfall 7) | Guard all config writes |
| Update function | GitHub API rate limiting (Pitfall 10) | Use git ls-remote fallback |
| GPU option | Driver version mismatch (Pitfall 4) | Default disabled, document manual |
| GPU option | VM/LXC passthrough conflict (Pitfall 11) | Print warning at option selection |
| PR submission | Wrong filenames (Pitfall 12) | Verify names match convention |
| PR submission | Missing cleanup_lxc (Pitfall 14) | Always last step in install |
| PR submission | Closed-source app rejection | OpenMontage is open source — OK |

---

## Sources

- [community-scripts/ProxmoxVE CONTRIBUTING wiki](https://github.com/community-scripts/ProxmoxVE/wiki/CONTRIBUTING)
- [community-scripts/ProxmoxVE api.func wiki](https://github.com/community-scripts/ProxmoxVE/wiki/%5Bcore%5D:-api.func)
- [PatchMon update script failure — issue #12884](https://github.com/community-scripts/ProxmoxVE/issues/12884)
- [Node.js 18 on Debian 12 GPG error — issue #1688](https://github.com/nodesource/distributions/issues/1688)
- [Fix for "externally managed environment" — community-scripts discussion #555](https://github.com/community-scripts/ProxmoxVE/discussions/555)
- [Proxmox wiki: Unprivileged LXC containers](https://pve.proxmox.com/wiki/Unprivileged_LXC_containers)
- [Proxmox forum: GPU passthrough to LXC](https://forum.proxmox.com/threads/gpu-passthrough-to-container-lxc.132518/)
- [NVIDIA LXC passthrough — unprivileged guide](https://github.com/H3rz3n/proxmox-lxc-unprivileged-gpu-passthrough)
- [Proxmox forum: NVIDIA LXC passthrough on Proxmox 9.0.6](https://forum.proxmox.com/threads/seeking-help-with-nvidia-gpu-passthrough-to-unprivileged-lxc-containers-on-proxmox-9-0-6.171365/)
- [runc 1.3.3 AppArmor failure in unprivileged LXC — opencontainers/runc issue #4972](https://github.com/opencontainers/runc/issues/4972)
- [FFmpeg hardware acceleration in Proxmox LXC](https://forum.proxmox.com/threads/ffmpeg-running-inside-both-lxc-containers-and-vms-on-a-fresh-proxmox-installation.173478/)
- [Jeff Geerling: externally-managed-environment pip fix](https://www.jeffgeerling.com/blog/2023/how-solve-error-externally-managed-environment-when-installing-pip3/)
