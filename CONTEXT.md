# Agent Web Runtime

A programmable browser environment for AI agents that exposes web interaction through tools instead of a human browser interface.

## Language

**Agent Web Runtime**:
A programmable browser environment exposed to AI agents through tool calls.
_Avoid_: browser, tabbed browser, web app

**Agent**:
An automated software actor that uses tools to inspect and operate the web.
_Avoid_: user, bot

**Tool**:
A callable capability exposed to an **Agent** for web navigation, inspection, extraction, or interaction.
_Avoid_: plugin, browser extension

**Agent Browser Session**:
A live, task-scoped browser process controlled by a parent **Agent** through a multi-turn stdio protocol.
_Avoid_: daemon, tab, browser window

**Browser Subagent**:
An **Agent Browser Session** that accepts high-level tasks, performs page-local work autonomously, and returns compact results.
_Avoid_: browser command shell, remote-controlled browser

**Active Page**:
The current page context a **Browser Subagent** is using to complete a task.
_Avoid_: tab

**Task Turn**:
One high-level request from a parent **Agent** that a **Browser Subagent** may satisfy with multiple internal page actions before returning a result.
_Avoid_: browser command, action step

**Debug Command**:
An explicit escape hatch for inspecting or manually controlling an **Agent Browser Session** outside the normal **Task Turn** contract.
_Avoid_: primary API

**Text Protocol**:
A stdio protocol where parent-agent inputs are plain text or slash commands and session outputs use readable XML-style blocks such as `<update>...</update>` and `<result>...</result>`.
_Avoid_: JSONL, RPC schema

**Update Block**:
A free-form **Text Protocol** message from a **Browser Subagent** that can report progress, surface uncertainty, or ask the parent **Agent** for steering.
_Avoid_: hidden reasoning transcript

**Needs Input Block**:
A **Text Protocol** message from a **Browser Subagent** that pauses the current **Task Turn** until the parent **Agent** provides steering.
_Avoid_: update, result

**Ready Block**:
A **Text Protocol** message that tells the parent **Agent** an **Agent Browser Session** can accept task turns.
_Avoid_: update

**Installed Engine**:
The state where the **In-Page Engine** is available in the **Active Page** and can receive task turns.
_Avoid_: network idle

**Engine Reinstall**:
The **Native Host** automatically installing the **In-Page Engine** again after top-level navigation.
_Avoid_: parent-agent intervention

**Page Readiness**:
Whether the **Active Page** has loaded enough content for the current task.
_Avoid_: session readiness

**Queued Steering**:
Plain-text input from the parent **Agent** during a running **Task Turn** that the **Browser Subagent** should incorporate at the next safe point.
_Avoid_: interrupt

**Interrupt Command**:
A slash command that explicitly stops the current **Task Turn** without ending the **Agent Browser Session**.
_Avoid_: queued steering

**Ephemeral Session State**:
Browser cookies, storage, and cache that are discarded when an **Agent Browser Session** ends.
_Avoid_: profile

**Persistent Profile**:
Named web identity reused across **Agent Browser Sessions** for authenticated or continuity-sensitive workflows, and not limited to one origin or domain.
_Avoid_: default session

**Profile Store**:
A persistent WebKit website data store identified by UUID and mapped to a named **Persistent Profile**.
_Avoid_: cookie export

**Manual Mode**:
A human-visible **Agent Browser Session** used to create or update a **Persistent Profile** through direct human interaction.
_Avoid_: normal agent mode

**Human Handoff**:
A parent-agent commanded transition that makes the browser window visible so a human can resolve authentication, CAPTCHA, judgment, or other blocked interaction.
_Avoid_: debug command

**Hidden Session**:
An **Agent Browser Session** whose browser state is live but not visible to a human until **Human Handoff**.
_Avoid_: headless session

**Return Control**:
An explicit native-window action that ends **Human Handoff** and returns the **Agent Browser Session** to agent control.
_Avoid_: implicit timeout, terminal done command

**Launch URL**:
An optional initial page for an **Agent Browser Session** that optimizes the first **Task Turn** but does not define the session.
_Avoid_: required target, session identity

**In-Page Engine**:
Injected page-local agent code that performs page inspection and actions inside the **Active Page**.
_Avoid_: product API

**Alibaba PageAgent**:
The specific upstream JavaScript in-page GUI agent from `alibaba/page-agent` / npm package `page-agent`, loaded by `tweb` from a pinned prebuilt CDN IIFE as the V0 **In-Page Engine**.
_Avoid_: generic PageAgent placeholder, local shim

