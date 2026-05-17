Status: done
Title: Create End-to-End V0 Smoke Workflow
Type: AFK

## Parent

.scratch/agent-web-runtime-v0/PRD.md

## What to build

Create a demoable end-to-end smoke workflow that proves V0 works through the actual parent-agent interface. The workflow should exercise session startup, Ready Block, one or more Task Turns, navigation, result output, trace inspection, and inspection slash commands against a controlled page and fake or configured model endpoint.

This issue is about making the integrated behavior easy to verify, not adding new product semantics.

## Acceptance criteria

- [ ] A repeatable smoke workflow starts `tweb` and reaches a **Ready Block**.
- [ ] The workflow sends at least one plain-text **Task Turn** and receives a `<result>` block.
- [ ] The workflow covers navigation and continued task execution after navigation.
- [ ] The workflow verifies `/trace`.
- [ ] The workflow verifies at least one artifact command such as `/screenshot` or `/html`.
- [ ] The workflow can run without requiring real third-party credentials.
- [ ] Documentation explains how to run the smoke workflow locally.

## Blocked by

- .scratch/agent-web-runtime-v0/issues/02-add-slash-command-inspection-tools.md
- .scratch/agent-web-runtime-v0/issues/06-run-the-first-browser-subagent-task-turn.md
- .scratch/agent-web-runtime-v0/issues/07-add-task-turn-lifecycle-semantics.md
- .scratch/agent-web-runtime-v0/issues/08-continue-tasks-across-navigation.md

## Comments

- Added an end-to-end smoke test covering startup, Ready Block, Task Turn result, navigation update, Trace Command, and HTML artifact writing.
- Added `scripts/smoke-v0.sh`, which builds and starts the actual `tweb` executable over stdin/stdout with `--controlled`.
- The smoke workflow navigates through a controlled Task Turn, verifies `<result>`, verifies `/trace`, writes an `/html` Artifact File, and quits.
- Added `docs/smoke-v0.md` with local run instructions.
- Verified the script passes locally without third-party credentials.
