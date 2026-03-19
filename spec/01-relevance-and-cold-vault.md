# Requirements Document

## Introduction

This document covers two scoped concerns within kiro-recall: how the session
start hook determines which vault content is relevant to the current workspace,
and how the system behaves when the vault exists but contains no usable content.

kiro-recall ships as a Kiro Power (MCP + steering + hooks bundled) that wraps
the mcp-obsidian MCP server. The vault is a plain folder of markdown files with
a defined structure. The session start hook fires before the first prompt and
injects relevant vault context into the session.

These requirements cover relevance detection and cold vault handling only.
Session start hook wiring and manual capture hook are specified separately.

---

## Glossary

- **Vault**: The root folder of markdown files used as the personal knowledge
  store. Configured by the user at install time.
- **Relevance_Detector**: The component responsible for determining which vault
  content to load for a given workspace session.
- **Session_Hook**: The hook that fires before the first prompt in a Kiro
  session and triggers context injection.
- **Workspace**: The folder currently open in Kiro.
- **Workspace_Name**: The final path segment of the Workspace root folder (e.g.
  `kiro-recall` from `C:\Dev\kiro-recall`).
- **Generic_Name**: A Workspace_Name that matches a known list of non-specific
  folder names: `src`, `dev`, `project`, `app`, `code`, `workspace`, `repo`,
  `main`, `test`, `build`, `website`, `frontend`, `backend`, `api`, `server`,
  `client`, `lib`, `library`, `core`, `base`.
- **Primary_Signal**: The Workspace_Name matched against subfolder names inside
  `01-projects/` in the Vault.
- **Secondary_Signal**: The set of open file paths in the Workspace, and the
  project name declared in `.kiro/steering` if present.
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

---

## Requirements

### Requirement 1: Primary Signal — Workspace Name Matching

**User Story:** As a developer, I want kiro-recall to automatically identify
the relevant project in my vault by matching the workspace folder name, so that
the correct project context loads without any manual configuration.

#### Acceptance Criteria

1. WHEN the Session_Hook fires, THE Relevance_Detector SHALL extract the
   Workspace_Name from the root path of the current Workspace.

2. WHEN the Workspace_Name is not a Generic_Name, THE Relevance_Detector SHALL
   search `01-projects/` in the Vault for a file or subfolder whose name
   case-insensitively matches the Workspace_Name.

3. WHEN a matching Project_Note is found via Primary_Signal, THE
   Relevance_Detector SHALL load that Project_Note and all Permanent_Notes for
   Context_Injection.

4. WHEN a matching Project_Note is found via Primary_Signal, THE
   Relevance_Detector SHALL record the match source as `primary` for use in
   session summary output.

---

### Requirement 2: Generic Name Detection — Skip to Secondary Signal

**User Story:** As a developer who uses generic folder names like `src` or
`dev`, I want kiro-recall to skip the folder name match and use smarter signals
instead, so that I don't get irrelevant or empty context injected.

#### Acceptance Criteria

1. WHEN the Workspace_Name matches any entry in the Generic_Name list, THE
   Relevance_Detector SHALL skip Primary_Signal evaluation entirely.

2. WHEN Primary_Signal is skipped due to a Generic_Name, THE Relevance_Detector
   SHALL proceed directly to Secondary_Signal evaluation.

3. THE Relevance_Detector SHALL maintain a fixed, documented Generic_Name list
   containing at minimum: `src`, `dev`, `project`, `app`, `code`, `workspace`,
   `repo`, `main`, `test`, `build`, `website`, `frontend`, `backend`, `api`,
   `server`, `client`, `lib`, `library`, `core`, `base`.

---

### Requirement 3: Secondary Signal — Open Files and Steering Project Name

**User Story:** As a developer, I want kiro-recall to infer the project from
open files and steering configuration when the folder name is ambiguous or
generic, so that context injection still works in those cases.

#### Acceptance Criteria

1. WHEN Secondary_Signal evaluation is triggered, THE Relevance_Detector SHALL
   inspect the paths of all files currently open in the Workspace.

2. WHEN one or more open file paths contain a path segment that case-insensitively
   matches a subfolder name inside `01-projects/`, THE Relevance_Detector SHALL
   treat the first such match as the resolved project identifier.

