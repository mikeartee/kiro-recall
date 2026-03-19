# Requirements Document

## Introduction

This document covers two scoped concerns within kiro-recall: how the session
start hook wires into the Kiro session lifecycle to inject vault context before
the first prompt, and how the manual capture hook enables mid-session knowledge
capture via the `/recall` slash command.

kiro-recall ships as a Kiro Power (MCP + steering + hooks bundled) that wraps
the mcp-obsidian MCP server. The vault is a plain folder of markdown files with
a defined structure. Relevance detection and cold vault handling are specified
in spec 01. This document assumes the Relevance_Detector has already resolved
which content to load.

These requirements cover session hook wiring and manual capture only.

---

## Glossary

Terms carried forward from spec 01:

- **Vault**: The root folder of markdown files used as the personal knowledge
  store. Configured by the user at install time.
- **Relevance_Detector**: The component responsible for determining which vault
  content to load for a given workspace session. Defined in spec 01.
- **Session_Hook**: The hook that fires before the first prompt in a Kiro
  session and triggers context injection.
- **Workspace**: The folder currently open in Kiro.
- **Permanent_Notes**: Markdown files stored under `06-permanent/` in the Vault.
- **Inbox**: The `00-inbox/` folder in the Vault.
- **Project_Note**: A markdown file or subfolder inside `01-projects/` whose
  name matches the resolved project identifier.
- **Cold_Vault**: A Vault where `06-permanent/` contains no markdown files and
  `00-inbox/` contains no markdown files.
- **Context_Injection**: The act of loading vault content and making it
  available as ambient context for the current session.
- **Capture_Command**: The `/recall` slash command used to write a structured
  note to `00-inbox/`.

New terms introduced in this document:

- **Session_Summary**: The single-line human-readable message surfaced to the
  user after Context_Injection completes, describing what was loaded.
- **Match_Source**: The signal that resolved vault content — one of `primary`,
  `secondary`, or `fallback`. Determined by the Relevance_Detector as defined
  in spec 01.
- **Injection_Payload**: The resolved set of vault content (Project_Note and/or
  Permanent_Notes) passed to Context_Injection by the Relevance_Detector.
- **Capture_Note**: The structured markdown file written to `00-inbox/` by the
  Capture_Command.
- **MCP_Server**: The mcp-obsidian MCP server instance that provides read and
  write access to the Vault.
- **Vault_Path**: The absolute filesystem path to the Vault root, configured at
  install time.

---

## Requirements

### Requirement 1: Session Hook Firing Point

**User Story:** As a developer, I want kiro-recall to load my vault context
before I type anything, so that every session starts with full context already
in place.

#### Acceptance Criteria

1. THE Session_Hook SHALL register on the `promptSubmit` event (or the
   earliest equivalent lifecycle event available in the Kiro Power API) so that
   it fires before the user's first prompt is processed.

2. WHEN the Session_Hook fires, THE Session_Hook SHALL invoke the
   Relevance_Detector to resolve the Injection_Payload before any other
   processing occurs.

3. WHEN the Relevance_Detector returns an Injection_Payload, THE Session_Hook
   SHALL complete Context_Injection before the user's first prompt is forwarded
   to the model.

4. THE Session_Hook SHALL fire exactly once per session, on the first prompt
   submission only.

---

### Requirement 2: Context Injection

**User Story:** As a developer, I want the resolved vault content injected as
ambient context, so that Kiro has access to my notes without me having to paste
them in manually.

#### Acceptance Criteria

1. WHEN the Relevance_Detector returns a non-empty Injection_Payload, THE
   Session_Hook SHALL pass the full content of the Injection_Payload to
   Context_Injection.

2. THE Context_Injection SHALL make the Injection_Payload available as ambient
   context for the duration of the session.

3. WHEN Context_Injection completes, THE Session_Hook SHALL surface the
   Session_Summary to the user.

4. WHEN the Relevance_Detector returns an empty Injection_Payload (Cold_Vault
   path as defined in spec 01), THE Session_Hook SHALL skip Context_Injection
   and apply cold vault behaviour as specified in spec 01.

---

### Requirement 3: Session Summary Format

**User Story:** As a developer, I want a brief, warm confirmation of what was
loaded at session start, so that I know kiro-recall fired and what context I'm
working with.

#### Acceptance Criteria

1. WHEN Context_Injection completes, THE Session_Hook SHALL display exactly one
   Session_Summary line to the user.

2. THE Session_Summary SHALL include the Match_Source (`primary`, `secondary`,
   or `fallback`) and the total count of notes loaded.

3. WHEN the Match_Source is `primary` and a Project_Note was loaded, THE
   Session_Summary SHALL include the name of the matched project.

4. THE Session_Summary SHALL use a warm, conversational tone and SHALL NOT
   include file paths, internal identifiers, or diagnostic output.

5. THE Session_Summary SHALL conform to the following format:

   > Loaded [project name] note ([Match_Source] match) + [N] permanent notes.

   Examples:
   - `Loaded kiro-recall note (primary match) + 12 permanent notes.`
   - `Loaded kiro-recall note (secondary match) + 8 permanent notes.`
   - `Loaded 15 permanent notes (fallback — no project match found).`

