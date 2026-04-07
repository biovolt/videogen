---
phase: 01-install-script
reviewed: 2026-04-07T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - install/openMontage-install.sh
  - ct/openMontage.sh
findings:
  critical: 2
  warning: 4
  info: 2
  total: 8
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-04-07
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Both scripts follow the community-scripts structure well overall: correct shebang, copyright headers, `build.func` sourced from the official URL, `${var_name:-default}` form used throughout, and the mandatory terminal calls (`motd_ssh`, `customize`, `cleanup_lxc`) are present at the end of the install script. The API-key handoff pattern — host collects via TTY, writes to `/root/.install_env` inside the container, install script sources it — is correctly implemented.

Two critical issues remain. First, the heredoc in `ct/openMontage.sh` that writes API keys into the container uses a double-quoted `EOF` delimiter, meaning keys are single-quote-wrapped on the host side; a key value containing a single quote will produce a broken or injectable env file. Second, the Python `.env` patching script passes the replacement value directly as a string to `re.sub`, which treats `&` as "insert the matched text" and `\n` / `\1` etc. as escape sequences — API keys with these characters will be silently corrupted in `.env`. Four warnings cover missing `$STD` prefixes in `update_script`, an unguarded `git pull`, and a version-string format mismatch that produces perpetual false-update detection.

---

## Critical Issues

### CR-01: Shell injection / broken env file via single-quote in API key value

**File:** `ct/openMontage.sh:67-71`

**Issue:** The heredoc delimiter is unquoted (`<<EOF`), so `${FAL_KEY}`, `${ELEVENLABS_API_KEY}`, and `${OPENAI_API_KEY}` are expanded on the host before being written. Each value is wrapped in single quotes in the output (e.g., `export FAL_KEY='<value>'`). If any key value contains a single quote, the resulting `/root/.install_env` file becomes syntactically invalid. When the install script later does `source /root/.install_env`, the broken syntax produces a parse error or, with a crafted value, allows command injection inside the container.

**Fix:** Write each value using `printf %q` (which produces a safely shell-quoted representation) or write the file via `pct exec` with individual env-var arguments instead of a heredoc:

```bash
pct exec "$CTID" -- bash -c "printf 'export FAL_KEY=%q\nexport ELEVENLABS_API_KEY=%q\nexport OPENAI_API_KEY=%q\n' \"\$FAL_KEY\" \"\$ELEVENLABS_API_KEY\" \"\$OPENAI_API_KEY\" > /root/.install_env" \
  -- env FAL_KEY="${FAL_KEY}" ELEVENLABS_API_KEY="${ELEVENLABS_API_KEY}" OPENAI_API_KEY="${OPENAI_API_KEY}"
```

A simpler alternative: use a single-quoted heredoc and write each value to its own file, then read with `cat`:

```bash
printf '%s' "${FAL_KEY}"            | pct exec "$CTID" -- tee /root/.fal_key >/dev/null
printf '%s' "${ELEVENLABS_API_KEY}" | pct exec "$CTID" -- tee /root/.elevenlabs_key >/dev/null
printf '%s' "${OPENAI_API_KEY}"     | pct exec "$CTID" -- tee /root/.openai_key >/dev/null
```

Then in the install script read with `FAL_KEY=$(cat /root/.fal_key)` etc., which is injection-safe regardless of key content.

---

### CR-02: `re.sub` replacement string not escaped — API key values corrupted when they contain `&` or `\`

**File:** `install/openMontage-install.sh:79-84`

**Issue:** The replacement on lines 79-84 passes the constructed string (`key + '=' + value`) directly as the `repl` argument to `re.sub`. Python's `re.sub` interprets `&` in the replacement as "substitute the entire matched text" and `\1`, `\2`, etc. as backreferences. API keys from OpenAI, ElevenLabs, and fal.ai are base64url-encoded and can contain `+`, `/`, `=`, and in some formats `&`. A key containing `&` will write a corrupted value to `.env` with no error. A key starting or containing `\` produces garbled output. The bug is silent — no exception is raised.

**Fix:** Use a lambda for the replacement to suppress template expansion:

```python
for var, key in [
    ('FAL_KEY',            'FAL_KEY'),
    ('ELEVENLABS_API_KEY', 'ELEVENLABS_API_KEY'),
    ('OPENAI_API_KEY',     'OPENAI_API_KEY'),
]:
    value = os.environ.get(var, '')
    if value:
        replacement = key + '=' + value
        content = re.sub(
            r'^' + key + r'=.*',
            lambda m, r=replacement: r,   # lambda bypasses & and \N expansion
            content,
            flags=re.M
        )
    else:
        placeholder = '# ' + key + '=your-key-here'
        content = re.sub(
            r'^' + key + r'=.*',
            lambda m, r=placeholder: r,
            content,
            flags=re.M
        )
```

