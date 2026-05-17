# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- `CONTEXT.md` at the repo root, or
- `CONTEXT-MAP.md` at the repo root if it exists, then read the context files relevant to the topic.
- `docs/adr/` for architectural decisions that touch the area being changed.

If any of these files don't exist, proceed silently. The producer skill creates them lazily when terms or decisions are resolved.

## Layout

This repo currently uses a single context:

- Root `CONTEXT.md`
- Root `docs/adr/`

## Use the glossary's vocabulary

When output names a domain concept, use the term as defined in `CONTEXT.md`. Avoid synonyms the glossary explicitly rejects.

## Flag ADR conflicts

If output contradicts an ADR, surface the conflict explicitly rather than silently overriding it.
