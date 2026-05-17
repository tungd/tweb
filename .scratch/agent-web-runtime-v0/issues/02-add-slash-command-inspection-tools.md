Status: done
Title: Add Slash Command Inspection Tools
Type: AFK

## Parent

.scratch/agent-web-runtime-v0/PRD.md

## What to build

Add the first parent-agent inspection slash commands for the current **Active Page**: `/trace`, `/eval`, `/screenshot`, and `/html`. These commands let the parent **Agent** inspect the **Agent Browser Session** without making primitive browser actions the primary interface.

`/trace` should return inline JSON in a `<trace>` block. `/eval` should evaluate JavaScript and return an inline result, JSON-serialized when possible. `/screenshot` should write a full-page screenshot **Artifact File**. `/html` should write raw current page HTML to an **Artifact File**.

## Acceptance criteria

- [ ] `/trace` returns the current **In-Memory Trace** as inline JSON inside a `<trace>` block.
- [ ] `/eval` evaluates JavaScript against the **Active Page** and returns an inline result.
- [ ] `/screenshot <output>` writes a full-page screenshot.
- [ ] Relative screenshot output paths are treated as temp-file names, not repo-relative paths.
- [ ] `/html` writes raw current page HTML to an artifact file.
- [ ] Artifact files are left behind and the absolute output path is reported.
- [ ] Tests cover slash command parsing, artifact path resolution, and command result rendering with fakes where WebKit is not required.

## Blocked by

- .scratch/agent-web-runtime-v0/issues/01-start-a-hidden-agent-browser-session.md

## Comments

- Added slash command parsing for `/trace`, `/eval`, `/screenshot`, `/html`, and `/quit`.
- Added an in-memory trace store, JSON-like eval values, full-page screenshot capture mode, and local artifact writing.
- Relative artifact names resolve beneath the system temp directory; absolute artifact paths are preserved.
- Wired the controlled CLI session to support inspection commands through the same stdin/stdout Text Protocol.
- Added tests covering command parsing, trace rendering, eval rendering, artifact path resolution, and screenshot/HTML artifact writing.
