Status: done
Title: Implement Model Configuration and Secret Storage
Type: AFK

## Parent

.scratch/agent-web-runtime-v0/PRD.md

## What to build

Add **Setup Mode** so `tweb` can store required **Model Configuration** before normal **Agent Browser Sessions** run. Non-secret configuration, including base URL and model name, should be stored locally. API tokens should be stored in the platform **Secret Store**.

Normal sessions should fail early with a `<fatal>` message when required model configuration is missing, except for modes that explicitly do not need model calls.

## Acceptance criteria

- [ ] `tweb --setup` collects and stores base URL, model name, and API token.
- [ ] Non-secret model configuration is stored outside the platform Secret Store.
- [ ] API tokens are stored in the platform Secret Store.
- [ ] Normal model-backed sessions fail fast with `<fatal>` when required model configuration is missing.
- [ ] Tests cover config read/write behavior using a fake secret backend.
- [ ] Tests cover missing-config failure behavior without requiring a real API token.

## Blocked by

- .scratch/agent-web-runtime-v0/issues/01-start-a-hidden-agent-browser-session.md

## Comments

- Added Setup Mode storage for model base URL, model name, and API token.
- Non-secret model values are written to a local JSON config file; API tokens go through a fakeable Secret Store boundary with a Keychain-backed implementation for the CLI.
- Added a startup gate that emits `<fatal>` and refuses model-backed sessions when required configuration is missing.
- Added tests for config read/write behavior with a fake Secret Store and for missing-config failure without a real API token.