6. WHEN zero Permanent_Notes are loaded alongside a Project_Note, THE
   Session_Summary SHALL omit the permanent notes count rather than display
   `+ 0 permanent notes`.

---

### Requirement 4: Session Hook Failure Behaviour

**User Story:** As a developer, I want kiro-recall to fail gracefully if the
vault or MCP server is unavailable, so that my session still starts and I'm
informed without being overwhelmed by error output.

#### Acceptance Criteria

1. WHEN the Vault_Path is unreachable at session start, THE Session_Hook SHALL
   skip Context_Injection entirely.

2. WHEN the MCP_Server is unavailable at session start, THE Session_Hook SHALL
   skip Context_Injection entirely.

3. IF Context_Injection is skipped due to an unreachable Vault_Path or
   unavailable MCP_Server, THEN THE Session_Hook SHALL surface exactly one
   warm error message to the user.

4. THE Session_Hook SHALL display the following message when the Vault_Path is
   unreachable:

   > Couldn't reach your vault at session start — context not loaded. Check
   > that your vault path is correct in kiro-recall settings.

5. THE Session_Hook SHALL display the following message when the MCP_Server is
   unavailable:

   > The vault MCP server isn't responding — context not loaded this session.
   > You can still use `/recall` to capture notes once it's back up.

6. THE Session_Hook SHALL NOT surface stack traces, exception messages, or
   internal file paths in any failure output.

7. WHEN Context_Injection is skipped due to failure, THE Session_Hook SHALL
   allow the user's first prompt to proceed without delay.

---

### Requirement 5: Manual Capture Hook — Trigger

**User Story:** As a developer, I want to capture what I just built, decided,
or learned by typing a single slash command, so that nothing important gets lost
between sessions.

#### Acceptance Criteria

1. THE Capture_Command SHALL be registered as the `/recall` slash command within
   the Kiro Power.

2. WHEN the user invokes `/recall`, THE Capture_Command SHALL activate
   immediately within the current session.

3. THE Capture_Command SHALL be available at any point during a session,
   regardless of whether Context_Injection ran at session start.

4. WHEN `/recall` is invoked, THE Capture_Command SHALL prompt the user to
   describe what was just built, decided, or learned, OR SHALL infer a draft
   from recent session context if available.

---

### Requirement 6: Capture Note Structure

**User Story:** As a developer, I want captured notes to follow a consistent
structure, so that my inbox stays organised and notes are easy to review and
promote later.

#### Acceptance Criteria

1. WHEN the Capture_Command writes a note, THE Capture_Command SHALL write a
   Capture_Note as a single markdown file to `00-inbox/` in the Vault.

2. THE Capture_Note SHALL include the following fields in order:

   - **Date**: ISO 8601 date of capture (e.g. `2025-07-14`)
   - **Project**: project name resolved from session context, or `unknown` if
     not resolvable
   - **What happened**: 1–3 sentences describing what was built, decided, or
     learned
   - **Why it matters**: 1–2 sentences describing the significance or future
     relevance
   - **Links**: any URLs or file references mentioned during the session
     (optional — omitted if none)

3. THE Capture_Note filename SHALL follow the format
   `YYYY-MM-DD-{project}-{slug}.md` where `{slug}` is a short kebab-case
   summary derived from the "What happened" content.

4. WHEN the Links field contains no entries, THE Capture_Note SHALL omit the
   Links section entirely rather than render an empty section.

5. THE Capture_Note SHALL be valid markdown and SHALL use second-level headings
   (`##`) for each field label.

---

### Requirement 7: Capture Confirmation

**User Story:** As a developer, I want confirmation that my note was saved after
running `/recall`, so that I know the capture worked and can move on.

#### Acceptance Criteria

1. WHEN the Capture_Command successfully writes a Capture_Note to `00-inbox/`,
   THE Capture_Command SHALL display a confirmation message to the user.

2. THE confirmation message SHALL include the filename of the saved Capture_Note
   so the user can locate it.

3. THE confirmation message SHALL use a warm, brief tone and SHALL NOT include
   full file paths or internal identifiers.

4. THE confirmation message SHALL conform to the following format:

   > Note saved: `{filename}`. It's in your inbox whenever you're ready to
   > review it.

5. WHEN `00-inbox/` already contains one or more markdown files, THE
   Capture_Command SHALL display the standard confirmation message defined in
   this requirement and SHALL NOT display the first-capture confirmation defined
   in spec 01.

---

### Requirement 8: Capture Failure Behaviour

**User Story:** As a developer, I want a graceful failure if the note can't be
saved, so that I don't lose what I just captured even if the vault write fails.

#### Acceptance Criteria

1. IF the Capture_Command fails to write the Capture_Note to `00-inbox/`, THEN
   THE Capture_Command SHALL surface a warm error message to the user.

2. WHEN a capture write fails, THE Capture_Command SHALL include the full
   content of the unsaved Capture_Note in the error output, formatted as a
   markdown code block, so the user can save it manually.

3. THE Capture_Command SHALL display the following message on write failure,
   followed by the Capture_Note content:

   > Couldn't save your note to the vault — here's what you captured so you
   > don't lose it:

4. THE Capture_Command SHALL NOT surface stack traces, exception messages, or
   internal file paths in the failure output.

5. WHEN a capture write fails, THE Capture_Command SHALL NOT retry the write
   automatically.