**Main Frame**:
The top-level document frame of the **Active Page**.
_Avoid_: iframe

**Native Host**:
The local process that owns the browser view, session protocol, model calls, policy, and trace collection for an **Agent Browser Session**.
_Avoid_: page script, parent agent

**Model Configuration**:
The required `tweb` configuration that tells the **Native Host** which model endpoint to use for **Browser Subagent** reasoning.
_Avoid_: parent-agent model

**Setup Mode**:
A CLI flow for storing **Model Configuration** such as base URL, model name, and API token.
_Avoid_: manual mode

**Session Model Bridge**:
A session-scoped native bridge that lets the **In-Page Engine** request model completions without receiving the real API token.
_Avoid_: transparent request interception

**Model Turn**:
One proxied model request made by the **In-Page Engine** through the **Session Model Bridge** during an active **Task Turn**.
_Avoid_: browser step, page action

**Model Scheme**:
The logical `tweb-llm://` endpoint namespace used by PageAgent's model client for **Session Model Bridge** requests only. In WebKit V0 this is transported through PageAgent `customFetch` and a native prompt bridge, not browser `fetch` to a custom scheme.
_Avoid_: native capability bus

**Session Bridge**:
A constrained message bridge from the **In-Page Engine** to the **Native Host** for session events such as updates, results, needs-input, and trace data.
_Avoid_: arbitrary native command bridge

**Compact Evidence**:
The model-written source context included in a normal result so the parent **Agent** can evaluate trust without receiving the full page or trace.
_Avoid_: full trace, page dump

**Full Trace**:
Verbose session history used for debugging an **Agent Browser Session**.
_Avoid_: normal result

**In-Memory Trace**:
A **Full Trace** retained only while an **Agent Browser Session** is running.
_Avoid_: persisted trace

**Trace Command**:
A slash command that returns the current **In-Memory Trace** inside a `<trace>` block with JSON content.
_Avoid_: debug namespace

**Eval Command**:
A slash command that lets the parent **Agent** bypass the **Browser Subagent** and evaluate JavaScript in the **Active Page**.
_Avoid_: task turn

**Screenshot Command**:
A slash command that writes a screenshot of the **Active Page** to a requested output path.
_Avoid_: normal result

**Artifact File**:
A file produced by a slash command, such as a screenshot, and left in the system temporary directory or requested absolute path.
_Avoid_: managed artifact lifecycle

**HTML Command**:
A slash command that writes the current **Active Page** HTML to an **Artifact File** for parent-agent inspection.
_Avoid_: normal result

**Turn Memory**:
The **Browser Subagent** reasoning history for one **Task Turn**.
_Avoid_: session memory

**Semantic Session Memory**:
Automatic cross-turn summaries or facts maintained by `tweb` for the **Browser Subagent**.
_Avoid_: browser state

**Swift Host**:
The V0 **Native Host** implementation using Swift and macOS WebKit APIs.
_Avoid_: OCaml host

**macOS 14 Floor**:
The minimum V0 platform requirement chosen so `tweb` can use WebKit's named persistent data stores for **Profile Stores**.
_Avoid_: older macOS support

**Pure CLI Host**:
The V0 packaging shape where `tweb` runs directly as a command-line process rather than through a macOS app bundle.
_Avoid_: app bundle

**Handoff Window**:
A plain native window shown during **Human Handoff** that contains the live browser session and **Return Control**.
_Avoid_: product UI

## Relationships

