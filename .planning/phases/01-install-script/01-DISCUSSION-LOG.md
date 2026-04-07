# Phase 1: Install Script - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-07
**Phase:** 01-install-script
**Areas discussed:** API key prompt flow, Install order & messaging

---

## API Key Prompt Flow

### FAL_KEY empty behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Skip silently (Recommended) | Leave FAL_KEY empty in .env — OpenMontage works zero-key with Piper TTS + free stock media | |
| Ask again once | Re-prompt once explaining FAL_KEY enables premium features | |
| Set a placeholder | Write FAL_KEY=your-key-here so user sees where to fill it in | |

**User's choice:** Skip silently
**Notes:** User later clarified that skipped keys should still get a commented-out placeholder (e.g., `# FAL_KEY=your-key-here`), not left blank entirely.

### Other API keys

| Option | Description | Selected |
|--------|-------------|----------|
| FAL_KEY only (Recommended) | Keep install friction low | |
| Top 3 keys | Prompt for FAL_KEY, ELEVENLABS_API_KEY, OPENAI_API_KEY | ✓ |
| You decide | Claude picks based on .env.example contents | |

**User's choice:** Top 3 keys
**Notes:** Covers the most common premium providers.

### Skip behavior for all keys

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, all skip silently (Recommended) | Consistent behavior — all three accept empty | ✓ |
| Show what each enables | Brief one-liner per key before the prompt | |

**User's choice:** All skip silently — consistent behavior across all three prompts.
**Notes:** User confirmed placeholders should be commented out (e.g., `# FAL_KEY=your-key-here`).

---

## Install Order & Messaging

### Install order

| Option | Description | Selected |
|--------|-------------|----------|
| System deps first (Recommended) | Python -> Node.js -> FFmpeg -> clone -> pip -> npm -> .env | ✓ |
| Clone first | Clone OpenMontage first, then install deps | |
| You decide | Claude picks based on community-scripts conventions | |

**User's choice:** System deps first

### Message verbosity

| Option | Description | Selected |
|--------|-------------|----------|
| One per major step (Recommended) | msg_info/msg_ok for each major step, ~8 pairs | ✓ |
| Granular sub-steps | Messages for sub-steps too, ~15+ pairs | |
| Minimal | Only 3-4 high-level messages | |

**User's choice:** One per major step

---

## Claude's Discretion

- Version tracking method (git tag vs commit hash)
- Piper TTS handling (deferred to first run)
- Python version selection

## Deferred Ideas

None