3. WHEN `.kiro/steering` exists in the Workspace and contains a `project` field,
   THE Relevance_Detector SHALL use the value of that field as a candidate
   project identifier if no match was found from open file paths.

4. WHEN a project identifier is resolved via Secondary_Signal, THE
   Relevance_Detector SHALL load the matching Project_Note and all
   Permanent_Notes for Context_Injection.

5. WHEN a project identifier is resolved via Secondary_Signal, THE
   Relevance_Detector SHALL record the match source as `secondary` for use in
   session summary output.

---

### Requirement 4: Fallback — Load All Permanent Notes

**User Story:** As a developer, I want kiro-recall to still inject useful
context even when no project match is found, so that my permanent knowledge is
always available as a baseline.

#### Acceptance Criteria

1. WHEN neither Primary_Signal nor Secondary_Signal resolves a project
   identifier, THE Relevance_Detector SHALL load all Permanent_Notes from
   `06-permanent/` for Context_Injection.

2. WHEN the fallback path is taken, THE Relevance_Detector SHALL record the
   match source as `fallback` for use in session summary output.

3. WHEN the fallback path is taken and `06-permanent/` contains no markdown
   files, THE Relevance_Detector SHALL treat the Vault as a Cold_Vault and
   apply cold vault behaviour as defined in Requirement 6.

---

### Requirement 5: Relevance Decision Tree

**User Story:** As a contributor or maintainer, I want the relevance logic
documented as an explicit decision tree, so that the behaviour is unambiguous
and testable at each branch.

#### Acceptance Criteria

1. THE Relevance_Detector SHALL implement the following decision tree in order,
   stopping at the first branch that produces a result:

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

2. THE Relevance_Detector SHALL not evaluate lower-priority signals once a
   higher-priority signal produces a match.

---

### Requirement 6: Cold Vault Detection

**User Story:** As a new user who has just installed kiro-recall but not yet
added any notes, I want the system to handle an empty vault gracefully, so that
I don't see errors or confusing output on my first session.

#### Acceptance Criteria

1. WHEN the Session_Hook fires, THE Relevance_Detector SHALL check whether the
   Vault is a Cold_Vault by verifying that `06-permanent/` contains zero
   markdown files AND `00-inbox/` contains zero markdown files.

2. WHEN the Vault is a Cold_Vault, THE Session_Hook SHALL skip Context_Injection
   entirely.

3. WHEN the Vault is a Cold_Vault, THE Session_Hook SHALL NOT surface an error
   or warning to the user.

---

### Requirement 7: Cold Vault UX Message

**User Story:** As a new user with an empty vault, I want a warm, actionable
message that tells me exactly what to do next, so that I can get value from
kiro-recall immediately without reading documentation.

#### Acceptance Criteria

1. WHEN the Vault is a Cold_Vault, THE Session_Hook SHALL display the following
   message verbatim at the start of the session:

   > Your vault is empty — no context loaded yet. That's fine, you're just
   > getting started. Use `/recall` during this session to capture your first
   > note. It'll land in your inbox and kiro-recall will confirm it worked.

2. THE Session_Hook SHALL include the Capture_Command (`/recall`) as a
   highlighted, actionable reference within the cold vault message.

3. THE Session_Hook SHALL NOT display any additional diagnostic output, stack
   traces, or file path information alongside the cold vault message.

---

### Requirement 8: First Capture Confirmation

**User Story:** As a new user who has just run `/recall` for the first time, I
want a confirmation that my note was saved, so that I know the vault is working
and I can trust it going forward.

#### Acceptance Criteria

1. WHEN the Capture_Command is invoked and the resulting note is the first
   markdown file written to `00-inbox/`, THE Session_Hook SHALL display a
   confirmation message after the note is saved.

2. WHEN the first-capture confirmation fires, THE Session_Hook SHALL display
   the following message verbatim:

   > Note saved to your inbox. Your vault is live — next session, kiro-recall
   > will load context automatically.

3. WHEN the Capture_Command is invoked and `00-inbox/` already contains one or
   more markdown files, THE Session_Hook SHALL NOT display the first-capture
   confirmation message.
