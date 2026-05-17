Status: done
Title: V0 Agent Web Runtime

## Problem Statement

Coding agents need to use the web, but existing browser tooling makes them micromanage browser primitives. Chrome, Safari, and Firefox expose human browser concepts like tabs and windows. Playwright-style tools expose low-level observe/click/type loops and can be token-heavy, especially when page state must be repeatedly dumped back to the parent agent.

The user wants `tweb` to provide an **Agent Web Runtime**: a task-scoped, hidden browser process that a parent **Agent** can drive as a **Browser Subagent** over stdin/stdout. The parent agent should send high-level **Task Turns**, while the Browser Subagent performs page-local inspection and actions autonomously, returns compact results, and preserves browser state across turns.

## Solution

Build a macOS 14+ Swift Package executable named `tweb` that hosts a WebKit-backed **Agent Browser Session**. The process starts from an optional **Launch URL**, installs an **In-Page Engine** based on PageAgent in the **Main Frame**, and communicates through a plain **Text Protocol**.

The normal interface is high-level text task turns. Slash commands provide explicit escape hatches for trace inspection, JavaScript evaluation, screenshots, raw HTML artifact capture, human handoff, interruption, and quitting. The session is a **Hidden Session** by default and can reveal the same live browser state through a native **Handoff Window** when the parent agent invokes `/human`.

The **Native Host** owns model configuration, secrets, profile storage, WebKit lifecycle, trace collection, and policy. PageAgent can be the initial **In-Page Engine**, but it is not the product API. PageAgent reaches the configured OpenAI-compatible model through a session-scoped `tweb-llm://` **Model Scheme**, implemented by the Native Host so the real API token never enters the page.

## User Stories

