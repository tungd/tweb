---
name: tweb-cli
description: Use the installed tweb Agent Web Runtime CLI as a parent agent. Use when an agent needs to start or control a tweb Agent Browser Session, send Task Turns, parse Text Protocol blocks, use slash commands such as /trace, /eval, /screenshot, /html, /human, /interrupt, or /quit, select Persistent Profiles, prepare Manual Mode sessions, or handle tweb errors and artifacts.
---

# tweb CLI

Use this skill to operate the installed `tweb` command as an **Agent Web Runtime**. Assume `tweb` is available on `PATH`, typically from `~/.local/bin/tweb`.

Do not treat `tweb` as a human browser, a Playwright replacement API, or a source-build task. This skill is for using the CLI surface from another agent.

## Mental model

- `tweb` starts an **Agent Browser Session** controlled through stdin/stdout.
- The parent **Agent** sends plain-text **Task Turns** for normal work.
- The **Browser Subagent** performs page-local inspection and actions internally.
- Slash commands are escape hatches for inspection, artifacts, handoff, interruption, and shutdown.
- The **Active Page** persists across completed Task Turns.
- **Turn Memory** does not persist; include needed cross-turn context in follow-up Task Turns.
- One **Agent Browser Session** runs at most one active Task Turn at a time.

## Starting a session

Start from `about:blank`:

```sh
tweb
```

Start with a **Launch URL**:

```sh
tweb https://example.com
```

Use a named **Persistent Profile** when web identity should survive across sessions:

```sh
tweb --profile work https://example.com
```

Use **Manual Mode** to let a human prepare or update a Persistent Profile:

```sh
tweb --manual --profile work
```

## Text Protocol output

`tweb` writes readable XML-style blocks. Parse by block tag, not by line position.

```text
<ready>
url: https://example.com
</ready>
```

Block meanings:

- `<ready>` means the **Agent Browser Session** can accept Task Turns; it does not mean the page is network-idle.
- `<update>` reports status, URL changes, progress, or uncertainty.
- `<needs-input>` means the current Task Turn is paused and needs parent-agent steering.
- `<result>` completes a Task Turn or slash command.
- `<trace>` returns the current **In-Memory Trace** as JSON.
- `<error>` is recoverable unless follow-up output proves otherwise.
- `<fatal>` means the session cannot continue; start a new session after fixing the cause.

## Sending Task Turns

Send one plain-text instruction per Task Turn:

```text
Find the current pricing for ExampleCo Pro and summarize the plan limits.
```

Good Task Turns:

- State the goal, not browser primitives.
- Include relevant cross-turn context explicitly.
- Ask for compact, source-aware results when evidence matters.
- Let the Browser Subagent decide Page Readiness.

Avoid:

- Micromanaging with click/type/selector steps unless debugging.
- Assuming tabs are part of the public abstraction.
- Starting another Task Turn while one is already running.

If you send plain text while a Task Turn is running, it becomes **Queued Steering**:

```text
Prefer official docs over blog posts.
```

If `<needs-input>` appears, answer with plain text steering to resume the same Task Turn.

## Slash commands

Use slash commands only when you need an explicit escape hatch.

```text
/trace
/eval document.title
/screenshot page.png
/html page.html
/human
/interrupt
/quit
```

Command behavior:

- `/trace` returns a `<trace>` block with JSON for the current session.
- `/eval <javascript>` evaluates JavaScript in the Active Page and returns an inline `<result>`.
- `/screenshot <output>` writes a full-page screenshot Artifact File and returns its absolute path.
- `/html <output>` writes raw current-page HTML to an Artifact File and returns its absolute path.
- `/human` reveals the same live Hidden Session in a native Handoff Window.
- `/interrupt` stops the current Task Turn but keeps the Agent Browser Session alive.
- `/quit` ends the Agent Browser Session.

Artifact path rule:

- Absolute output paths are preserved.
- Relative output paths are treated as file names in the system temporary directory, not as repo-relative paths.

## Human Handoff

Use `/human` when authentication, CAPTCHA, payment, judgment-heavy UI, or blocked interaction requires a human.

Important constraints:

- The Browser Subagent cannot open Human Handoff by itself.
- It may request handoff with `<needs-input>`.
- The parent Agent must invoke `/human`.
- Return Control is native window UI, not webpage content.

## Profiles and session state

Default behavior is **Ephemeral Session State**:

```sh
tweb https://example.com
```

Use a **Persistent Profile** only when continuity is required:

```sh
tweb --profile personal-mail https://mail.example.com
```

Persistent Profiles are named web identities backed by WebKit Profile Stores. They are not domain-scoped cookie exports.

## Model configuration failures

A normal model-backed session may fail early if **Model Configuration** is missing:

```text
<fatal>
missing model configuration: base URL, model name, API token
</fatal>
```

In that case, ask the user whether to configure `tweb` or use an existing configured environment. Do not invent credentials.

## Error handling

- Treat `<fatal>` as terminal for that process.
- Treat `<error>` as recoverable unless the session stops responding.
- After recoverable errors, you may send another Task Turn, inspect with `/trace`, use `/human`, or quit.
- Engine reinstall failures after navigation are usually recoverable.
- Malformed slash commands produce recoverable errors; correct the command and continue.

## Recommended parent-agent loop

1. Start `tweb` with an optional Launch URL and optional Persistent Profile.
2. Wait for `<ready>`.
3. Send a high-level Task Turn.
4. Read `<update>` blocks and only steer when useful.
5. If `<needs-input>` appears, provide plain-text steering or use `/human` when appropriate.
6. Use `/trace`, `/eval`, `/screenshot`, or `/html` for debugging and artifacts.
7. Read `<result>` and carry any needed cross-turn context yourself.
8. Send `/quit` when finished.
