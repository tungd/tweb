Status: done
Title: Continue Tasks Across Navigation
Type: AFK

## Parent

.scratch/agent-web-runtime-v0/PRD.md

## What to build

Support top-level navigation inside a running **Task Turn**. When navigation replaces the **Main Frame**, the **Native Host** should perform **Engine Reinstall**, emit URL updates, and allow the current task to continue unless the session becomes unusable.

The **Ready Block** should continue to mean that the **In-Page Engine** is installed, not that the page is network-idle. **Page Readiness** remains the **Browser Subagent**'s responsibility.

## Acceptance criteria

- [ ] Top-level navigation emits URL changes as **Update Blocks**.
- [ ] Top-level navigation triggers **Engine Reinstall** in the new **Main Frame**.
- [ ] A running **Task Turn** can continue after navigation.
- [ ] The **Native Host** does not depend on network-idle heuristics before letting the Browser Subagent work.
- [ ] Engine reinstall failure produces a recoverable `<error>` unless the whole session is unusable.
- [ ] Tests or smoke checks cover navigation followed by continued task execution on the new page.

## Blocked by

- .scratch/agent-web-runtime-v0/issues/06-run-the-first-browser-subagent-task-turn.md

## Comments

- Added an Engine Reinstall boundary that runs after top-level URL changes.
- URL changes continue to emit Update Blocks, and running Task Turns can complete after navigation.
- The Native Host coordinator does not use network-idle heuristics for Page Readiness.
- Engine Reinstall failures surface as recoverable `<error>` blocks when the session remains usable.
- Added tests for URL updates, reinstall calls, continued task execution after navigation, no network-idle dependency, and recoverable reinstall failure.
