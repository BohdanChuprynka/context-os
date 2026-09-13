# Context OS installer

You are Claude Code (or Codex) running inside the Context OS kit. When the user says anything like "set it up", "install", or "set up my Context OS", follow this guide end to end. Work step by step, show what you are about to do, and ask before anything outside the new vault folder.

The kit contains:

```
vault-starter/               the blank Context OS: root routing file, vault template, audit tool
  CLAUDE.md                  root routing template ({{placeholders}} to fill)
  AGENTS.md                  Codex adapter
  _vault-template/           one blank vault (CLAUDE.md schema, raw/, wiki/index.md, wiki/log.md)
  tools/check-vaults.rb      read-only audit (structure, routing table, index drift, links, review dates)
skills/dream-skill/          learns durable facts from Claude Code + Codex sessions (MIT)
skills/clean-wiki/           finds stale facts, contradictions, orphans; owner approves in a local UI (MIT)
```

## Ground rules

- Never read, copy or upload the user's personal files beyond what they point you to.
- Do not overwrite existing files. If the target folder or a config already exists, stop and ask.
- Ask before editing anything under `~/.claude`, `~/.codex`, or other global config.
- Replace every `{{PLACEHOLDER}}` you copy. Leave no placeholder behind (step 8 checks this).
- Keep this kit folder where it is after setup: the skills are symlinked from it. If the user wants the kit somewhere permanent, move it first, before step 6.

## Step 1. Preflight

Check and report, without installing anything yourself:

- `python3 --version` (3.11+ needed for clean-wiki), `jq --version`, `ruby --version` (macOS ships Ruby), and at least one of `claude --version` / `codex --version`.
- Obsidian is optional. The vaults are plain markdown folders; Obsidian is just a nice viewer.

If something is missing, give the exact install command (for example `brew install jq`) and wait.

## Step 2. Short interview

Ask these in one message, with defaults the user can accept by saying "defaults":

1. **Name** the AI should use for them. (Needed for `{{OWNER_NAME}}`.)
2. **Where** to create the Context OS. Default: `~/Documents/Context OS`.
3. **Which vaults.** Offer this menu; default is `me`, `projects`, `work`:

| Vault | Purpose | Suggested categories |
|---|---|---|
| `me` | Identity, preferences, background, goals, people | Identity, Preferences, Experience, Skills, Education, Goals, People |
| `projects` | Codebases and projects: purpose, stack, decisions, current goals, known issues | Project (one page each), Concept |
| `work` | Current job or business: company, clients, processes, pipeline, playbook | Company, Clients, Processes, Pipeline, Playbook |
| `health` | Conditions, routines, experiments, symptoms (mark pages `sensitivity: private`) | Conditions, Routines, Experiments, Observations |
| `fitness` | Training, nutrition targets, body metrics | Training, Nutrition, Metrics |
| `setup` | Apps, keyboard shortcuts, dev environment, config | Apps, Shortcuts, Environment |
| `learning` | Courses, topics, roadmaps, reading | Courses, Topics, Roadmaps |

They can rename any vault or add their own (ask for a one-line purpose and 3 to 6 categories).

4. **Which AI tools** they use: Claude Code, Codex, or both.

## Step 3. Create the vaults

Let `ROOT` be the chosen folder and `TODAY` today's date (`YYYY-MM-DD`).

1. Copy `vault-starter/` to `ROOT` (`cp -R`). Refuse if `ROOT` already contains a `CLAUDE.md`.
2. For each chosen vault `NAME`:
   - `cp -R "$ROOT/_vault-template" "$ROOT/NAME"`
   - In `NAME/CLAUDE.md`, `NAME/wiki/index.md` and `NAME/wiki/log.md`, fill:
     - `{{VAULT_TITLE}}`: a readable title, e.g. `Me` or `Projects`.
     - `{{VAULT_PURPOSE}}`: two or three sentences on what belongs here and what does not.
     - `{{VAULT_CATEGORIES}}`: one bullet per category, `- **Category**: what a page of this kind holds.`
     - `{{INDEX_SECTIONS}}`: one `## Category` heading per category, each followed by a blank line.
     - `{{TODAY}}`.
   - `ln -s CLAUDE.md "$ROOT/NAME/AGENTS.md"` so Codex reads the same schema.
3. In `ROOT/CLAUDE.md`, fill `{{OWNER_NAME}}` and replace `{{VAULT_TABLE}}` with one row per vault: `` | `NAME` | one-line domain | ``.
4. `mkdir -p "$ROOT/dream-reports" "$ROOT/clean-reports"`.
5. Run `ruby "$ROOT/tools/check-vaults.rb"`. Expect 0 structural errors. Fix anything it reports before moving on.

