# Requirements: kiro-recall

Source of truth: spec/01-relevance-and-cold-vault.md, spec/02-session-hook-and-capture.md

---

## 1. MCP Server and Vault Path Configuration

WHEN kiro-recall is installed, the user SHALL configure their vault path by editing the `vaultPath` value in `powers/kiro-recall/mcp.json`.

WHEN the session hook fires, it SHALL attempt to verify the vault path is accessible before proceeding with context injection.

WHEN the vault path is unreachable, the hook SHALL skip context injection and display exactly:
> Couldn't reach your vault at session start — context not loaded. Check that your vault path is correct in kiro-recall settings.

WHEN the MCP server is unavailable, the hook SHALL skip context injection and display exactly:
> The vault MCP server isn't responding — context not loaded this session. You can still use `/recall` to capture notes once it's back up.

In both failure cases, the session SHALL continue normally without delay and SHALL NOT surface stack traces, exception messages, or internal file paths.

---

## 2. Relevance Detection

WHEN the session hook fires, the agent SHALL extract the Workspace_Name (final path segment of the workspace root).

WHEN the Workspace_Name is in the Generic_Name list (`src`, `dev`, `project`, `app`, `code`, `workspace`, `repo`, `main`, `test`, `build`, `website`, `frontend`, `backend`, `api`, `server`, `client`, `lib`, `library`, `core`, `base`), the agent SHALL skip Primary Signal and proceed to Secondary Signal.

WHEN the Workspace_Name is NOT in the Generic_Name list, the agent SHALL search `01-projects/` in the vault for a case-insensitive name match (file or subfolder). On match, load that Project Note + all Permanent Notes and record source as `primary`.

WHEN Primary Signal produces no match, the agent SHALL evaluate Secondary Signal: inspect open file paths for a segment matching a name in `01-projects/`, then check `.kiro/steering` for a `project` field. On match, load Project Note + all Permanent Notes and record source as `secondary`.

WHEN neither Primary nor Secondary Signal resolves a project, the agent SHALL load all Permanent Notes from `06-permanent/` and record source as `fallback`.

WHEN the fallback path is taken and `06-permanent/` is empty, the agent SHALL treat the vault as a Cold Vault.

The agent SHALL NOT evaluate lower-priority signals once a higher-priority signal produces a match.

---

## 3. Cold Vault Handling

WHEN both `06-permanent/` and `00-inbox/` contain zero markdown files, the vault is a Cold Vault.

WHEN the vault is a Cold Vault, the session hook SHALL skip context injection entirely, surface no error, and display exactly:
> Your vault is empty — no context loaded yet. That's fine, you're just getting started. Use `/recall` during this session to capture your first note. It'll land in your inbox and kiro-recall will confirm it worked.

The message SHALL NOT include diagnostic output, stack traces, or file paths.

---

## 4. Session Hook Firing

THE session hook SHALL fire on the first prompt submission only (once per session).

WHEN the hook fires, the agent SHALL complete context injection before the user's first prompt is forwarded to the model.

WHEN context injection completes, the agent SHALL display exactly one Session Summary line in the format:
- `Loaded {project} note ({source} match) + {N} permanent notes.`
- `Loaded {N} permanent notes (fallback — no project match found).`

WHEN zero Permanent Notes are loaded alongside a Project Note, the count SHALL be omitted (not `+ 0 permanent notes`).

---

## 5. Manual Capture — /recall

WHEN the user invokes `/recall`, the agent SHALL prompt for what was built, decided, or learned — or infer a draft from recent session context.

THE agent SHALL write a Capture Note to `00-inbox/` with fields: Date (ISO 8601), Project, What happened, Why it matters, Links (omitted if empty). All fields use `##` second-level headings.

THE filename SHALL follow: `YYYY-MM-DD-{project}-{slug}.md`.

WHEN `00-inbox/` was empty before the write, display:
> Note saved to your inbox. Your vault is live — next session, kiro-recall will load context automatically.

WHEN `00-inbox/` already had notes, display:
> Note saved: `{filename}`. It's in your inbox whenever you're ready to review it.

WHEN the write fails, display the failure message followed by the full note content in a markdown code block. Do NOT retry automatically.
