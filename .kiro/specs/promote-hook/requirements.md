# Requirements: promote-hook

## Introduction

The promote hook is a user-triggered Kiro hook invoked via `/promote`. It guides the user through selecting a note from `00-inbox/`, reformats it as an atomic Zettelkasten permanent note, writes it to `06-permanent/`, and deletes the original. The hook is a pure JSON hook file — no compiled code — and uses mcp-obsidian for all vault I/O.

## Glossary

- **Hook**: A Kiro hook JSON file that defines an agent-driven workflow triggered by a user command.
- **Inbox**: The `00-inbox/` folder in the vault; holds raw capture notes awaiting promotion.
- **Permanent_Note**: An atomic Zettelkasten note in `06-permanent/` encoding a single idea with standard headings.
- **Promote_Hook**: The hook defined in `.kiro/hooks/kiro-recall-promote.kiro.hook`.
- **mcp-obsidian**: The MCP server used for all vault read/write/delete operations.
- **Vault**: The markdown folder managed by mcp-obsidian, path resolved from `powers/kiro-recall/mcp.json`.
- **Wikilink**: A `[[note title]]` style cross-reference used in Obsidian-compatible vaults.
- **Kebab_Case_Filename**: A filename composed of lowercase words joined by hyphens, no date prefix, ending in `.md`.

---

## Requirements

### Requirement 1: Vault Path Resolution

**User Story:** As a developer, I want the hook to resolve the vault path from the existing config, so that I don't have to configure it separately.

#### Acceptance Criteria

1. WHEN the Promote_Hook runs, THE Promote_Hook SHALL read `powers/kiro-recall/mcp.json` from the workspace root and extract the vault path from `mcpServers.mcp-obsidian.args` (last element of the array).
2. IF the config file is unreadable or the vault path cannot be extracted, THEN THE Promote_Hook SHALL display a human-readable error message and stop without surfacing stack traces, exception messages, or internal file paths.

---

### Requirement 2: Empty Inbox Handling

**User Story:** As a developer, I want a clear message when there's nothing to promote, so that I'm not left wondering why nothing happened.

#### Acceptance Criteria

1. WHEN the Promote_Hook runs and `00-inbox/` contains zero markdown files, THE Promote_Hook SHALL display exactly: `Your inbox is empty — nothing to promote yet.`
2. WHEN the empty inbox message is displayed, THE Promote_Hook SHALL stop without performing any further operations.

---

### Requirement 3: Note Selection

**User Story:** As a developer, I want to see a list of inbox notes and pick one, so that I control which note gets promoted.

#### Acceptance Criteria

1. WHEN `00-inbox/` contains one or more markdown files, THE Promote_Hook SHALL list the filenames and prompt the user to select one by number or name.
2. WHEN the user selects a note, THE Promote_Hook SHALL read the full content of that note from `00-inbox/` via mcp-obsidian.
3. IF the selected note cannot be read, THEN THE Promote_Hook SHALL display a human-readable error and stop without surfacing stack traces, exception messages, or internal file paths.

---

### Requirement 4: Permanent Note Formatting

**User Story:** As a developer, I want the selected note reformatted as an atomic Zettelkasten permanent note, so that it follows a consistent structure for long-term knowledge retention.

#### Acceptance Criteria

1. WHEN a note is selected, THE Promote_Hook SHALL reformat the content as a Permanent_Note with a single top-level `#` title followed by exactly four `##` sections in this order: `The idea`, `Why it matters`, `Connected to`, `Source`.
2. THE Promote_Hook SHALL derive the `#` title from the core idea expressed in the note content.
3. THE Promote_Hook SHALL populate `## The idea` with a single, self-contained statement of the idea.
4. THE Promote_Hook SHALL populate `## Why it matters` with 1–2 sentences on the significance or future relevance of the idea.
5. THE Promote_Hook SHALL populate `## Connected to` using `[[wikilink]]` format referencing related notes or concepts; if no connections are apparent, THE Promote_Hook SHALL leave this section with a placeholder `[[]]` or omit links rather than fabricating connections.
6. THE Promote_Hook SHALL populate `## Source` with the originating project name, session context, and date in ISO 8601 format derived from the source note's metadata or filename.

---

### Requirement 5: Kebab-Case Filename Derivation

**User Story:** As a developer, I want the permanent note filename derived from the idea title, so that filenames are readable and evergreen without date prefixes.

#### Acceptance Criteria

1. THE Promote_Hook SHALL derive the Kebab_Case_Filename from the idea title by lowercasing all characters, replacing spaces and special characters with hyphens, collapsing consecutive hyphens to one, and stripping leading and trailing hyphens.
2. THE Promote_Hook SHALL append `.md` to produce the final filename.
3. THE Promote_Hook SHALL NOT include a date prefix in the Kebab_Case_Filename.

---

### Requirement 6: Write to Permanent Notes

**User Story:** As a developer, I want the reformatted note written to `06-permanent/`, so that it is loaded into every future session.

#### Acceptance Criteria

1. WHEN the Permanent_Note is formatted and the filename is derived, THE Promote_Hook SHALL write the note to `06-permanent/{filename}` via mcp-obsidian.
2. WHEN the write succeeds, THE Promote_Hook SHALL proceed to delete the original inbox note (Requirement 7).
3. IF the write fails, THEN THE Promote_Hook SHALL display the reformatted note content in a markdown code block so the user does not lose the content, and SHALL stop without attempting deletion.
4. IF the write fails, THEN THE Promote_Hook SHALL NOT surface stack traces, exception messages, or internal file paths.

---

### Requirement 7: Delete Original Inbox Note

**User Story:** As a developer, I want the original inbox note removed after a successful promotion, so that my inbox stays clean.

#### Acceptance Criteria

1. WHEN the write to `06-permanent/` succeeds, THE Promote_Hook SHALL delete the original note from `00-inbox/` via mcp-obsidian.
2. IF the deletion fails, THEN THE Promote_Hook SHALL display a human-readable warning that the note was promoted but the inbox copy could not be removed, without surfacing stack traces, exception messages, or internal file paths.

---

### Requirement 8: Success Confirmation

**User Story:** As a developer, I want a clear confirmation after promotion, so that I know exactly what was created.

#### Acceptance Criteria

1. WHEN the promotion completes successfully (write and delete both succeed), THE Promote_Hook SHALL display exactly: `Promoted to 06-permanent/{filename}.`
2. THE Promote_Hook SHALL NOT include file system paths, stack traces, or internal identifiers beyond the filename in the confirmation message.