1. As a coding agent, I want to start `tweb` with no URL, so that I can create an Agent Browser Session from `about:blank`.
2. As a coding agent, I want to start `tweb` with a Launch URL, so that the first Task Turn can begin from the relevant page.
3. As a coding agent, I want `tweb` to emit a Ready Block, so that I know when the session can accept task turns.
4. As a coding agent, I want to send plain-text Task Turns, so that I can delegate web work without constructing JSON or browser commands.
5. As a coding agent, I want a Browser Subagent to complete multiple internal page actions per Task Turn, so that I avoid observe/click/type micromanagement.
6. As a coding agent, I want the Browser Subagent to navigate across pages during a task, so that it can follow links and complete realistic web workflows.
7. As a coding agent, I want completed Task Turns to leave browser state intact, so that follow-up turns can continue from the current page.
8. As a coding agent, I want Turn Memory to reset after each Task Turn, so that hidden reasoning history does not grow across the session.
9. As a coding agent, I want to provide cross-turn context myself, so that semantic memory remains explicit and debuggable.
10. As a coding agent, I want status and URL changes emitted as Update Blocks, so that I can track what the session is doing.
11. As a coding agent, I want free-form Update Blocks, so that the Browser Subagent can explain progress or uncertainty.
12. As a coding agent, I want Needs Input Blocks, so that I can distinguish ordinary progress from a paused task needing direction.
13. As a coding agent, I want plain text sent during a running task to become Queued Steering, so that I can correct direction without hard-stopping the task.
14. As a coding agent, I want an Interrupt Command, so that I can explicitly stop the current Task Turn while keeping the session alive.
15. As a coding agent, I want one active Task Turn per Agent Browser Session, so that navigation and control semantics stay predictable.
16. As a coding agent, I want to run multiple `tweb` processes for parallelism, so that independent browser work does not conflict.
17. As a coding agent, I want normal results to include model-written Compact Evidence, so that I can judge the answer without receiving full page dumps.
18. As a coding agent, I want `/trace` to return an inline JSON Full Trace, so that I can debug the current session when needed.
19. As a coding agent, I want traces to be in memory only for MVP, so that sensitive page data is not persisted automatically.
20. As a coding agent, I want `/eval` to evaluate JavaScript in the Active Page, so that I can bypass the Browser Subagent when necessary.
21. As a coding agent, I want `/eval` results to be inline and JSON-serialized when possible, so that small inspections are easy to consume.
22. As a coding agent doing frontend work, I want `/screenshot` to write a full-page screenshot artifact, so that I can inspect visual output.
23. As a coding agent doing frontend work, I want relative screenshot paths treated as temp-file names, so that I do not accidentally write into the repo.
24. As a coding agent doing frontend work, I want `/html` to write raw current page HTML to an artifact file, so that I can inspect markup without XML-framing problems.
25. As a coding agent, I want artifact files left behind, so that I can inspect them after the session command returns.
26. As a coding agent, I want `/quit` to end the Agent Browser Session, so that I can cleanly release WebKit and session resources.
27. As a coding agent, I want `/human` to reveal the Hidden Session, so that a human can resolve login, CAPTCHA, or judgment-heavy interactions.
28. As a human operator, I want Human Handoff to show the same live browser state, so that I do not lose context when taking over.
29. As a human operator, I want Return Control to be a native control outside the webpage, so that page scripts cannot hide or alter it.
30. As a human operator, I want Manual Mode for a Persistent Profile, so that I can log in once and persist credentials/cookies for later agent sessions.
31. As a coding agent, I want to select a named Persistent Profile, so that authenticated workflows can reuse a prepared web identity.
32. As a coding agent, I want Ephemeral Session State by default, so that unrelated tasks do not leak cookies or storage into each other.
33. As a user, I want Persistent Profiles to map to WebKit Profile Stores, so that named profiles are isolated by WebKit storage rather than ad hoc cookie copying.
34. As a user, I want Persistent Profiles to be arbitrary named web identities, so that one profile can span multiple domains in a realistic workflow.
35. As a user, I want `tweb --setup` to store model configuration, so that normal sessions can run without prompting.
36. As a user, I want API tokens stored in the platform Secret Store, so that secrets do not live in plaintext config files.
37. As a user, I want non-secret model configuration stored locally, so that `tweb` can find the base URL and model name.
38. As a Browser Subagent, I want model calls routed through the Session Model Bridge, so that I can use PageAgent without seeing the real API token.
39. As a Native Host, I want to expose the Model Scheme only for model requests, so that it does not become a general native capability bus.
40. As a Native Host, I want session events on a constrained Session Bridge, so that updates, results, needs-input, and traces are separated from model traffic.
41. As a Native Host, I want to reinstall the In-Page Engine after top-level navigation, so that the current Task Turn can continue after page changes.
42. As a Native Host, I want Ready Block to mean the In-Page Engine is installed, so that readiness does not depend on fuzzy network-idle behavior.
43. As a Browser Subagent, I want to own Page Readiness decisions, so that task-specific waiting happens inside the page-local loop.
44. As a developer, I want V0 implemented as a Pure CLI Host, so that the first prototype validates the session protocol without app-bundle packaging.
45. As a developer, I want V0 implemented with Swift, so that WebKit, Keychain, profile stores, windows, and event-loop concerns use native APIs.
46. As a developer, I want V0 to require macOS 14, so that named Persistent Profiles can use WebKit's UUID-backed Profile Stores.
47. As a developer, I want PageAgent treated as the initial In-Page Engine rather than the product API, so that the external contract can survive PageAgent changes.
48. As a developer, I want the In-Page Engine installed in the Main Frame only for MVP, so that iframe support does not block the first useful slice.
49. As a developer, I want Engine Reinstall failures to be recoverable errors, so that the parent agent can decide whether to navigate, use `/human`, or quit.
50. As a developer, I want missing model configuration to fail normal sessions early, so that the Browser Subagent does not start half-functional.

## Implementation Decisions

