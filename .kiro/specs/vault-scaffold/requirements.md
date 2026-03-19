# Requirements Document

## Introduction

This document specifies the vault scaffold hook for kiro-recall. The vault is a
plain folder of markdown files at a user-configured path. The POWER.md claims
the vault structure is "auto-scaffolded on first run" but no hook currently
implements this. If a user points kiro-recall at a new empty folder, the session
hook finds nothing and falls through to cold vault behaviour.

The scaffold hook is a manually-triggered Kiro hook (`userTriggered`) that the
user runs once when setting up a new vault. It creates the standard folder
structure, skips folders that already exist (idempotent), reports what was
created versus what was already present, and writes a starter note to
`06-permanent/` so the vault is not cold on the very first session start.

All deliverables are hook JSON files — no compiled code.

---

## Glossary

- **Vault**: The root folder of markdown files used as the personal knowledge
  store. Configured by the user via the `vaultPath` value in
  `powers/kiro-recall/mcp.json`.
- **Scaffold_Hook**: The `userTriggered` Kiro hook that creates the standard
  vault folder structure on demand.
- **Standard_Folders**: The eight folders that make up the canonical vault
  structure: `00-inbox/`, `01-projects/`, `02-job-search/`, `03-learning/`,
  `04-knowledge/`, `05-community/`, `06-permanent/`, `07-templates/`.
- **Starter_Note**: A markdown file written to `06-permanent/` during
  scaffolding so the vault is not a Cold_Vault on the first session start.
- **Cold_Vault**: A Vault where `06-permanent/` contains no markdown files and
  `00-inbox/` contains no markdown files. Defined in the relevance and cold
  vault spec.
- **Scaffold_Report**: The summary output displayed to the user after the hook
  completes, listing which folders were created and which already existed.

---

## Requirements

### Requirement 1: Manual Trigger

**User Story:** As a developer setting up a new vault, I want to run the
scaffold hook on demand, so that I control when the folder structure is created
and am not surprised by automatic side effects.

#### Acceptance Criteria

1. THE Scaffold_Hook SHALL be configured as a `userTriggered` hook in its hook
   JSON file.

2. WHEN the Scaffold_Hook is invoked, THE Scaffold_Hook SHALL execute
   immediately without prompting the user for confirmation or additional input.

---

### Requirement 2: Idempotent Folder Creation

**User Story:** As a developer, I want the scaffold hook to only create folders
that are missing, so that I can safely re-run it without overwriting or
duplicating anything that already exists.

#### Acceptance Criteria

1. WHEN the Scaffold_Hook runs, THE Scaffold_Hook SHALL check for the existence
   of each of the eight Standard_Folders in the Vault root.

2. WHEN a Standard_Folder does not exist in the Vault, THE Scaffold_Hook SHALL
   create that folder.

3. WHEN a Standard_Folder already exists in the Vault, THE Scaffold_Hook SHALL
   leave that folder and its contents unchanged.

4. FOR ALL possible subsets of pre-existing Standard_Folders, running the
   Scaffold_Hook SHALL result in all eight Standard_Folders existing in the
   Vault (idempotence property).

---

### Requirement 3: Scaffold Report

**User Story:** As a developer, I want a clear summary of what the hook did, so
that I know exactly which folders were created and which were already there.

#### Acceptance Criteria

1. WHEN the Scaffold_Hook completes, THE Scaffold_Hook SHALL display a
   Scaffold_Report listing each Standard_Folder with its outcome.

2. THE Scaffold_Report SHALL mark each folder as either `created` or
   `already existed`.

3. WHEN all eight Standard_Folders already existed before the hook ran, THE
   Scaffold_Report SHALL indicate that no changes were made.

4. THE Scaffold_Report SHALL NOT include file paths, internal identifiers, stack
   traces, or diagnostic output beyond the folder names and their outcomes.

---

### Requirement 4: Starter Note Creation

**User Story:** As a new user running the scaffold hook for the first time, I
want a starter note placed in my permanent notes folder, so that my vault is not
cold on the very first session start and kiro-recall loads something useful
immediately.

#### Acceptance Criteria

1. WHEN the Scaffold_Hook runs and `06-permanent/` contains zero markdown files,
   THE Scaffold_Hook SHALL write a Starter_Note to `06-permanent/`.

2. WHEN the Scaffold_Hook runs and `06-permanent/` already contains one or more
   markdown files, THE Scaffold_Hook SHALL NOT write a Starter_Note.

3. THE Starter_Note SHALL be named `vault-setup.md`.

4. THE Starter_Note SHALL contain the following content exactly:

   ```markdown
   # Vault Setup

   ## What this is
   This is your kiro-recall vault. It holds the personal knowledge that
   kiro-recall injects into every Kiro session before your first prompt.

   ## Folder structure
   - `00-inbox/` — zero-friction capture; `/recall` writes here
   - `01-projects/` — one file or subfolder per active project
   - `02-job-search/` — applications and CV work
   - `03-learning/` — course and certification notes
   - `04-knowledge/` — permanent reference topics
   - `05-community/` — community work
   - `06-permanent/` — refined atomic notes; loaded every session
   - `07-templates/` — note templates

   ## Next steps
   - Name project folders in `01-projects/` to match your workspace folder
     names for reliable primary signal matching.
   - Use `/recall` mid-session to capture notes to `00-inbox/`.
   - Promote refined notes to `06-permanent/` so they load every session.
   ```

5. WHEN the Starter_Note is written, THE Scaffold_Hook SHALL include it in the
   Scaffold_Report as `created`.

6. WHEN the Starter_Note already exists (i.e. `06-permanent/` was non-empty),
   THE Scaffold_Hook SHALL include a note in the Scaffold_Report that the
   starter note was skipped.

---

### Requirement 5: Vault Path Resolution

**User Story:** As a developer, I want the scaffold hook to use the same vault
path as the rest of kiro-recall, so that I don't have to configure anything
separately.

#### Acceptance Criteria

1. THE Scaffold_Hook SHALL resolve the Vault path from the same `vaultPath`
   configuration used by the mcp-obsidian MCP server.

2. IF the Vault path is unreachable when the Scaffold_Hook runs, THEN THE
   Scaffold_Hook SHALL display the following message and stop without creating
   any folders:

   > Couldn't reach your vault — scaffold aborted. Check that your vault path
   > is correct in `powers/kiro-recall/mcp.json`.

3. THE Scaffold_Hook SHALL NOT surface stack traces, exception messages, or
   internal file paths in any failure output.

---

### Requirement 6: Hook Deliverable Format

**User Story:** As a contributor, I want the scaffold hook delivered as a
standard Kiro hook JSON file, so that it integrates with the existing
kiro-recall hook infrastructure without requiring a build step.

#### Acceptance Criteria

1. THE Scaffold_Hook SHALL be delivered as a single `.kiro.hook` JSON file
   located at `.kiro/hooks/kiro-recall-vault-scaffold.kiro.hook`.

2. THE hook JSON file SHALL conform to the Kiro hook schema with fields: `name`,
   `version`, `description`, `when` (type `userTriggered`), and `then` (type
   `askAgent` with a `prompt` field).

3. THE hook JSON file SHALL NOT reference any external scripts, compiled
   binaries, or runtime dependencies beyond the mcp-obsidian MCP server already
   declared in `powers/kiro-recall/mcp.json`.
