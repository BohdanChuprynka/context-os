# Context OS

This folder is {{OWNER_NAME}}'s personal context database: a set of small Obsidian vaults that AI agents (Claude Code, Codex, or any tool that reads files) consult before answering.

Mission:

> Give the model the best possible context about {{OWNER_NAME}} (identity, current state, preferences, projects, goals) so every answer can be personalized without re-explaining.

It is a persona model, not an archive. Do not ingest commit logs, shell history, browser history, or generic work output. When anything below conflicts with that principle, the principle wins.

## Vaults

Each vault is an independent folder with its own schema. **Read `<vault>/CLAUDE.md` before reading or writing inside it.**

| Vault | Domain |
|-------|--------|
{{VAULT_TABLE}}

## Routing

When a question touches the owner (identity, preferences, goals, projects, health, setup, work), read this file, pick the matching vault from the table, open `<vault>/wiki/index.md`, then read only the smallest set of relevant pages. Cite what you used. If no page covers it, say so instead of guessing.

## Shared vault anatomy

```
<vault>/CLAUDE.md        schema + operations for this vault. The contract.
<vault>/AGENTS.md        symlink to CLAUDE.md so Codex reads the same contract.
<vault>/raw/             source documents waiting to be ingested. Read, never modify.
<vault>/raw/completed/   sources already ingested.
<vault>/wiki/            AI-maintained markdown pages, one page per concept.
<vault>/wiki/index.md    catalog of every page, by category.
<vault>/wiki/log.md      chronological record of ingests, updates, queries, audits.
```

`_vault-template/` is the blank vault used to add a new one. It is not a vault.

## Operations

- **Ingest**: `raw/` source, discuss with the owner, write or update `wiki/` pages, update `wiki/index.md`, append `wiki/log.md`, move the source to `raw/completed/`. Queries and audits never authorize an ingest.
- **Query**: read `wiki/index.md`, read the smallest relevant set of pages, answer with `[[wikilinks]]` inside a vault and plain paths across vaults.
- **Audit**: `ruby tools/check-vaults.rb` (read-only; `--json` for paths). Reports broken frontmatter, missing AGENTS.md links, passed review dates, and broken or ambiguous wikilinks. Do not auto-edit from a warning.
- **Learn from sessions**: the `dream-skill` skill reads new Claude Code and Codex conversations and files durable facts into these vaults; uncertain changes wait in a review queue.
- **Clean**: the `clean-wiki` skill scans for stale facts, contradictions, orphans and index drift; the owner approves each change in a local web UI, with an undo log.

## Conventions

- `[[wikilinks]]` for every cross-reference inside a vault. Wikilinks never cross vault boundaries; use a plain path such as `` `me: wiki/Bio.md` ``.
- Dates in ISO 8601 (`YYYY-MM-DD`). File and folder names in kebab-case or plain Title Case, consistently per vault.
- Every curated page has frontmatter with `tags`, `created`, `updated`. `updated` records file maintenance, not factual verification.
- Volatile facts (current role, current priorities, active experiments) carry `as_of` and, when useful, `review_after`. Past that date, treat them as last-known, not current.
- A plan, a completed action and an observed outcome are different states. Missing data means unknown, not zero.
- One page per concept (one project, one role, one goal).

## Source-of-truth rule

When facts disagree, prefer:

1. The owner's words in the current conversation.
2. The owning page with explicit provenance and the most recent applicable evidence date. Never settle a conflict from `updated` alone.
3. Any agent memory cache. Verify it against the vault before asserting it as current.
4. General model knowledge, last.

## Privacy

This folder describes a real person. Never publish, upload, or paste its contents into third-party services without the owner's explicit request. Mark sensitive pages with `sensitivity: private` in frontmatter; agents should not quote them outside a direct question about that topic.