- An **Agent** uses one or more **Tools**
- An **Agent Web Runtime** exposes **Tools** to an **Agent**
- A **Tool** may operate against one or more web pages without exposing browser tabs as the primary abstraction
- An **Agent** starts and owns an **Agent Browser Session**
- A **Browser Subagent** may navigate across multiple pages during one **Agent Browser Session**
- An **Agent Browser Session** exposes one **Active Page** by default, even if it manages additional page state internally
- An **Agent** normally communicates with a **Browser Subagent** through **Task Turns**
- A **Debug Command** may expose primitive browser operations, but it is not the primary parent-agent interface
- An **Agent Browser Session** uses a **Text Protocol** rather than structured JSON events
- A **Browser Subagent** may use **Update Blocks** during a **Task Turn** when it is stuck or needs a decision from the parent **Agent**
- While the **Native Host** proxies PageAgent model calls, long-running **Task Turns** emit periodic **Update Blocks** with the active **Model Turn** count
- A **Needs Input Block** explicitly signals that the **Browser Subagent** is waiting for parent-agent input before continuing the current **Task Turn**
- A **Ready Block** marks when an **Agent Browser Session** can accept the first **Task Turn**
- A **Ready Block** means the browser is live and the **In-Page Engine** is installed, not that the page is network-idle
- The **Browser Subagent** owns **Page Readiness** decisions during a **Task Turn**
- Top-level navigation triggers **Engine Reinstall** so the current **Task Turn** can continue
- Plain-text input during a running **Task Turn** is **Queued Steering**
- An **Interrupt Command** stops the current **Task Turn** explicitly
- An **Agent Browser Session** runs at most one active **Task Turn** at a time
- A completed **Task Turn** leaves browser state intact for follow-up turns
- **Turn Memory** resets after each **Task Turn**, even though browser state remains intact
- MVP does not maintain **Semantic Session Memory**; the parent **Agent** supplies cross-turn context
- An **Agent Browser Session** uses **Ephemeral Session State** by default
- V0 uses a **Swift Host** for native WebKit integration
- V0 requires the **macOS 14 Floor**
- V0 starts as a **Pure CLI Host**; app-bundle packaging is deferred until it is necessary
- V0 **Human Handoff** uses a functional **Handoff Window**, not a polished app UI
- A parent **Agent** must explicitly choose a **Persistent Profile** when browser state should survive across sessions
- A **Persistent Profile** maps to a UUID-backed **Profile Store**
- A human can use **Manual Mode** to authenticate or prepare a **Persistent Profile** before later agent use
- A **Browser Subagent** may use a **Needs Input Block** to ask for direction, but only the parent **Agent** can invoke **Human Handoff**
- **Human Handoff** ends only after **Return Control**
- An **Agent Browser Session** normally runs as a **Hidden Session** and becomes visible only during **Human Handoff**
- A **Launch URL** is optional and may default to `about:blank`
- The initial **In-Page Engine** is **Alibaba PageAgent**, but Alibaba PageAgent is not part of the external product contract
- MVP installs the **In-Page Engine** in the **Main Frame** only
- The **In-Page Engine** performs page-local operations while the **Native Host** owns model calls and policy
- The **Native Host** uses its own required **Model Configuration** rather than inheriting the parent **Agent** model by default
- **Setup Mode** stores required **Model Configuration** before normal **Agent Browser Sessions** run
- **Setup Mode** stores base URL, model name, and API token in a static config file so agent sessions can start without Keychain prompts
- The **In-Page Engine** reaches the model through a **Session Model Bridge**, not by holding the real API token
- The **Session Model Bridge** uses the **Model Scheme** namespace and must not become a general native capability bus
- The **In-Page Engine** uses a **Session Bridge** for session events and control messages, separate from the **Model Scheme**
- A normal **Task Turn** result includes **Compact Evidence**, while **Full Trace** is available through the **Trace Command**
- MVP keeps **Full Trace** as an **In-Memory Trace** rather than writing traces to disk automatically
- Automatic status and URL changes are emitted as **Update Blocks**
- MVP slash commands include **Trace Command**, **Eval Command**, **Screenshot Command**, and **HTML Command**
- The **Trace Command** returns inline JSON inside a `<trace>` block
- The **HTML Command** writes raw current page HTML to an **Artifact File**
- The **Eval Command** returns an inline result, JSON-serialized when possible
- The **Screenshot Command** captures the full page by default; viewport capture can be added later as an option
- Relative **Screenshot Command** output paths are treated as file names in the temporary directory
- **Artifact Files** are left behind for the system or user to clean up

## Example dialogue

> **Dev:** "Should the **Agent Web Runtime** support tabs like Chrome?"
> **Domain expert:** "No. An **Agent** needs addressable web states and efficient **Tools**, not a human browser's tab UI."

> **Dev:** "Can the **Browser Subagent** leave the original URL?"
> **Domain expert:** "Yes. Page navigation is part of the task, but the parent **Agent** should not have to manage tabs."

> **Dev:** "Should the parent **Agent** call click/type/snapshot directly?"
> **Domain expert:** "No. It should send a **Task Turn** and let the **Browser Subagent** handle page actions internally; primitive control belongs behind slash commands."

> **Dev:** "Should session output be JSONL?"
> **Domain expert:** "No. Use a **Text Protocol** with XML-style blocks like `<update>...</update>` and `<result>...</result>`; JSON adds protocol noise for the parent **Agent**."