---

## Warnings

### WR-01: `git pull` in `update_script` not prefixed with `$STD` and not guarded against failure

**File:** `ct/openMontage.sh:37`

**Issue:** `git pull` runs without `$STD`, so its output floods the terminal in quiet mode. More importantly, it has no failure guard. If the pull fails (network error, local modifications, detached HEAD), the script silently continues and runs `uv pip install` and `npm install` against a stale or partially merged tree, potentially leaving the application broken.

**Fix:**

```bash
$STD git pull || { msg_error "git pull failed — aborting update"; exit 1; }
```

---

### WR-02: `uv pip install` and `npm install` in `update_script` missing `$STD`

**File:** `ct/openMontage.sh:39,41`

**Issue:** Both commands lack the `$STD` prefix required by the project and the community-scripts PR review criteria. The equivalent commands in the install script (lines 47 and 52) correctly use `$STD`. The inconsistency means update runs are noisy and will fail PR review.

**Fix:**

```bash
$STD uv pip install --python /opt/openmontage/.venv/bin/python -r requirements.txt
# ...
$STD npm install
```

---

### WR-03: Version string format mismatch between install and update causes perpetual false-update detection

**File:** `install/openMontage-install.sh:36-41` and `ct/openMontage.sh:33-34`

**Issue:** `update_script` fetches the latest release tag via the GitHub Releases API (e.g., `v1.0.0`) and compares it to the stored version. The install script uses the same API call but falls back to `git rev-parse --short HEAD` (e.g., `abc1234`) when no release exists. If the repo has no releases at install time, the stored version will be a commit hash that can never equal a future release tag. Every `update_script` run will unconditionally re-pull and reinstall even when there is no actual change.

**Fix:** Prefix the fallback value to make it distinguishable, and handle it in `update_script`:

```bash
# install/openMontage-install.sh: fallback block
if [[ -z "${RELEASE}" ]]; then
  RELEASE="git-$(git -C /opt/openmontage rev-parse --short HEAD)"
  msg_info "No GitHub release found — tracking by commit: ${RELEASE}"
fi
```

In `update_script`, skip the comparison when the stored value starts with `git-` and always update (or always skip — document the chosen behaviour).

---

### WR-04: Python inline script uses bare `open()` without `with` — disk-full leaves `.env` truncated

**File:** `install/openMontage-install.sh:69,94`

**Issue:** `open(env_file).read()` on line 69 and `open(env_file, 'w')` on line 94 are not used as context managers. If an exception occurs after the write-mode `open()` truncates the file but before `f.write(content)` completes (e.g., disk full), `.env` is left empty. The application will subsequently start without any API keys and fail in a way that is hard to diagnose.

**Fix:** Use `with` statements:

```python
with open(env_file) as f:
    content = f.read()

# ... patching logic ...

with open(env_file, 'w') as f:
    f.write(content)
```

---

## Info

### IN-01: `APP` variable not declared in install script — version path is hardcoded

**File:** `install/openMontage-install.sh:41`

**Issue:** CLAUDE.md specifies the version file path as `/opt/${APP}_version.txt`. The install script never declares `APP`, so the path is hardcoded as `/opt/OpenMontage_version.txt`. This works today but diverges from the convention and will silently break if the name changes or the script is adapted.

**Fix:**

```bash
APP="OpenMontage"
# ...
echo "${RELEASE}" >"/opt/${APP}_version.txt"
```

---

### IN-02: `var_gpu` not declared — GPU passthrough will never be configured

**File:** `ct/openMontage.sh:9-17`

**Issue:** The CLAUDE.md project spec notes `var_gpu="yes"` as the intended value for an app that does video/AI workloads. The variable is absent from the script. Without it, `setup_hwaccel` is never called and GPU passthrough is never configured in the container. For a video production pipeline this is a meaningful capability gap.

**Fix:** Add after `var_unprivileged`:

```bash
var_gpu="${var_gpu:-yes}"
```

And add in `install/openMontage-install.sh` after `setup_ffmpeg`:

```bash
setup_hwaccel "openMontage"
```

---

_Reviewed: 2026-04-07_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
