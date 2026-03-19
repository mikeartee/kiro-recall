# Design: promote-hook

## Overview

The promote hook is a single JSON hook file (`.kiro/hooks/kiro-recall-promote.kiro.hook`) with `"type": "userTriggered"`. It contains one `askAgent` prompt that drives the entire workflow. No compiled code, no external scripts — only the agent executing steps via mcp-obsidian tool calls.

The hook follows the same structural conventions as `kiro-recall-capture.kiro.hook` and `kiro-recall-vault-scaffold.kiro.hook`: numbered steps, explicit error handling at each step, no stack traces in output.

---

## Architecture

### Artifact

```
.kiro/hooks/kiro-recall-promote.kiro.hook
```

Single JSON file. Structure:

```json
{
  "name": "kiro-recall: Promote Note",
  "version": "1.0.0",
  "description": "...",
  "when": { "type": "userTriggered" },
  "then": { "type": "askAgent", "prompt": "..." }
}
```

### Dependencies

- `mcp-obsidian` MCP server (already configured in `powers/kiro-recall/mcp.json`)
- Workspace file `powers/kiro-recall/mcp.json` (vault path source)
- Vault folders: `00-inbox/` (read + delete), `06-permanent/` (write)

---

## Workflow Steps (encoded in the prompt)

### Step 1 — Resolve vault path

Read `powers/kiro-recall/mcp.json`. Extract `mcpServers.mcp-obsidian.args` last element. On failure: human-readable error, stop.

### Step 2 — List inbox notes

Use mcp-obsidian to list `00-inbox/`. Filter to `.md` files only.

- If zero markdown files: display `Your inbox is empty — nothing to promote yet.` and stop.
- If one or more: display numbered list and prompt user to select.

### Step 3 — Read selected note

Use mcp-obsidian to read the selected file from `00-inbox/`. On failure: human-readable error, stop.

### Step 4 — Reformat as Permanent Note

Construct the Permanent Note with this exact structure:

```markdown
# {Idea Title}

## The idea
{Single self-contained statement of the idea}

## Why it matters
{1–2 sentences on significance or future relevance}

## Connected to
{[[wikilink]] references to related notes/concepts, or omitted if none apparent}

## Source
{Project name}, {session context}, {date in ISO 8601}
```

Rules:
- Title derived from the core idea in the source note.
- `## Connected to` uses `[[wikilink]]` format. If no connections are apparent, write `(none identified)` rather than fabricating links.
- `## Source` pulls project and date from the source note's `## Project` and `## Date` fields if present; otherwise infers from filename (e.g. `2025-07-14-kiro-recall-...` → project: `kiro-recall`, date: `2025-07-14`).

### Step 5 — Derive kebab-case filename

Algorithm:
1. Take the idea title from Step 4.
2. Lowercase all characters.
3. Replace any character that is not `a-z`, `0-9`, or `-` with a hyphen.
4. Collapse consecutive hyphens to a single hyphen.
5. Strip leading and trailing hyphens.
6. Append `.md`.

No date prefix. Result is the permanent note filename.

### Step 6 — Write to 06-permanent/

Use mcp-obsidian to write `06-permanent/{filename}`.

- On success: proceed to Step 7.
- On failure: display the reformatted note content in a markdown code block preceded by a warm failure message. Stop. Do not attempt deletion.

### Step 7 — Delete from 00-inbox/

Use mcp-obsidian to delete `00-inbox/{original-filename}`.

- On success: proceed to Step 8.
- On failure: display a warning that the note was promoted but the inbox copy could not be removed. Stop. Do not surface stack traces or paths.

### Step 8 — Confirm

Display exactly: `Promoted to 06-permanent/{filename}.`

---

## Error Handling Summary

| Failure point | Output | Action |
|---|---|---|
| Config unreadable | Human-readable message | Stop |
| Inbox listing fails | Human-readable message | Stop |
| Inbox empty | `Your inbox is empty — nothing to promote yet.` | Stop |
| Note read fails | Human-readable message | Stop |
| Write fails | Warm message + note in code block | Stop |
| Delete fails | Warning (promoted, inbox copy remains) | Stop |

No step ever surfaces a stack trace, exception message, or internal file path.

---

## Correctness Properties

### P1 — Permanent note structure invariant
For any source note, the reformatted output SHALL contain exactly one `#` heading and exactly four `##` headings in the order: `The idea`, `Why it matters`, `Connected to`, `Source`.

### P2 — Kebab-case idempotence
Applying the kebab-case derivation algorithm twice to the same title SHALL produce the same result as applying it once: `kebab(kebab(title)) == kebab(title)`.

### P3 — No date prefix in filename
For any idea title, the derived filename SHALL NOT match the pattern `^\d{4}-\d{2}-\d{2}-`.

### P4 — Write failure preserves content
WHEN a write to `06-permanent/` fails, the full reformatted note content SHALL appear verbatim inside a markdown code block in the output, so no content is lost.

### P5 — Delete only after successful write
THE Promote_Hook SHALL NOT attempt to delete the inbox note unless the write to `06-permanent/` has succeeded in the same run.

### P6 — No internal details in any error output
For any failure scenario, the output SHALL NOT contain Python/JS stack trace patterns, exception class names, or absolute file system paths.

---

## Consistency with Existing Hooks

| Convention | capture hook | vault-scaffold hook | promote hook |
|---|---|---|---|
| `"type": "userTriggered"` | ✓ | ✓ | ✓ |
| Numbered steps in prompt | ✓ | ✓ | ✓ |
| Vault path from mcp.json | ✓ | ✓ | ✓ |
| No stack traces in output | ✓ | ✓ | ✓ |
| Failure shows content in code block | ✓ | — | ✓ |
| Clean confirmation message | ✓ | ✓ | ✓ |
