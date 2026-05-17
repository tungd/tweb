# PageAgent Runtime

The Native Host downloads and caches the reviewed prebuilt Alibaba PageAgent IIFE from the pinned jsDelivr URL:

```text
https://cdn.jsdelivr.net/npm/page-agent@1.8.2/dist/iife/page-agent.demo.js?autoInit=false
```

The small `tweb` adapter is embedded in `PageAgentBundle` so a bare copied CLI executable does not depend on SwiftPM resource bundles at runtime. The adapter creates `window.__twebPageAgent`, calls Alibaba PageAgent's `agent.execute(...)` API, and configures model calls through PageAgent `customFetch` plus the `tweb-llm://model/v1` namespace.

The upstream package is MIT licensed; keep `LICENSE.page-agent` with the pinned dependency.

Update convention:

1. Pick the reviewed npm version of `page-agent`.
2. Update the CDN/version references in `PageAgentBundle`, this README, and ADR-0003.
3. Review upstream release notes and the prebuilt IIFE before changing the pinned version.
4. Rerun the in-page engine and task-turn tests.

The external `tweb` Text Protocol must remain Browser Subagent Task Turns and slash commands. PageAgent globals are an implementation detail inside the Active Page.