- Build V0 as a Swift Package executable with a Pure CLI Host.
- Require macOS 14 for V0 because WebKit named persistent data stores are central to Persistent Profiles.
- Use Swift for the Native Host because the core risk is WebKit integration, Keychain access, native windows, and the macOS run loop.
- Keep app-bundle packaging out of V0 unless Pure CLI hosting proves impossible.
- Implement an Agent Browser Session that reads stdin and writes stdout while owning one live WKWebView-backed Hidden Session.
- Treat the optional Launch URL as a first-turn optimization only; default startup is `about:blank`.
- Emit a Ready Block once the browser is live and the In-Page Engine is installed.
- Use a Text Protocol with XML-style blocks for ready, update, needs-input, result, error, fatal, and trace output.
- Keep normal parent-agent input as plain-text Task Turns plus slash commands.
- Use high-level Task Turns as the primary interface. Primitive browser operations are not the normal interface.
- Support one active Task Turn per session. Plain text during a running turn is Queued Steering. `/interrupt` explicitly stops the turn.
- Preserve browser state across completed Task Turns, but reset Turn Memory after each turn.
- Do not maintain Semantic Session Memory in MVP.
- Use PageAgent as the initial In-Page Engine, but keep the `tweb` public contract independent from PageAgent.
- Vendor the PageAgent bundle for V0 rather than requiring a live npm build step in the first implementation path.
- Install the In-Page Engine in the Main Frame only for MVP.
- Automatically reinstall the In-Page Engine after top-level navigation.
- Let the Browser Subagent decide Page Readiness instead of using Native Host network-idle heuristics.
- Route model traffic through a Session Model Bridge using the `tweb-llm://` Model Scheme.
- Keep the Model Scheme model-only. Use a separate constrained Session Bridge for updates, results, needs-input, and trace data.
- Store model base URL and model name in local config. Store API tokens in the platform Secret Store.
- Add Setup Mode for model configuration: base URL, model name, and API token.
- Use OpenAI-compatible chat completions as the first model interface because PageAgent already expects that shape.
- Default to Ephemeral Session State when no profile is selected.
- Map each named Persistent Profile to a UUID-backed WebKit Profile Store.
- Support Manual Mode for creating or updating a Persistent Profile through human login.
- Implement Human Handoff as parent-agent driven only. The Browser Subagent may ask for direction with a Needs Input Block but cannot invoke handoff itself.
- Implement Human Handoff by revealing the same Hidden Session in a functional native Handoff Window.
- Put Return Control in native window chrome outside web content.
- Keep high-impact action confirmation out of MVP.
- Keep Full Trace in memory only for MVP.
- Return normal Task Turn results with model-written Compact Evidence.
- Implement `/trace` as inline JSON inside a trace block.
- Implement `/eval` as JavaScript evaluation against the Active Page, with inline JSON-serialized results where possible.
- Implement `/screenshot` as a full-page screenshot command. Relative output names resolve through the system temporary directory.
- Implement `/html` as a raw HTML artifact writer, not inline stdout.
- Leave Artifact Files behind for the system or user to clean up.
- Treat Engine Reinstall failure as recoverable unless the whole Agent Browser Session is unusable.

Major modules to build:

- CLI entrypoint and argument parser for normal mode, setup mode, manual mode, profile selection, launch URL, and slash-command session control.
- Session coordinator that owns the Agent Browser Session state machine, stdin/stdout protocol, active task lifecycle, queued steering, interruption, and shutdown.
- Text Protocol parser/renderer that handles XML-style blocks and slash command dispatch.
- WebSession module that owns WKWebView, Hidden Session lifecycle, launch navigation, URL/status update emission, Human Handoff visibility, Handoff Window, and Return Control.
- Profile registry that maps Persistent Profile names to WebKit Profile Store UUIDs.
- Config and Secret Store module that handles model configuration and macOS Keychain storage.
- In-Page Engine installer that injects PageAgent, verifies Installed Engine readiness, and performs Engine Reinstall after navigation.
- Session Model Bridge that handles `tweb-llm://` requests and forwards them to the configured model endpoint with the real API token.
- Session Bridge that accepts constrained messages from the In-Page Engine and turns them into protocol output or trace entries.
- Task runner that starts PageAgent task execution, maps PageAgent completion to result blocks, handles needs-input, and resets Turn Memory per Task Turn.
- Trace store that keeps in-memory trace data and renders `/trace` JSON.
- Artifact writer that produces screenshot and HTML artifact files through system temp primitives or requested absolute paths.
- Slash command handler for `/trace`, `/eval`, `/screenshot`, `/html`, `/human`, `/interrupt`, and `/quit`.

