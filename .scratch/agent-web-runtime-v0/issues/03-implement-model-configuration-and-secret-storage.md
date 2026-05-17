Status: done
Title: Implement Model Configuration
Type: AFK

## Parent

.scratch/agent-web-runtime-v0/PRD.md

## What to build

Add **Setup Mode** so `tweb` can store required **Model Configuration** before normal **Agent Browser Sessions** run. The base URL, model name, and API token are stored together in the static config file.

Normal sessions should fail early with a `<fatal>` message when required model configuration is missing, except for modes that explicitly do not need model calls.

## Acceptance criteria

- [ ] `tweb --setup` collects and stores base URL, model name, and API token.
- [ ] Model configuration is stored in `~/.config/tweb/model.json`.
- [ ] Normal model-backed sessions fail fast with `<fatal>` when required model configuration is missing.
- [ ] Tests cover config read/write behavior without requiring a real API token.
- [ ] Tests cover missing-config failure behavior without requiring a real API token.

## Blocked by

- .scratch/agent-web-runtime-v0/issues/01-start-a-hidden-agent-browser-session.md

## Comments

- Added Setup Mode storage for model base URL, model name, and API token.
- Model values are written to `~/.config/tweb/model.json`, including the API token, so agent sessions can start without interactive Keychain prompts.
- Added a startup gate that emits `<fatal>` and refuses model-backed sessions when required configuration is missing.
- Added tests for config read/write behavior and for missing-config failure without a real API token.