> **Dev:** "Are updates only constrained progress events?"
> **Domain expert:** "No. An **Update Block** can be free-form because the **Browser Subagent** may need steering or decisions from the parent **Agent**."

> **Dev:** "Should questions to the parent be asked inside `<update>`?"
> **Domain expert:** "No. Use a **Needs Input Block** so the parent **Agent** can distinguish a pause from ordinary progress."

> **Dev:** "How does the parent know `tweb` is ready?"
> **Domain expert:** "The **Agent Browser Session** emits a **Ready Block** once it can accept task turns."

> **Dev:** "Does **Ready Block** mean the page is fully loaded?"
> **Domain expert:** "No. It means the **In-Page Engine** is installed and ready; modern pages may continue loading."

> **Dev:** "Should the **Native Host** wait for network idle before task turns?"
> **Domain expert:** "No. The **Browser Subagent** decides whether the **Active Page** is ready enough for the task."

> **Dev:** "Does navigation require the parent **Agent** to restart the task?"
> **Domain expert:** "No. The **Native Host** performs **Engine Reinstall** after top-level navigation and the current **Task Turn** continues."

> **Dev:** "If the parent sends text while a task is running, is that an interrupt?"
> **Domain expert:** "No. Plain text is **Queued Steering**; use an **Interrupt Command** for a hard stop."

> **Dev:** "Can one `tweb` process run concurrent tasks?"
> **Domain expert:** "No. An **Agent Browser Session** has one active **Task Turn**; use multiple sessions for parallel work."

> **Dev:** "Does a completed **Task Turn** reset the page?"
> **Domain expert:** "No. Browser state remains intact so follow-up **Task Turns** can continue from the current page."

> **Dev:** "Does the **Browser Subagent** carry reasoning history across turns?"
> **Domain expert:** "No. **Turn Memory** resets after each **Task Turn**; the parent **Agent** supplies relevant follow-up context."

> **Dev:** "Should `tweb` automatically summarize previous turns?"
> **Domain expert:** "No. MVP preserves browser state, not **Semantic Session Memory**."

> **Dev:** "Should V0 use OCaml/camlkit for the **Native Host**?"
> **Domain expert:** "No. Use a **Swift Host** because WKWebView, profiles, native window control, and the macOS event loop are first-class Swift/macOS concerns."

> **Dev:** "Should V0 support macOS older than 14?"
> **Domain expert:** "No. Use the **macOS 14 Floor** so **Profile Stores** can use WebKit's named persistent data store API."

> **Dev:** "Does V0 need a macOS app bundle?"
> **Domain expert:** "No. Start with a **Pure CLI Host** to validate the session protocol and browser-subagent loop."

> **Dev:** "Does `/human` need a full app interface?"
> **Domain expert:** "No. V0 uses a functional **Handoff Window** with the live browser session and **Return Control**."

> **Dev:** "Should `tweb https://example.co` reuse cookies from a previous run?"
> **Domain expert:** "No. Use **Ephemeral Session State** by default; require an explicit **Persistent Profile** for reuse."

> **Dev:** "Is a **Persistent Profile** scoped to one domain?"
> **Domain expert:** "No. A **Persistent Profile** is a named web identity and may span multiple domains."

> **Dev:** "How does a **Persistent Profile** map to WebKit storage?"
> **Domain expert:** "Each **Persistent Profile** maps to a UUID-backed **Profile Store**."

> **Dev:** "Is the URL required when starting `tweb`?"
> **Domain expert:** "No. A **Launch URL** is optional and only optimizes the first turn; an **Agent Browser Session** can start at `about:blank`."

> **Dev:** "How should authenticated profiles be created?"
> **Domain expert:** "Use **Manual Mode** so a human can log in and persist the **Persistent Profile**; later the parent **Agent** chooses that profile."

> **Dev:** "How does control return after **Human Handoff**?"
> **Domain expert:** "The human must use native-window **Return Control** in the visible browser window; terminal `/done` is not the primary handoff completion mechanism."

> **Dev:** "Should **Return Control** be injected into the webpage?"
> **Domain expert:** "No. **Return Control** is a native control outside web content so page scripts and CSS cannot hide or alter it."

> **Dev:** "Can the **Browser Subagent** open a human handoff itself?"
> **Domain expert:** "No. The **Browser Subagent** can ask for direction with a **Needs Input Block**, but only the parent **Agent** drives **Human Handoff**."

> **Dev:** "Does `/human` create a separate browser?"
> **Domain expert:** "No. It reveals the same **Hidden Session** so the human operates on the live browser state."

