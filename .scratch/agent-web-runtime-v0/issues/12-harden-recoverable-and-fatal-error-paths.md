Status: done
Title: Harden Recoverable and Fatal Error Paths
Type: AFK

## Parent

.scratch/agent-web-runtime-v0/PRD.md

## What to build

Normalize `<error>` versus `<fatal>` behavior across the V0 runtime. Recoverable failures should leave the **Agent Browser Session** alive where possible. Fatal failures should be reserved for cases where the session cannot continue.

This slice should cover model configuration failures, model call failures, engine installation and reinstall failures, WebKit/session failures, task failures, interrupted turns, and malformed slash commands.

## Acceptance criteria

- [ ] Missing required model configuration in normal mode emits `<fatal>` and exits or refuses to start.
- [ ] Engine installation or reinstall failure emits recoverable `<error>` unless the session is unusable.
- [ ] Model call failures are surfaced as `<error>` when the session can continue.
- [ ] WebKit or session failures that prevent continued operation emit `<fatal>`.
- [ ] Interrupted turns produce a clear non-fatal outcome.
- [ ] Malformed slash commands produce recoverable `<error>` responses.
- [ ] Tests cover representative recoverable and fatal cases at the coordinator/protocol boundary.

## Blocked by

- .scratch/agent-web-runtime-v0/issues/06-run-the-first-browser-subagent-task-turn.md
- .scratch/agent-web-runtime-v0/issues/08-continue-tasks-across-navigation.md

## Comments

- Normalized coordinator/protocol handling for recoverable `<error>` versus fatal `<fatal>` paths.
- Missing model configuration is already covered by the model configuration gate as a fatal startup blocker.
- Engine reinstall failure is covered as a recoverable error in the navigation continuation slice.
- Task/model failures now surface as recoverable `<error>` responses when the session can continue.
- Session startup failures emit `<fatal>` and throw because the Agent Browser Session is unusable.
- Malformed slash commands and interrupted turns produce clear non-fatal outcomes.
- Added representative error-path tests at the coordinator/protocol boundary.
