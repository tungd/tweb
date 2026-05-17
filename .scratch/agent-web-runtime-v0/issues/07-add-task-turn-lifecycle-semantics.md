Status: done
Title: Add Task Turn Lifecycle Semantics
Type: AFK

## Parent

.scratch/agent-web-runtime-v0/PRD.md

## What to build

Harden the **Task Turn** lifecycle so one **Agent Browser Session** runs at most one active task at a time. Add **Queued Steering**, **Needs Input Block** handling, **Interrupt Command** behavior, per-turn **Turn Memory** reset, and explicit absence of **Semantic Session Memory**.

This slice should make the Browser Subagent feel like a controllable subagent rather than a fire-and-forget browser command.

## Acceptance criteria

- [ ] A second plain-text input during a running task is treated as **Queued Steering**, not a new concurrent task.
- [ ] `/interrupt` stops the current **Task Turn** without ending the **Agent Browser Session**.
- [ ] A **Needs Input Block** pauses the current task until the parent provides steering.
- [ ] Completed turns reset **Turn Memory**.
- [ ] Browser state remains intact across completed turns.
- [ ] `tweb` does not maintain automatic **Semantic Session Memory**.
- [ ] Tests cover idle, running, queued steering, needs-input, interrupt, result, and follow-up-turn behavior.

## Blocked by

- .scratch/agent-web-runtime-v0/issues/06-run-the-first-browser-subagent-task-turn.md

## Comments

- Added explicit Task Turn lifecycle states for idle, running, and needs-input.
- Plain text during a running turn is Queued Steering and is forwarded to the active task instead of starting a concurrent task.
- `/interrupt` stops the current Task Turn without closing the Agent Browser Session.
- Needs Input Blocks pause the turn until parent steering arrives.
- Completed and failed turns reset Turn Memory while preserving browser state and maintaining no Semantic Session Memory.
- Added tests for idle, running, queued steering, needs-input, interrupt, result, and follow-up-turn behavior.
