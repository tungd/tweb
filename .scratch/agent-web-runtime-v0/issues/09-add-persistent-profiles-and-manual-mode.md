Status: done
Title: Add Persistent Profiles and Manual Mode
Type: AFK

## Parent

.scratch/agent-web-runtime-v0/PRD.md

## What to build

Add **Persistent Profile** support backed by UUID-based WebKit **Profile Stores**, while preserving **Ephemeral Session State** as the default. Add **Manual Mode** so a human can create or update a named profile through direct interaction before later agent use.

Persistent Profiles are named web identities and may span domains. They should not be implemented through cookie export/import.

## Acceptance criteria

- [ ] Sessions without a profile use **Ephemeral Session State**.
- [ ] `--profile <name>` selects or creates a named **Persistent Profile**.
- [ ] Each named profile maps to a stable UUID-backed **Profile Store**.
- [ ] `--manual --profile <name>` opens a human-visible session for profile setup or update.
- [ ] Profile mappings persist across runs.
- [ ] Tests cover profile-name to UUID mapping and default ephemeral behavior.
- [ ] Manual mode is smoke-testable with a persistent WebKit store.

## Blocked by

- .scratch/agent-web-runtime-v0/issues/01-start-a-hidden-agent-browser-session.md

## Comments

- Added default Ephemeral Session State and named Persistent Profile selection.
- Persistent Profiles map to stable UUID-backed WebKit website data store identities; mappings persist in a local profile registry.
- Added Manual Mode with a visible session boundary for creating or updating a named profile.
- Wired `--profile <name>` and `--manual --profile <name>` into the CLI path.
- Added tests for ephemeral default behavior, stable/reused profile UUID mapping, mapping persistence, profile selection, and Manual Mode visibility.
