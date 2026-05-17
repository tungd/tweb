Status: done
Title: Bridge PageAgent Model Calls Through tweb-llm
Type: AFK

## Parent

.scratch/agent-web-runtime-v0/PRD.md

## What to build

Implement the **Session Model Bridge** using the `tweb-llm://` **Model Scheme**. The **In-Page Engine** should be able to make OpenAI-compatible chat completions requests through this scheme without receiving the real API token.

The **Native Host** should validate the request shape, read the real API token from the **Secret Store**, forward the request to the configured model endpoint, and return an OpenAI-compatible response. The **Model Scheme** must remain model-only and must not become a general native capability bus.

## Acceptance criteria

- [ ] The custom WebKit URL scheme accepts model requests at the expected chat completions path.
- [ ] The bridge forwards OpenAI-compatible request bodies to the configured model endpoint.
- [ ] The real API token is injected by the **Native Host**, not exposed to the page.
- [ ] Non-model paths or unsupported methods are rejected.
- [ ] Forwarded responses preserve the OpenAI-compatible response shape expected by PageAgent.
- [ ] Tests cover request validation, auth forwarding, path rejection, and response forwarding with a fake model endpoint.

## Blocked by

- .scratch/agent-web-runtime-v0/issues/03-implement-model-configuration-and-secret-storage.md

## Comments

- Added a Session Model Bridge for `tweb-llm://` model requests at `/v1/chat/completions`.
- The bridge validates method/path, rejects non-model paths, loads the real token from Native Host configuration, and forwards the original OpenAI-compatible body.
- Native auth is injected as an upstream Authorization header; the page-supplied request body never receives the token.
- Added the executable WKURLSchemeHandler wiring for the `tweb-llm` Model Scheme.
- Added a fakeable HTTP client boundary and tests for validation, auth forwarding, path rejection, method rejection, and response forwarding.
