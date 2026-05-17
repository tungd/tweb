# tweb

`tweb` is an **Agent Web Runtime**: a programmable WebKit browser session exposed to coding agents through a stdin/stdout CLI.

The parent agent sends high-level **Task Turns**. `tweb` owns the browser process, page state, model bridge, profiles, trace collection, inspection commands, and human handoff.

## Status

V0 is a macOS 14+ Swift CLI. It is intended for agent use, not as a human browser UI.

## Requirements

- macOS 14 or newer
- Swift toolchain / Xcode command line tools
- `~/.local/bin` on `PATH` if installing locally
- An OpenAI-compatible model endpoint for normal model-backed sessions

## Build and install

From the repo root:

```sh
swift build -c release
mkdir -p ~/.local/bin
cp -f .build/release/tweb ~/.local/bin/tweb
```

Confirm your shell can find it:

```sh
which tweb
```

## Human setup

Configure model access before normal model-backed sessions:

```sh
tweb --setup --base-url https://api.openai.com --model MODEL_NAME --api-token API_TOKEN
```

`tweb` stores model configuration, including the API token, in `~/.config/tweb/model.json` so agent sessions can start non-interactively.

Prepare a named browser identity when agents need authenticated continuity:

```sh
tweb --manual --profile work
```

Manual Mode opens a human-visible session for login or account setup. Later agent sessions can reuse that web identity:

```sh
tweb --profile work https://example.com
```

Default sessions use ephemeral browser state:

```sh
tweb https://example.com
```

## Agent usage

Start an Agent Browser Session:

```sh
tweb https://example.com
```

Wait for:

```text
<ready>
url: https://example.com
</ready>
```

Then send a plain-text Task Turn:

```text
Find the pricing page and summarize the paid plans.
```

The session emits Text Protocol blocks:

- `<ready>` means the session can accept Task Turns.
- `<update>` reports status, URL changes, progress, or uncertainty.
- During long PageAgent Task Turns, `<update>` includes the proxied model-turn count every few seconds.
- `<needs-input>` means the active Task Turn needs parent-agent steering.
- `<result>` completes a Task Turn or slash command.
- `<trace>` returns the current in-memory trace as JSON.
- `<error>` is recoverable unless the session stops responding.
- `<fatal>` means the process cannot continue.

## Slash commands

Use slash commands as explicit escape hatches:

```text
/trace
/eval document.title
/screenshot page.png
/html page.html
/human
/interrupt
/quit
```

Notes:

- `/screenshot` writes a full-page screenshot artifact.
- `/html` writes raw current-page HTML as an artifact.
- Relative artifact paths are treated as file names in the system temporary directory.
- `/human` reveals the same live hidden session in a native handoff window.
- `/interrupt` stops the current Task Turn but keeps the session alive.
- `/quit` exits cleanly.

## Install the agent skill

This repo includes a reusable agent skill at:

```text
skills/tweb-cli/SKILL.md
```

Install it by copying the `skills/tweb-cli` directory into your agent's skills directory.

Examples:

```sh
cp -R skills/tweb-cli ~/.codex/skills/
cp -R skills/tweb-cli ~/.claude/skills/
cp -R skills/tweb-cli ~/.config/opencode/skills/
cp -R skills/tweb-cli ~/.vibe/skills/
cp -R skills/tweb-cli ~/.pi/agent/skills/
```

After installation, agents can invoke the skill as `$tweb-cli` or discover it when they need to operate the installed `tweb` CLI.

## Smoke workflow

A deterministic local smoke workflow is available:

```sh
bash scripts/smoke-v0.sh
```

The smoke workflow builds `tweb`, starts a controlled session, waits for `<ready>`, sends a Task Turn, verifies `<result>`, verifies `/trace`, writes an HTML artifact, and quits.

## Domain docs

Project vocabulary and architectural decisions live in:

- `CONTEXT.md`
- `docs/adr/`
- `.scratch/agent-web-runtime-v0/PRD.md`
