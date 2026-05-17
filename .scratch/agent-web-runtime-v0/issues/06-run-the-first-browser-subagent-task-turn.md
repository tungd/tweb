Status: done
Title: Run the First Browser Subagent Task Turn
Type: AFK

## Parent

.scratch/agent-web-runtime-v0/PRD.md

## What to build

Connect the **Agent Browser Session** to the vendored **In-Page Engine** and **Session Model Bridge** so the parent **Agent** can send one plain-text **Task Turn** and receive a `<result>` block.

This slice should prove the core thesis end to end: parent agent delegates a high-level task, the **Browser Subagent** uses PageAgent internally, model calls route through the **Native Host**, and the result returns with model-written **Compact Evidence**.

## Acceptance criteria

- [ ] Plain text input starts a **Task Turn** when the session is idle.
- [ ] The **In-Page Engine** receives and executes the task.
- [ ] Model calls during the task route through the **Session Model Bridge**.
- [ ] The completed task returns a `<result>` block.
- [ ] Normal results include model-written **Compact Evidence**.
- [ ] The current browser state remains intact after the result.
- [ ] Tests or smoke checks cover a fake or controlled page task returning a result through the full path.

## Blocked by

- .scratch/agent-web-runtime-v0/issues/04-bridge-pageagent-model-calls-through-tweb-llm.md
- .scratch/agent-web-runtime-v0/issues/05-vendor-the-pageagent-in-page-engine.md

## Comments

- Added Task Turn request/result contracts with Compact Evidence rendering.
- Added a Browser Subagent task runner interface and PageAgent task runner that routes model calls through the Session Model Bridge.
- Updated the session coordinator so idle plain text starts a Task Turn and returns a `<result>` block.
- Wired the CLI to run controlled task turns for smoke workflows and configured model-backed PageAgent turns for normal sessions.
- Added tests for plain-text task input, model bridge routing through the runner, result rendering, and browser-state continuity.
