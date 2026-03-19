# kiro-recall: Manual Capture Hook

This steering file covers the `/recall` slash command: trigger behaviour, note structure, confirmation messages, and failure handling.

---

## Capture Command Registration

The Capture Command is registered as the `/recall` slash command within the Kiro Power. It must be available at any point during a session, regardless of whether Context Injection ran at session start.

---

## Trigger Behaviour

When the user invokes `/recall`:
1. Activate immediately within the current session
2. Prompt the user to describe what was just built, decided, or learned — OR infer a draft from recent session context if available
3. Build the Capture Note from the provided or inferred content
4. Write the note to `00-inbox/` via the MCP server
5. Display the appropriate confirmation message

---

## Capture Note Structure

The Capture Note is a single markdown file written to `00-inbox/` in the vault.

**Fields in order (using `##` second-level headings):**

```markdown
## Date
YYYY-MM-DD (ISO 8601 date of capture)

## Project
{project name resolved from session context, or `unknown` if not resolvable}

## What happened
{1–3 sentences describing what was built, decided, or learned}

## Why it matters
{1–2 sentences describing the significance or future relevance}

## Links
{any URLs or file references mentioned during the session}
```

**Rules:**
- The Links section is omitted entirely when there are no entries — do NOT render an empty section
- The note must be valid markdown
- Use `##` second-level headings for each field label

---

## Filename Format

```
YYYY-MM-DD-{project}-{slug}.md
```

Where:
- `YYYY-MM-DD` is the ISO 8601 date of capture
- `{project}` is the project name from session context (or `unknown`)
- `{slug}` is a short kebab-case summary derived from the "What happened" content

**Examples:**
- `2025-07-14-kiro-recall-session-hook-wired.md`
- `2025-07-14-unknown-relevance-detector-decision-tree.md`

---

## Confirmation Messages

### First capture (inbox was empty before this write)

When `00-inbox/` contained zero markdown files before this write, display:

> Note saved to your inbox. Your vault is live — next session, kiro-recall will load context automatically.

### Standard confirmation (inbox already had notes)

When `00-inbox/` already contains one or more markdown files, display:

> Note saved: `{filename}`. It's in your inbox whenever you're ready to review it.

Include the filename. No full file paths or internal identifiers.

**Selection rule:** Check inbox file count before writing. If zero → first-capture message. If one or more → standard message. Never show both.

---

## Failure Handling

If the Capture Command fails to write the note to `00-inbox/`:

1. Display the following message:
   > Couldn't save your note to the vault — here's what you captured so you don't lose it:

2. Immediately follow with the full Capture Note content in a markdown code block

3. Do NOT retry the write automatically

4. Do NOT surface stack traces, exception messages, or internal file paths

**Example failure output:**

```
Couldn't save your note to the vault — here's what you captured so you don't lose it:

​```markdown
## Date
2025-07-14

## Project
kiro-recall

## What happened
Wired the session hook to fire on promptSubmit. Relevance Detector resolves
the injection payload before the first prompt reaches the model.

## Why it matters
This is the core mechanism — without it, context injection doesn't happen.
​```
```

The user can copy and save the note manually from this output.