## Step 4. Connect it to the AI tools (ask first)

Show the user this block and ask permission to append it to `~/.claude/CLAUDE.md` (create the file if missing) and, if they use Codex, to `~/.codex/AGENTS.md`:

```markdown
## Personal context (Context OS)

For anything about me (identity, preferences, goals, projects, health, setup, work), first read `ROOT/CLAUDE.md` and follow its routing: pick the vault, read its `wiki/index.md`, then only the relevant pages. Prefer what I say in the conversation over the vault, and the vault over memory.
```

Replace `ROOT` with the real absolute path. If they decline, tell them to paste it themselves later.

## Step 5. Seed the first pages

An empty vault teaches the AI nothing. Offer three ways, and do whichever they pick (more than one is fine):

- **Interview (10 minutes).** Ask about 12 questions, a few at a time: what they do now, current priorities, past roles, skills, projects, how they like answers (length, tone, format), tools they use, goals for this year, people they work with often, things AI keeps getting wrong about them. Write compact pages in `me/wiki/` (for example `Bio.md`, `Now.md`, `Preferences.md`, `Goals.md`) and the right project or work pages. Add `as_of: TODAY` to anything that will change (`Now.md`, current role, priorities). Update each `wiki/index.md` and append `wiki/log.md`.
- **Drop files.** They put a resume, notes, a LinkedIn export, a README or project docs into `<vault>/raw/`. You ingest each one using that vault's `CLAUDE.md` Ingest steps.
- **Learn from past chats.** Covered by Dream in step 6 (use `--since` with a date about 30 days back for the first real run).

Keep every page factual and short. Never invent details to fill a category.

## Step 6. Install Dream (learns from sessions)

1. `bash skills/dream-skill/setup.sh` from this kit folder. It symlinks the Claude Code skill, installs a Codex copy if Codex exists, and seeds `~/.claude/dream-skill/config.toml`.
2. Replace the seeded config (ask first if it already existed before setup) with:

```toml
reports_dir = "ROOT/dream-reports"

[vaults.NAME]
root = "ROOT/NAME"
description = "the vault's one-line purpose"
# repeat for every vault; add `review_only = true` for health or anything sensitive

[entity_routing]
preferred_vault = "me"
stop_terms = []
```

3. Tell the user to restart Claude Code (so `/dream-skill` appears), then run a shadow canary first: `/dream-skill --shadow` (Codex: `Use $dream-skill --shadow`). Shadow runs every stage but writes nothing.
4. When the shadow run looks healthy, the first real run: `/dream-skill --since <date about 30 days ago>`. Safe, high-confidence facts are written with receipts and an undo log; everything uncertain waits in a local review UI.

## Step 7. Install clean-wiki (monthly cleanup)

1. `bash skills/clean-wiki/setup.sh` (creates a local venv with Flask and links the skill).
2. Edit `skills/clean-wiki/skills/clean-wiki/config/vault-paths.toml`: one `[[vaults]]` block per vault with `name` and absolute `path`, and `reports_dir = "ROOT/clean-reports"`. Delete the commented examples.
3. If Codex is installed, setup also created `~/.codex/skills/clean-wiki/config/vault-paths.toml`; put the same vault blocks there.
4. Tell the user: run `/clean-wiki` about once a month. It opens a local swipe-to-approve page; nothing changes without their approval, and every change has an undo log.

## Step 8. Verify and hand over

1. `ruby "$ROOT/tools/check-vaults.rb"`: 0 structural errors.
2. `grep -rn "{{" "$ROOT" --include='*.md' | grep -v _vault-template` returns nothing.
3. Open a fresh session and ask one question that needs the vault (for example "what am I focused on this month?"). The answer should cite a vault page.
4. Give the user this routine:

| When | What | Command |
|---|---|---|
| Any time | Drop a file into `<vault>/raw/` and say "ingest it" | |
| Weekly | Learn new facts from recent chats, review the uncertain ones | `/dream-skill` |
| Monthly | Clean stale facts, contradictions and orphans | `/clean-wiki` |
| Monthly, or after big changes | Structural audit | `ruby ROOT/tools/check-vaults.rb` |
| When something changes | Just tell the AI ("I switched jobs", "I prefer shorter answers"); Dream files it | |

Finish with a short summary: vault location, vaults created, pages written, what was installed, and anything skipped.