> **Dev:** "Is PageAgent the product API?"
> **Domain expert:** "No. **Alibaba PageAgent** is the initial **In-Page Engine**, but `tweb` exposes **Browser Subagent** task turns."

> **Dev:** "Should the **In-Page Engine** run in iframes?"
> **Domain expert:** "No. MVP installs the **In-Page Engine** in the **Main Frame** only."

> **Dev:** "Should injected page code call the LLM directly?"
> **Domain expert:** "No. The **Native Host** owns model calls and policy; the **In-Page Engine** owns page-local operations."

> **Dev:** "Does `tweb` use the parent **Agent** model automatically?"
> **Domain expert:** "No. `tweb` has its own required **Model Configuration** for now; bundled local models are a future option."

> **Dev:** "How does a user configure model access?"
> **Domain expert:** "Use **Setup Mode** to store base URL, model name, and API token for `tweb`."

> **Dev:** "Should API tokens be stored in the config file?"
> **Domain expert:** "Yes for V0. Agentic use needs non-interactive startup, so **Setup Mode** stores the API token with the rest of **Model Configuration** in `~/.config/tweb/model.json`."

> **Dev:** "How should PageAgent call the model in V0?"
> **Domain expert:** "Use a **Session Model Bridge** controlled by the **Native Host** so **Alibaba PageAgent** can make OpenAI-compatible requests without seeing the real API token."

> **Dev:** "How should the parent agent know a long PageAgent task is still alive?"
> **Domain expert:** "Emit periodic **Update Blocks** from the **Native Host** that report the active **Model Turn** count observed by the **Session Model Bridge**."

> **Dev:** "Should the model bridge expose general native commands?"
> **Domain expert:** "No. The **Model Scheme** namespace is only for model requests; other native capabilities need a separate bridge."

> **Dev:** "Should model requests and session events use the same bridge?"
> **Domain expert:** "No. Use the **Session Model Bridge** for model requests and a constrained **Session Bridge** for updates, results, needs-input, and traces."

> **Dev:** "Should normal results include the full session trace?"
> **Domain expert:** "No. Include **Compact Evidence** in normal results and expose **Full Trace** through the **Trace Command**."

> **Dev:** "Should traces be persisted automatically?"
> **Domain expert:** "No. MVP keeps **Full Trace** as an **In-Memory Trace** available during the session."

> **Dev:** "What slash commands are needed for MVP?"
> **Domain expert:** "Use `/trace`, `/eval`, `/screenshot <output>`, and `/html`; emit status and URL changes as **Update Blocks**."

> **Dev:** "Should `/trace` write to a file?"
> **Domain expert:** "No. The **Trace Command** returns inline JSON inside a `<trace>` block."

> **Dev:** "How should `/eval` return values?"
> **Domain expert:** "The **Eval Command** returns an inline result, JSON-serialized when possible."

> **Dev:** "Should `/html` return PageAgent's simplified DOM?"
> **Domain expert:** "No. The **HTML Command** returns raw current page HTML."

> **Dev:** "Should `/html` write raw HTML inline to stdout?"
> **Domain expert:** "No. The **HTML Command** writes raw current page HTML to an **Artifact File**."

> **Dev:** "Should `/screenshot` capture only the current viewport?"
> **Domain expert:** "No. The **Screenshot Command** captures the full page by default; viewport capture can be added later."

> **Dev:** "How should relative screenshot output paths be resolved?"
> **Domain expert:** "Treat relative screenshot paths as file names in the temporary directory, not as repo-relative paths."

> **Dev:** "Should `tweb` manage artifact cleanup?"
> **Domain expert:** "No. Use the system temporary directory primitive and leave **Artifact Files** behind."

## Flagged ambiguities

- "web tool" was narrowed to **Agent Web Runtime**, not a general human-facing browser or website builder.
- "session" was resolved as **Agent Browser Session**, a foreground multi-turn stdio process rather than a background daemon.
- Primitive browser actions were resolved as direct slash commands, not the normal **Task Turn** interface.
- Output framing was resolved as a **Text Protocol**, not JSONL.
- "headless" should be avoided for V0; the resolved term is **Hidden Session** because the browser is live but normally not visible.
- High-impact action confirmation is intentionally out of scope for MVP, even though **Persistent Profiles** make it a future safety concern.
- **Engine Reinstall** failure is recoverable by default and should produce an `<error>` unless the whole **Agent Browser Session** is unusable.
