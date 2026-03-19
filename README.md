# kiro-recall

> Your knowledge. Your machine. Every session. Automatically.
> Essentially, the "MCP Server of YOU".

## What it is

Open a workspace in Kiro. Type your first prompt. Before it reaches the model,
kiro-recall fires a hook, reads your personal knowledge vault from disk, and
injects the relevant notes as context. You do nothing. It just happens.

No cloud calls to read your own notes. No data leaving your machine. No external
service dependency. Your vault is plain markdown files on your disk, readable
by any text editor, not locked into any service, not sitting in someone else's
database.

That's the MCP Server of You. Your decisions, your knowledge, your project
context, injected into every Kiro session before you type a single word.

## The problem it solves

Steering files are passive. Kiro reads them if it feels like it and skips
them constantly. Every session without kiro-recall burns time re-establishing
context: who you are, what the project is, what decisions were already made.
kiro-recall makes context injection an active hook-based event, not a suggestion.

## Benefits

### Your knowledge. Your machine. Every session. Automatically.

The vault reads from disk. No API calls to read your own notes, no data
leaving your machine, no external service dependency. Your markdown files are
plain text, readable by any editor, not locked into any service or database.

When you open a workspace in Kiro and type your first prompt, the session hook
fires. It reads your vault locally via MCP, loads the relevant notes, and
injects them as context before your prompt reaches the model. You do nothing.
It just happens.

### Forces context that actually sticks

Steering files get skipped. CLAUDE.md gets ignored. kiro-recall uses hooks.
They fire whether Kiro wants to or not. Your context loads before the first
prompt, every time, without you thinking about it.

### Captures knowledge as you build

The `/recall` hook means nothing gets lost between sessions. Trigger it
mid-session, describe what you built or decided, and it writes a structured
note straight to your inbox. No context switching, no opening another app,
no typing up notes later from memory.

### Promotes raw captures into permanent knowledge

The `/promote` hook takes an inbox note and reformats it as an atomic
Zettelkasten permanent note. One idea, properly structured, moved to
`06-permanent/` where it loads automatically in future sessions. Your
captures compound over time into a genuine knowledge base.

### Works without Obsidian

The vault is just markdown files. No app required. If you want visual graph
browsing and backlinks, install Obsidian. If you just want the context
injection and capture to work, you don't need to.

### Grows with you

Every permanent note you add makes the next session smarter. The vault
compounds. The longer you use it, the more relevant context kiro-recall
can inject. Unlike steering files which go stale, permanent notes are
atomic and evergreen.

### Builds your second brain as a side effect

You're not maintaining a separate system. kiro-recall captures knowledge
during your normal dev workflow. The vault fills itself. Over time it becomes
a searchable record of every decision, pattern, and insight across all your
projects.

## Architecture

### Core approach
- Ships as a Kiro Power (MCP + steering + hooks bundled)
- Wraps @bitbonsai/mcpvault, 14 tools, actively maintained
- Vault reads happen locally, no cloud dependency for file access
- Obsidian is NOT a hard dependency, vault is just a folder of markdown files
- First-run scaffold hook creates the vault structure automatically

### Vault structure (auto-scaffolded on first run)
```
vault/
├── 00-inbox/          # Zero-friction capture
├── 01-projects/       # Active projects
├── 02-job-search/     # Applications and CV work
├── 03-learning/       # Course and certification notes
├── 04-knowledge/      # Permanent reference topics
├── 05-community/      # Community work
├── 06-permanent/      # Refined atomic Zettelkasten notes
└── 07-templates/      # Note templates
```

### Hooks

| Hook | Trigger | What it does |
|------|---------|--------------|
| Session Start | Every first prompt | Reads vault locally, injects context before your first message |
| Capture (`/recall`) | User triggered | Writes a structured note to `00-inbox/` |
| Vault Scaffold | User triggered | Creates the standard folder structure in a new vault |
| Promote (`/promote`) | User triggered | Reformats an inbox note as a Zettelkasten permanent note and moves it to `06-permanent/` |

### How relevance detection works

On session start, kiro-recall runs a Relevance Detector to decide what to load:

1. **Primary signal** — matches your workspace folder name against project names in `01-projects/`
2. **Secondary signal** — scans open file paths for a project name match, then checks `.kiro/steering` for a `project` field
3. **Fallback** — loads all permanent notes from `06-permanent/` when no project match is found
4. **Cold vault** — if the vault has no notes yet, shows a warm onboarding message instead

### Power activation keywords
`vault` `notes` `recall` `second brain` `knowledge base` `context`

## MCP dependency

Wraps: https://github.com/bitbonsai/mcpvault  
Reads any directory of markdown files directly from disk. No Obsidian install
required. Obsidian is optional for visual browsing only.

## Install

1. Install kiro-recall from the Kiro Powers marketplace, one click
2. Open `mcp.json` and replace `YOUR_VAULT_PATH_HERE` with your vault path
3. Restart Kiro or reconnect the MCP server from the MCP Server view
4. Run the Vault Scaffold hook once to create your folder structure
5. Session start hook fires on your next first prompt, vault context loads automatically

## Why Not Just Use Steering Files?

Steering files are passive. Kiro reads them if it feels like it. kiro-recall
uses hooks. They fire whether Kiro wants to or not. Your context loads before
the first prompt, every time.

Think of it as the MCP Server of You. Your decisions, your knowledge, your
project context, injected into every session automatically. From your machine.
With no cloud dependency for the vault itself.

## Roadmap

### v0.1.0 — Current release
- Session start hook, automatic local vault context injection
- `/recall`, mid-session knowledge capture
- `/promote`, promote inbox notes to permanent Zettelkasten notes
- Vault scaffold hook, idempotent first-run setup

### v0.2.0
- Context meter hook, watches Kiro's context usage and surfaces a `/recall`
  prompt when approaching the threshold (e.g. 75%), preventing knowledge loss
  before auto-compaction fires. Depends on Kiro exposing a context threshold
  hook event.

### Future
- Conversation distillation, import Claude/Kiro chat exports and extract
  key decisions and insights as draft permanent notes via Cowork
- Multi-vault support, load context from multiple vaults per session

## Status
- [x] Spec written
- [x] MCP wrapper built
- [x] Session start hook
- [x] Manual capture hook (`/recall`)
- [x] Vault scaffold hook
- [x] Promote hook (`/promote`)
- [x] Power packaging
- [ ] Published to Kiro Powers marketplace

## Author
Mike Rewiri-Thorsen  
AWS Community Builder, AI Engineering, Class of 2026  
https://github.com/mikeartee
