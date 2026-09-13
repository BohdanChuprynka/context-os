# Context OS

A personal context database your AI reads before it answers you. Plain markdown folders, based on Andrej Karpathy's LLM Wiki pattern (a `raw/` folder for sources and a `wiki/` folder the AI maintains), plus the tools that keep it current.

Stop re-explaining yourself in every new chat. Tell it once and it's written down, kept tidy, and read automatically.

## What's inside

**1. Setting up the DB from the ground up** (`vault-starter/`)
- separate vaults for each area of your life and work (`me`, `projects`, `work`, `health`, ...)
- a root `CLAUDE.md` that routes the AI to the right vault and page for each question
- a schema, index and change log in every vault
- a `raw/` inbox: drop in notes, transcripts or docs, and the AI turns them into clean pages

**2. Maintaining your DB** (`vault-starter/tools/check-vaults.rb` + `skills/clean-wiki/`)
- a read-only audit: broken frontmatter, routing table vs. folders on disk, pages missing from the index, broken links, passed review dates
- clean-wiki: finds stale facts, contradictions, duplicates and orphans; you approve each fix in a local swipe UI, with an undo log
- dates on facts (`as_of`, `review_after`), so old info doesn't pass as current
- clear rules for which source wins when two notes disagree

**3. Auto-reinforced improvement** (`skills/dream-skill/`)
- reads your Claude Code and Codex sessions and pulls out what's worth remembering
- safe, high-confidence updates go in on their own, with receipts and an undo log
- anything uncertain waits for your review in a local page

## Setup (about 15 minutes)

Requirements: macOS or Linux, Python 3.11+, `jq`, Ruby (preinstalled on macOS), and Claude Code or Codex. Obsidian is optional, just a nice viewer.

1. Get the kit somewhere permanent: `git clone https://github.com/BohdanChuprynka/context-os ~/context-os` (or unzip the folder you were sent to `~/context-os`). The skills are linked from it, so don't delete it after setup.
2. Open a terminal in it and start Claude Code: `cd ~/context-os && claude` (or `codex`).
3. Say: **"Set up my Context OS."**

It checks your tools, asks a few questions (your name, where to create the vaults, which areas you want), builds the vaults, helps you write the first pages, and installs the two skills. It asks before touching any global config. `CLAUDE.md` in this folder is the full guide it follows, if you want to read it first.

## After setup

| When | What |
|---|---|
| Any time | Tell the AI what changed ("I switched jobs", "I prefer shorter answers"), or drop a file into a vault's `raw/` and say "ingest it" |
| Weekly | `/dream-skill` to learn from recent chats, then review the uncertain ones |
| Monthly | `/clean-wiki` to clean stale facts and contradictions |
| Monthly | `ruby tools/check-vaults.rb` inside your Context OS folder for the structural audit |

In Codex, use `Use $dream-skill` and `Use $clean-wiki`.

## Privacy

Everything stays on your machine as plain files. The skills run through the AI tool you already use (Claude Code or Codex), which sends the relevant text to that provider, the same as any chat. Nothing here phones home. Keep the vault out of public git repos.

## Credits

dream-skill and clean-wiki are MIT licensed (`skills/LICENSE`); source: github.com/BohdanChuprynka/skills. The raw/wiki vault pattern follows Andrej Karpathy's LLM Wiki idea.
