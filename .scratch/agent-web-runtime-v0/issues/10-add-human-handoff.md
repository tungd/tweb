Status: done
Title: Add Human Handoff
Type: AFK

## Parent

.scratch/agent-web-runtime-v0/PRD.md

## What to build

Implement parent-agent-driven **Human Handoff**. `/human` should reveal the same live **Hidden Session** in a functional **Handoff Window** so a human can resolve login, CAPTCHA, judgment, or other blocked interaction. Control should return only through native-window **Return Control**, not a webpage overlay.

The **Browser Subagent** may ask for direction through a **Needs Input Block**, but it must not invoke Human Handoff itself.

## Acceptance criteria

- [ ] `/human` reveals the same live browser state from the current **Agent Browser Session**.
- [ ] The **Handoff Window** contains the live web view and native **Return Control**.
- [ ] Return Control hides or releases the handoff window and returns control to the agent session.
- [ ] Return Control is outside web content and cannot be hidden by page scripts or CSS.
- [ ] The Browser Subagent cannot open Human Handoff by itself.
- [ ] Tests or manual smoke checks cover entering and returning from Human Handoff.

## Blocked by

- .scratch/agent-web-runtime-v0/issues/01-start-a-hidden-agent-browser-session.md

## Comments

- Added a Human Handoff boundary that reveals the same live browser session state through `/human`.
- Modeled the Handoff Window as containing the live web view plus Return Control in native window chrome.
- Added Return Control behavior at the handoff boundary and wired controlled CLI `/human` support.
- Browser Subagent handoff requests produce a Needs Input Block; they do not open Human Handoff directly.
- Added tests for entering handoff, native Return Control placement, returning control, and preventing subagent-initiated handoff.
