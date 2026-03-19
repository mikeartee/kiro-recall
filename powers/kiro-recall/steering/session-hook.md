# kiro-recall: Session Hook & Relevance Detection

This steering file covers the session start hook: how it fires, how the Relevance Detector resolves vault content, cold vault handling, and the session summary format.

---

## Session Hook Firing

The Session Hook registers on the `promptSubmit` event (or the earliest equivalent lifecycle event in the Kiro Power API). It fires exactly once per session — on the first prompt submission only. Subsequent prompts in the same session do not re-trigger it.

When the hook fires:
1. Invoke the Relevance Detector immediately, before any other processing
2. Receive the resolved Injection Payload
3. Complete Context Injection before forwarding the user's first prompt to the model
4. Surface the Session Summary to the user

---

## Relevance Detector — Decision Tree

The Relevance Detector resolves which vault content to load by evaluating signals in priority order, stopping at the first branch that produces a result.

```
START
  │
  ▼
Is Workspace_Name a Generic_Name?
  ├─ YES → go to SECONDARY SIGNAL
  └─ NO  → go to PRIMARY SIGNAL

PRIMARY SIGNAL
  Does 01-projects/ contain a name matching Workspace_Name?
  ├─ YES → load Project_Note + all Permanent_Notes → DONE (source: primary)
  └─ NO  → go to SECONDARY SIGNAL

SECONDARY SIGNAL
  Do any open file paths contain a segment matching a name in 01-projects/?
  ├─ YES → load Project_Note + all Permanent_Notes → DONE (source: secondary)
  └─ NO  → Does .kiro/steering contain a project field matching 01-projects/?
             ├─ YES → load Project_Note + all Permanent_Notes → DONE (source: secondary)
             └─ NO  → go to FALLBACK

FALLBACK
  Is 06-permanent/ non-empty?
  ├─ YES → load all Permanent_Notes → DONE (source: fallback)
  └─ NO  → COLD VAULT → skip injection, show UX message → DONE
```

A higher-priority signal match always prevents lower-priority evaluation.

---

## Generic Name List

The following workspace folder names are treated as generic and skip Primary Signal evaluation entirely, proceeding directly to Secondary Signal:

```
src, dev, project, app, code, workspace, repo, main, test, build,
website, frontend, backend, api, server, client, lib, library, core, base
```

---

## Primary Signal

- Extract the final path segment from the current workspace root path (the Workspace Name)
- If the Workspace Name is not in the Generic Name list, search `01-projects/` for a file or subfolder whose name case-insensitively matches the Workspace Name
- On match: load that Project Note + all Permanent Notes from `06-permanent/`; record source as `primary`

---

## Secondary Signal

Triggered when Primary Signal is skipped (generic name) or produces no match.

1. Inspect the paths of all files currently open in the workspace
2. Match any path segment case-insensitively against subfolder names in `01-projects/`
3. Use the first such match as the resolved project identifier
4. If no open-file match: read `.kiro/steering` and use the `project` field value as a candidate if it matches a name in `01-projects/`
5. On match: load Project Note + all Permanent Notes; record source as `secondary`

---

## Fallback

When neither Primary nor Secondary resolves a project identifier:
- Load all Permanent Notes from `06-permanent/`
- Record source as `fallback`
- If `06-permanent/` is empty, treat as Cold Vault (see below)

---

## Cold Vault Detection

A vault is a Cold Vault when:
- `06-permanent/` contains zero markdown files, AND
- `00-inbox/` contains zero markdown files

Both conditions must be true. A non-empty inbox alone prevents Cold Vault classification.

When the vault is a Cold Vault:
- Skip Context Injection entirely
- Do NOT surface an error or warning
- Display the following message verbatim:

> Your vault is empty — no context loaded yet. That's fine, you're just getting started. Use `/recall` during this session to capture your first note. It'll land in your inbox and kiro-recall will confirm it worked.

`/recall` must be rendered as a highlighted, actionable reference within the message. No additional diagnostic output, stack traces, or file paths.

---

## Context Injection

When the Relevance Detector returns a non-empty Injection Payload:
- Pass the full content of the Injection Payload to Context Injection
- Make it available as ambient context for the duration of the session
- Surface the Session Summary after injection completes

When the Relevance Detector returns an empty Injection Payload (Cold Vault path):
- Skip Context Injection
- Apply Cold Vault behaviour as above

---

## Session Summary Format

After Context Injection completes, display exactly one Session Summary line. Warm, conversational tone. No file paths, internal identifiers, or diagnostic output.

**Format:**
```
Loaded {project name} note ({source} match) + {N} permanent notes.
```

**Examples:**
- `Loaded kiro-recall note (primary match) + 12 permanent notes.`
- `Loaded kiro-recall note (secondary match) + 8 permanent notes.`
- `Loaded 15 permanent notes (fallback — no project match found).`

**Rules:**
- Include the Match Source (`primary`, `secondary`, or `fallback`) and the total count of notes loaded
- When Match Source is `primary` or `secondary` and a Project Note was loaded, include the project name
- When zero Permanent Notes are loaded alongside a Project Note, omit the count entirely — do NOT display `+ 0 permanent notes`
- When Match Source is `fallback`, use the format: `Loaded {N} permanent notes (fallback — no project match found).`

---

## Failure Handling

### Unreachable vault path
- Skip Context Injection entirely
- Display exactly:
  > Couldn't reach your vault at session start — context not loaded. Check that your vault path is correct in kiro-recall settings.
- Allow the user's first prompt to proceed without delay

### Unavailable MCP server
- Skip Context Injection entirely
- Display exactly:
  > The vault MCP server isn't responding — context not loaded this session. You can still use `/recall` to capture notes once it's back up.
- Allow the user's first prompt to proceed without delay

**In all failure cases:**
- No stack traces, exception messages, or internal file paths in output
- Session continues normally — failure is non-blocking