## Testing Decisions

- Tests should assert external behavior and stable module contracts, not WebKit implementation details.
- The Text Protocol parser/renderer should have focused unit tests for task input, slash commands, XML-style output blocks, ready/update/result/error/fatal rendering, and trace rendering.
- The session coordinator should have state-machine tests for ready, running, queued steering, needs-input, interrupt, result, error, and quit behavior.
- The profile registry should have tests for creating, looking up, and reusing profile-name to UUID mappings.
- The config and Secret Store boundary should have tests using a fake secret backend, so tests do not depend on the real Keychain.
- The Session Model Bridge should have tests with fake OpenAI-compatible requests and responses, including auth forwarding, model name preservation, and rejection of non-model paths.
- The slash command handler should have tests for `/trace`, `/eval`, `/screenshot`, `/html`, `/human`, `/interrupt`, and `/quit` dispatch behavior.
- The artifact writer should have tests for absolute paths, relative names resolved through the system temporary directory, and leave-behind semantics.
- The task runner should have tests around one-active-task enforcement, Turn Memory reset, and browser-state continuity at the coordinator boundary.
- WebKit integration should initially be covered by manual smoke tests or focused integration tests because the repo has no existing UI/runtime test harness.
- Good tests for this project should simulate page-agent and model boundaries with fakes where possible, reserving real WKWebView tests for end-to-end confidence.
- There is no prior test suite in the current repo, so initial tests should establish conventions rather than conform to existing examples.

## Out of Scope

- Linux, Windows, iOS, and macOS versions older than 14.
- App bundle packaging, polished Dock/menu behavior, signing, notarization, and distribution.
- OCaml/camlkit implementation for V0.
- A daemon or global background browser service.
- JSONL or RPC-style parent-agent protocol.
- Tabs as a parent-agent abstraction.
- Concurrent tasks inside one Agent Browser Session.
- Cross-turn semantic summaries maintained by `tweb`.
- Iframe injection and multi-frame PageAgent support.
- General browser automation primitives as the primary interface.
- High-impact action confirmation policy.
- Persisted trace storage or automatic trace export.
- Screenshot viewport mode and custom viewport sizing.
- Validated citations or grounded evidence enforcement.
- Bundled local models through llama.cpp or MLX.
- Provider-specific model adapters beyond OpenAI-compatible chat completions.
- A general native capability bus exposed through the Model Scheme.
- Full replacement of PageAgent internals.

## Further Notes

- ADR-0001 records the macOS 14 requirement for profile storage.
- ADR-0002 records the Swift Host decision for V0.
- The first implementation slice should prove the end-to-end loop: launch `tweb`, create a hidden WKWebView, install a minimal in-page engine, emit Ready Block, accept one Task Turn, perform a model-backed PageAgent step through the Model Scheme, and return a Result Block.
- PageAgent packaging is resolved for V0 as a vendored bundle.
- The Pure CLI Host may still need AppKit initialization and a macOS run loop; that does not change the external CLI-first product contract.

## Comments

- Implemented across issues 01-12 with focused TDD slices and small logical commits.
- Added the Swift Package executable/library, Text Protocol, session lifecycle, inspection slash commands, setup/config storage, model bridge, vendored in-page engine, task turns, lifecycle semantics, navigation reinstall, profiles/manual mode, human handoff, smoke workflow, and normalized error paths.
- Verification is covered by issue-specific XCTest suites plus `scripts/smoke-v0.sh`.
