# kiro-recall

> A Kiro Power that forces your vault context into every session before 
> you type a single word.

## What it is
kiro-recall is a Kiro Power that solves the passive steering file problem. 
Instead of hoping Kiro reads your context, hooks force it to load your 
personal knowledge vault before every session starts.

## The problem it solves
Steering files are passive — Kiro reads them if it feels like it and skips 
them constantly. Every session without kiro-recall burns tokens re-establishing 
context: who you are, what the project is, what decisions were already made. 
kiro-recall makes context injection an active hook-based event, not a suggestion.

## Benefits

### Saves tokens and credits
Every session without kiro-recall burns tokens re-establishing context — who 
you are, what the project is, what decisions were already made. That's typically 
500-1000 tokens of overhead before you've asked anything useful.

kiro-recall replaces that overhead with targeted context loading:
- Atomic permanent notes are small and precise — no filler
- Only loads notes relevant to the current project
- Power keyword activation means vault tools don't load at all unless needed
- No more pasting in background on every new session

Across 10 sessions a day that's a meaningful reduction in credit burn, 
especially on Kiro's free tier or if you're watching usage on a paid plan.

### Forces context that actually sticks
Steering files get skipped. CLAUDE.md gets ignored. kiro-recall uses hooks — 
they fire whether Kiro wants to or not. Your context loads before the first 
prompt, every time.

### Captures knowledge as you build
The manual capture hook means nothing gets lost between sessions. Hit the slash 
command, drop a note to inbox, done. No context switching, no opening another 
app, no typing up notes later from memory.

### Works without Obsidian
The vault is just markdown files. No app required. If you want visual graph 
browsing and backlinks, install Obsidian. If you just want the context injection 
and capture to work, you don't need to.

### Grows with you
Every permanent note you add makes the next session smarter. The vault compounds 
— the longer you use it, the more relevant context kiro-recall can inject. 
Unlike steering files which go stale, permanent notes are atomic and evergreen.

### Builds your second brain as a side effect
You're not maintaining a separate system. kiro-recall captures knowledge during 
your normal dev workflow. The vault fills itself. Over time it becomes a 
searchable record of every decision, pattern, and insight across all your projects.

## Architecture

### Core approach
- Ships as a Kiro Power (MCP + steering + hooks bundled)
- Wraps existing Obsidian MCP server (smithery-ai/mcp-obsidian)
- Obsidian is NOT a hard dependency — vault is just a folder of markdown files
- First-run hook scaffolds vault structure automatically

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
| Session Start | Every first prompt | Injects vault context before your first message |
| Capture (`/recall`) | User triggered | Writes a structured note to `00-inbox/` |
| Vault Scaffold | User triggered | Creates the standard folder structure in a new vault |
| Promote (`/promote`) | User triggered | Reformats an inbox note as a Zettelkasten permanent note and moves it to `06-permanent/` |

### Power activation keywords
`vault` `notes` `recall` `second brain` `knowledge base` `context`

## MCP dependency
Wraps: https://github.com/smithery-ai/mcp-obsidian  
Reads any directory of markdown files — no Obsidian install required.  
Obsidian is optional for visual browsing only.

## Install
1. Install kiro-recall from the Kiro Powers marketplace — one click
2. First run: enter your vault path or accept the default
3. kiro-recall scaffolds the folder structure automatically
4. Session start hook fires — vault context loads before your first prompt

## Roadmap

### v0.1.0 — Current release
- Session start hook — automatic vault context injection
- `/recall` — mid-session knowledge capture
- `/promote` — promote inbox notes to permanent Zettelkasten notes
- Vault scaffold hook — idempotent first-run setup

### v0.2.0
- Context meter hook — watches Kiro's context usage and surfaces a `/recall` prompt when approaching the threshold (e.g. 75%), preventing knowledge loss before auto-compaction fires. Depends on Kiro exposing a context threshold hook event.

### Future
- Conversation distillation — import Claude/Kiro chat exports and extract key decisions and insights as draft permanent notes via Cowork
- Multi-vault support — load context from multiple vaults per session

## Status
- [x] Spec written
- [x] MCP wrapper built
- [x] Session start hook
- [x] Manual capture hook (`/recall`)
- [x] First-run scaffold hook (`/kiro-recall-vault-scaffold`)
- [x] Promote hook (`/promote`)
- [ ] Power packaging
- [ ] Published to Kiro Powers marketplace

## Author
Mike Rewiri-Thorsen  
AWS Community Builder — AI Engineering, Class of 2026  
https://github.com/mikeartee