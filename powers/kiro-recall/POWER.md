---
name: "kiro-recall"
displayName: "kiro-recall"
description: "Forces your personal knowledge vault into every Kiro session before you type a single word. Wraps mcp-obsidian to inject relevant notes as ambient context, and captures new knowledge mid-session via /recall."
keywords: ["vault", "notes", "recall", "second brain", "knowledge base", "context", "obsidian", "capture", "zettelkasten"]
author: "Mike Rewiri-Thorsen"
---

# kiro-recall

## Overview

kiro-recall solves the passive steering file problem. Steering files are passive — Kiro reads them if it feels like it and skips them constantly. Every session without kiro-recall burns tokens re-establishing context: who you are, what the project is, what decisions were already made.

kiro-recall makes context injection an active hook-based event, not a suggestion. A session start hook fires before your first prompt, reads your vault, and injects the relevant notes as ambient context. A manual capture hook lets you write structured notes to your inbox mid-session with a single `/recall` command.

The vault is a plain folder of markdown files. Obsidian is not required — it's optional for visual graph browsing only.

## Available Steering Files

- **session-hook** — Session start hook behaviour: relevance detection, context injection, cold vault handling, and session summary format
- **capture-hook** — Manual capture hook: `/recall` command, note structure, confirmation messages, and failure handling
- **implementation-plan** — Full sequenced task list for building kiro-recall, with requirement traceability

## MCP Config Placeholders

**IMPORTANT:** Before using this power, replace the following placeholder in `mcp.json`:

- `YOUR_VAULT_PATH_HERE`: The absolute filesystem path to your vault root directory.
  - **How to set it:** Choose or create a folder on your system to use as your vault.
    - macOS/Linux example: `/Users/yourname/vault`
    - Windows example: `C:\\Users\\yourname\\vault`
  - The folder does not need to exist yet — kiro-recall will scaffold the structure on first run.
  - Once set, your `mcp.json` args should look like: `"--config", "{\"vaultPath\":\"/Users/yourname/vault\"}"`

## Vault Structure

kiro-recall scaffolds this folder structure automatically on first run:

```
vault/
├── 00-inbox/          # Zero-friction capture — /recall writes here
├── 01-projects/       # Active project notes — one file or subfolder per project
├── 02-job-search/     # Applications and CV work
├── 03-learning/       # Course and certification notes
├── 04-knowledge/      # Permanent reference topics
├── 05-community/      # Community work
├── 06-permanent/      # Refined atomic Zettelkasten notes — loaded every session
└── 07-templates/      # Note templates
```

The two folders that drive context injection are:
- `06-permanent/` — loaded every session as baseline knowledge
- `01-projects/` — the matching project note is loaded on top of permanent notes

## How It Works

### Session start
When you submit your first prompt, the session hook fires. It runs the Relevance Detector to figure out which vault content is relevant to your current workspace, then injects that content as ambient context before your prompt reaches the model. You see a one-line summary of what was loaded.

### Relevance detection (in priority order)
1. **Primary signal** — matches your workspace folder name against project names in `01-projects/`
2. **Secondary signal** — scans open file paths for a project name match, then checks `.kiro/steering` for a `project` field
3. **Fallback** — loads all permanent notes from `06-permanent/` when no project match is found
4. **Cold vault** — if the vault has no permanent notes and no inbox notes, skips injection entirely and shows a warm onboarding message

### Mid-session capture
Type `/recall` at any point. kiro-recall prompts you to describe what was built, decided, or learned (or infers a draft from session context), then writes a structured markdown note to `00-inbox/`.

## Onboarding

### Prerequisites
- Node.js 18+ (required to run the MCP server via npx)
- A folder to use as your vault (will be scaffolded automatically)
- Obsidian is optional — only needed if you want visual graph browsing

### Installation
1. Install kiro-recall from the Kiro Powers marketplace
2. Edit `mcp.json` and replace `YOUR_VAULT_PATH_HERE` with your vault path
3. Restart Kiro or reconnect the MCP server from the MCP Server view
4. On your next session, the hook fires and scaffolds your vault structure if it doesn't exist yet

### First session
Your vault will be empty (Cold Vault). You'll see:

> Your vault is empty — no context loaded yet. That's fine, you're just getting started. Use `/recall` during this session to capture your first note. It'll land in your inbox and kiro-recall will confirm it worked.

Run `/recall` to capture your first note. After it saves you'll see:

> Note saved to your inbox. Your vault is live — next session, kiro-recall will load context automatically.

From the second session onwards, context loads automatically.

## Session Summary Format

After context injection, you'll see exactly one line:

- `Loaded kiro-recall note (primary match) + 12 permanent notes.`
- `Loaded kiro-recall note (secondary match) + 8 permanent notes.`
- `Loaded 15 permanent notes (fallback — no project match found).`

When zero permanent notes exist alongside a project note, the count is omitted rather than showing `+ 0 permanent notes`.

## Failure Messages

If the vault path is unreachable:
> Couldn't reach your vault at session start — context not loaded. Check that your vault path is correct in kiro-recall settings.

If the MCP server is unavailable:
> The vault MCP server isn't responding — context not loaded this session. You can still use `/recall` to capture notes once it's back up.

If a `/recall` write fails:
> Couldn't save your note to the vault — here's what you captured so you don't lose it:
> *(followed by the full note content as a markdown code block)*

No stack traces, exception messages, or internal file paths appear in any failure output.

## Best Practices

- Keep permanent notes atomic — one idea per note, written to last
- Use `00-inbox/` as a staging area; promote notes to `06-permanent/` when they're refined
- Name project folders in `01-projects/` to match your workspace folder names for reliable primary signal matching
- Run `/recall` at the end of any meaningful session — decisions, patterns, and insights compound over time
- Avoid generic workspace folder names (`src`, `dev`, `app`) — kiro-recall skips primary matching for these and falls back to secondary signals

## Why Not Just Use Steering Files?

Steering files are passive. Kiro reads them if it feels like it. kiro-recall uses hooks — they fire whether Kiro wants to or not. Your context loads before the first prompt, every time. Across 10 sessions a day that's a meaningful reduction in credit burn, especially on Kiro's free tier.
