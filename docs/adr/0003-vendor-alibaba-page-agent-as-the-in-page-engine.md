# Use Alibaba PageAgent as the V0 in-page engine

V0 uses Alibaba PageAgent (`alibaba/page-agent`, npm package `page-agent`) as the concrete **In-Page Engine**. `tweb` loads the reviewed prebuilt IIFE from a pinned CDN URL rather than rebuilding PageAgent locally or using a placeholder shim.

The current pinned runtime URL is:

```text
https://cdn.jsdelivr.net/npm/page-agent@1.8.2/dist/iife/page-agent.demo.js?autoInit=false
```

`tweb` fetches and caches the pinned PageAgent IIFE in the Native Host, then injects the prebuilt IIFE plus a small adapter into the main frame as a WebKit user script. Native fetching keeps the CDN artifact as the source of truth while avoiding page Content Security Policy blocking a dynamically appended CDN `<script>`. The adapter exposes `window.__twebPageAgent.runTwebTask(...)` for the native task runner, creates `new window.PageAgent(...)`, calls `agent.execute(task)`, maps PageAgent's `ExecutionResult` into a `TaskTurnResult`, and configures PageAgent's OpenAI-compatible model calls through PageAgent's `customFetch` hook.

The model transport deliberately does not rely on `fetch("tweb-llm://...")` from page JavaScript. WebKit rejects `fetch` to that custom scheme from an HTTPS page with `TypeError: Load failed`, even when the Native Host registers a `WKURLSchemeHandler`. Instead, the adapter's `customFetch` calls a private `window.prompt("__tweb_model_request__", payload)` bridge. `WebKitBrowserSession` handles that prompt through `WKUIDelegate`, forwards the request through `SessionModelBridge`, injects the configured API token natively, and returns a Response-compatible JSON payload to PageAgent. This keeps model calls off the page network stack while preserving PageAgent's expected OpenAI-compatible client path.

Because every PageAgent model request crosses `SessionModelBridge`, the Native Host counts those proxied requests as **Model Turns** for the active **Task Turn**. Long-running PageAgent tasks emit periodic `<update>` blocks, currently every five seconds, in the form `PageAgent task running: N model turns`. This gives the parent agent liveness without exposing the prompt, token, or model response payloads.

The Native Host remains responsible for model configuration, API-token injection, profile state, WebKit lifecycle, and the parent-agent Text Protocol. Alibaba PageAgent remains an implementation detail behind **Task Turns** rather than becoming the external `tweb` protocol.

Rejected alternatives:

- A local placeholder or shim is not acceptable because it does not exercise the real PageAgent control loop.
- Rebuilding PageAgent from npm during the Swift build is not acceptable for V0 because it adds a Node build chain to the native host before the browser-session loop has been proven.
- Appending a CDN `<script>` from inside the page is not acceptable because strict page Content Security Policy can block it before readiness.
- Evaluating the full IIFE through ad hoc `/eval`-style JavaScript is not acceptable because WebKit can fail to return from the large JavaScript evaluation, leaving the CLI wedged before readiness.
- Routing model calls through a `WKURLSchemeHandler` custom scheme is not acceptable because WebKit page JavaScript cannot reliably `fetch` that scheme from real HTTPS pages.
- Silent long-running PageAgent tasks are not acceptable because the parent agent needs progress signals while the Native Host is proxying model calls.
