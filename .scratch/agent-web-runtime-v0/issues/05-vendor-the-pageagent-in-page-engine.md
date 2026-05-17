Status: done
Title: Vendor the PageAgent In-Page Engine
Type: AFK

## Parent

.scratch/agent-web-runtime-v0/PRD.md

## What to build

Vendor the PageAgent bundle for V0 and make it loadable as the initial **In-Page Engine**. The external `tweb` contract should remain **Browser Subagent** **Task Turns**, not PageAgent-specific APIs.

This slice should establish how the vendored bundle is updated, how it is loaded into the **Main Frame**, and how the **Native Host** verifies that the **In-Page Engine** is installed.

## Acceptance criteria

- [ ] A vendored PageAgent bundle is present and loadable by the **Native Host**.
- [ ] The **Native Host** can install the bundle in the **Main Frame**.
- [ ] Installation exposes a minimal readiness signal for **Installed Engine**.
- [ ] The external parent-agent protocol does not expose PageAgent-specific APIs.
- [ ] The vendoring/update convention is documented.
- [ ] Tests or smoke checks verify that the vendored bundle can be found and injected.

## Blocked by

- .scratch/agent-web-runtime-v0/issues/01-start-a-hidden-agent-browser-session.md

## Comments

- Added a vendored PageAgent-compatible bundle as a SwiftPM resource with an update convention documented beside it.
- Added an In-Page Engine installer that injects the bundle into the Main Frame and verifies the Installed Engine readiness signal.
- Kept the external Text Protocol independent from PageAgent-specific APIs.
- Added tests for vendored bundle lookup, main-frame injection, readiness failure, and public slash-command contract boundaries.
