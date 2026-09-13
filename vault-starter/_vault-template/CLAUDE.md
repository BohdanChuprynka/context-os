# {{VAULT_TITLE}}

## What this is

{{VAULT_PURPOSE}}

The AI maintains the wiki pages. The owner supplies sources, answers questions, and approves anything uncertain.

## Directory structure

```
raw/              source documents waiting to be ingested. Read, never modify.
raw/completed/    sources already ingested. Moved here after processing.
wiki/             AI-maintained markdown pages.
wiki/index.md     catalog of all wiki pages, organized by category.
wiki/log.md       chronological record of ingests, queries and maintenance.
CLAUDE.md         this file. The schema and operating instructions.
AGENTS.md         symlink to this file for Codex.
```

## Wiki page categories

{{VAULT_CATEGORIES}}
- **Sources**: one summary page per ingested raw source.
- **Syntheses**: analysis pages born from questions worth keeping.

## Page format

```markdown
---
tags: [category]
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: [source filenames or "conversation YYYY-MM-DD"]
# optional for volatile facts:
# as_of: YYYY-MM-DD
# review_after: YYYY-MM-DD
# status: active | paused | completed | archived
---

# Page Title

Short, factual content. Use [[wikilinks]] for other pages in this vault.
```

## Conventions

- One concept per page. Keep pages compact: an agent should get the point in the first screen.
- Write facts, not narration. "Prefers async updates over meetings (2026-05)" beats a paragraph about a meeting.
- Keep dated history out of current pages. Move superseded material to `wiki/_archive/` and leave a one-line pointer.
- Never invent facts. If a page is missing something, write it as an open question.

## Operations

### Ingest
1. Check `raw/` for new sources.
2. Read the source and discuss key takeaways with the owner.
3. Create or update the relevant wiki pages; write a source summary page.
4. Update `wiki/index.md` and append `wiki/log.md`.
5. Move the source to `raw/completed/`.

### Query
1. Read `wiki/index.md`, then the smallest relevant set of pages.
2. Answer with `[[wikilinks]]` to what you used.
3. If the answer is worth keeping, offer to file it as a synthesis page.

### Lint
Check for orphan pages, missing cross-references, passed `review_after` dates, goals past their deadline, and pages whose `status` no longer matches reality. Report; do not rewrite without the owner.

## Log format

```markdown
## [YYYY-MM-DD] action | Description
One or two lines: what changed and which pages were touched.
```
