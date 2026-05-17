Status: done
Title: Start a Hidden Agent Browser Session
Type: AFK

## Parent

.scratch/agent-web-runtime-v0/PRD.md

## What to build

Build the first runnable `tweb` vertical slice: a Swift Package CLI that starts a macOS 14+ WebKit-backed **Agent Browser Session**, creates a **Hidden Session**, accepts an optional **Launch URL**, emits a **Ready Block** once the session can accept input, emits status and URL changes as **Update Blocks**, and exits cleanly through `/quit`.

This slice does not need PageAgent, model calls, profiles, or human handoff. It proves the **Pure CLI Host**, WebKit run loop, stdin/stdout **Text Protocol**, optional launch navigation, and basic session shutdown.

## Acceptance criteria

- [ ] `tweb` can run with no URL and starts from `about:blank`.
- [ ] `tweb` can run with a Launch URL and navigates the **Active Page** there.
- [ ] The session emits a `<ready>` block when it can accept input.
- [ ] Status and URL changes are emitted as `<update>` blocks.
- [ ] `/quit` exits the process cleanly.
- [ ] The implementation is a Swift Package executable and requires macOS 14+.
- [ ] Tests cover the protocol output and session lifecycle behavior that can be exercised without real WebKit internals.

## Blocked by

None - can start immediately

## Comments

- Implemented a Swift Package executable/library split with a macOS 14 floor.
- Added a hidden-session lifecycle coordinator with optional Launch URL, Ready Block, Update Blocks, and `/quit`.
- Added issue-focused tests for protocol output and lifecycle behavior without depending on WebKit internals.
