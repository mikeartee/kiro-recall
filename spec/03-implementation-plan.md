# Implementation Plan: kiro-recall

## Overview

kiro-recall ships as a Kiro Power (MCP + steering + hooks bundled) that wraps
the mcp-obsidian MCP server. The vault is a plain folder of markdown files.
Implementation is sequenced so that the MCP foundation is wired first, then
the Relevance_Detector, then the session hook, then the capture command.

All tasks reference the requirements documents:
- **spec 01** = `spec/01-relevance-and-cold-vault.md`
- **spec 02** = `spec/02-session-hook-and-capture.md`

---

## Tasks

- [ ] 1. Wire MCP server and vault path configuration
  - Register mcp-obsidian (smithery-ai/mcp-obsidian) as the MCP dependency in
    the Power manifest
  - Expose `vault_path` as a required user-configurable setting (absolute
    filesystem path to the vault root)
  - Validate that `vault_path` resolves to an accessible directory at startup;
    surface no error if it does not — failure handling is covered in task 7
  - All subsequent tasks depend on this wiring being in place
  - _Requirements: spec 02 — Req 1.1, Req 4.1, Req 4.2_

- [ ] 2. Implement Relevance_Detector — generic name list and primary signal
  - [ ] 2.1 Define the Generic_Name list as a documented constant
    - Include at minimum: `src`, `dev`, `project`, `app`, `code`, `workspace`,
      `repo`, `main`, `test`, `build`, `website`, `frontend`, `backend`, `api`,
      `server`, `client`, `lib`, `library`, `core`, `base`
    - _Requirements: spec 01 — Req 2.3_
  - [ ] 2.2 Implement Workspace_Name extraction
    - Extract the final path segment from the current workspace root path
    - _Requirements: spec 01 — Req 1.1_
  - [ ] 2.3 Implement Primary_Signal matching
    - If Workspace_Name is not a Generic_Name, search `01-projects/` for a
      case-insensitive name match (file or subfolder)
    - On match: load Project_Note + all Permanent_Notes; record source as
      `primary`
    - _Requirements: spec 01 — Req 1.2, Req 1.3, Req 1.4_
  - [ ]* 2.4 Write property test for Primary_Signal matching
    - **Property: Generic names never produce a primary match**
    - **Validates: spec 01 — Req 2.1, Req 2.2**
  - [ ]* 2.5 Write unit tests for Workspace_Name extraction and Primary_Signal
    - Test case-insensitive matching
    - Test generic name bypass
    - _Requirements: spec 01 — Req 1.1, Req 1.2, Req 2.1_

- [ ] 3. Implement Relevance_Detector — secondary signal
  - [ ] 3.1 Implement open-file path scanning
    - Inspect paths of all files currently open in the workspace
    - Match any path segment case-insensitively against subfolder names in
      `01-projects/`; use the first match as the resolved project identifier
    - _Requirements: spec 01 — Req 3.1, Req 3.2_
  - [ ] 3.2 Implement `.kiro/steering` project field fallback
    - If no open-file match found, read `.kiro/steering` and use the `project`
      field value as a candidate identifier if it matches a name in
      `01-projects/`
    - _Requirements: spec 01 — Req 3.3_
  - [ ] 3.3 On secondary match: load Project_Note + all Permanent_Notes; record
    source as `secondary`
    - _Requirements: spec 01 — Req 3.4, Req 3.5_
  - [ ]* 3.4 Write unit tests for secondary signal
    - Test open-file path match takes precedence over steering field
    - Test steering field used when no open-file match
    - _Requirements: spec 01 — Req 3.1, Req 3.2, Req 3.3_

- [ ] 4. Implement Relevance_Detector — fallback and decision tree
  - [ ] 4.1 Implement fallback path
    - When neither primary nor secondary resolves a project, load all
      Permanent_Notes from `06-permanent/`; record source as `fallback`
    - _Requirements: spec 01 — Req 4.1, Req 4.2_
  - [ ] 4.2 Wire the full decision tree
    - Implement the ordered evaluation: generic check → primary → secondary →
      fallback, stopping at the first branch that produces a result
    - _Requirements: spec 01 — Req 5.1, Req 5.2_
  - [ ]* 4.3 Write property test for decision tree ordering
    - **Property: A higher-priority signal match always prevents lower-priority
      evaluation**
    - **Validates: spec 01 — Req 5.2**
  - [ ]* 4.4 Write unit tests for fallback path
    - Test fallback fires only when primary and secondary both fail
    - _Requirements: spec 01 — Req 4.1, Req 4.2_

- [ ] 5. Checkpoint — Relevance_Detector complete
  - Ensure all Relevance_Detector tests pass. Ask the user if questions arise.

- [ ] 6. Implement cold vault detection and UX message
  - [ ] 6.1 Implement Cold_Vault check
    - A vault is Cold_Vault when `06-permanent/` contains zero markdown files
      AND `00-inbox/` contains zero markdown files
    - _Requirements: spec 01 — Req 6.1_
  - [ ] 6.2 Wire cold vault path into the decision tree
    - When fallback path reaches an empty `06-permanent/`, treat as Cold_Vault:
      skip Context_Injection, display no error
    - _Requirements: spec 01 — Req 6.2, Req 6.3_
  - [ ] 6.3 Display cold vault UX message verbatim
    - Show exactly:
      > Your vault is empty — no context loaded yet. That's fine, you're just
      > getting started. Use `/recall` during this session to capture your first
      > note. It'll land in your inbox and kiro-recall will confirm it worked.
    - `/recall` must be rendered as a highlighted, actionable reference
    - No additional diagnostic output, stack traces, or file paths
    - _Requirements: spec 01 — Req 7.1, Req 7.2, Req 7.3_
  - [ ]* 6.4 Write unit tests for cold vault detection
    - Test both conditions required (permanent empty AND inbox empty)
    - Test that a non-empty inbox alone prevents cold vault classification
    - _Requirements: spec 01 — Req 6.1_

- [ ] 7. Implement session hook wiring
  - [ ] 7.1 Register Session_Hook on the `promptSubmit` event (or earliest
    equivalent lifecycle event in the Kiro Power API)
    - _Requirements: spec 02 — Req 1.1_
  - [ ] 7.2 Invoke Relevance_Detector as the first action when the hook fires
    - _Requirements: spec 02 — Req 1.2_
  - [ ] 7.3 Pass the resolved Injection_Payload to Context_Injection before
    forwarding the user's first prompt to the model
    - _Requirements: spec 02 — Req 1.3, Req 2.1, Req 2.2_
  - [ ] 7.4 Implement once-per-session guard
    - Session_Hook fires exactly once; subsequent prompts in the same session
      do not re-trigger it
    - _Requirements: spec 02 — Req 1.4_
  - [ ]* 7.5 Write unit tests for session hook firing behaviour
    - Test hook fires on first prompt only
    - Test Relevance_Detector is called before prompt forwarding
    - _Requirements: spec 02 — Req 1.1, Req 1.2, Req 1.3, Req 1.4_

- [ ] 8. Implement session summary output
  - [ ] 8.1 Build Session_Summary string from Injection_Payload and Match_Source
    - Format: `Loaded {project} note ({source} match) + {N} permanent notes.`
    - When Match_Source is `fallback`: `Loaded {N} permanent notes (fallback — no project match found).`
    - When zero Permanent_Notes alongside a Project_Note: omit `+ 0 permanent notes`
    - Warm, conversational tone; no file paths, internal identifiers, or
      diagnostic output
    - _Requirements: spec 02 — Req 3.1, Req 3.2, Req 3.3, Req 3.4, Req 3.5, Req 3.6_
  - [ ] 8.2 Surface Session_Summary to the user after Context_Injection completes
    - _Requirements: spec 02 — Req 2.3_
  - [ ]* 8.3 Write property test for Session_Summary format
    - **Property: Session_Summary always contains Match_Source and note count**
    - **Validates: spec 02 — Req 3.2**
  - [ ]* 8.4 Write unit tests for Session_Summary edge cases
    - Test zero permanent notes omits count
    - Test fallback format
    - Test primary format with project name
    - _Requirements: spec 02 — Req 3.5, Req 3.6_

- [ ] 9. Implement session hook failure handling
  - [ ] 9.1 Detect unreachable Vault_Path at session start
    - Skip Context_Injection; display exactly:
      > Couldn't reach your vault at session start — context not loaded. Check
      > that your vault path is correct in kiro-recall settings.
    - _Requirements: spec 02 — Req 4.1, Req 4.3, Req 4.4_
  - [ ] 9.2 Detect unavailable MCP_Server at session start
    - Skip Context_Injection; display exactly:
      > The vault MCP server isn't responding — context not loaded this session.
      > You can still use `/recall` to capture notes once it's back up.
    - _Requirements: spec 02 — Req 4.2, Req 4.3, Req 4.5_
  - [ ] 9.3 Ensure no stack traces, exception messages, or internal file paths
    appear in any failure output
    - _Requirements: spec 02 — Req 4.6_
  - [ ] 9.4 Allow the user's first prompt to proceed without delay when
    Context_Injection is skipped due to failure
    - _Requirements: spec 02 — Req 4.7_
  - [ ]* 9.5 Write unit tests for failure paths
    - Test unreachable vault path produces correct message
    - Test unavailable MCP server produces correct message
    - Test no internal details leak into output
    - _Requirements: spec 02 — Req 4.1, Req 4.2, Req 4.6_

- [ ] 10. Checkpoint — Session hook complete
  - Ensure all session hook and summary tests pass. Ask the user if questions arise.

- [ ] 11. Implement capture command registration
  - Register `/recall` as a slash command within the Kiro Power
  - Command must be available at any point during a session, regardless of
    whether Context_Injection ran
  - _Requirements: spec 02 — Req 5.1, Req 5.2, Req 5.3_

- [ ] 12. Implement capture note structure and write logic
  - [ ] 12.1 Implement user prompt / context inference for capture content
    - When `/recall` is invoked, prompt the user to describe what was built,
      decided, or learned, OR infer a draft from recent session context if
      available
    - _Requirements: spec 02 — Req 5.4_
  - [ ] 12.2 Build Capture_Note markdown content
    - Fields in order: Date (ISO 8601), Project (from session context or
      `unknown`), What happened (1–3 sentences), Why it matters (1–2 sentences),
      Links (optional — omit section entirely if none)
    - Use `##` second-level headings for each field label
    - Valid markdown output
    - _Requirements: spec 02 — Req 6.2, Req 6.4, Req 6.5_
  - [ ] 12.3 Derive filename from note content
    - Format: `YYYY-MM-DD-{project}-{slug}.md` where `{slug}` is a short
      kebab-case summary derived from the "What happened" content
    - _Requirements: spec 02 — Req 6.3_
  - [ ] 12.4 Write Capture_Note to `00-inbox/` via MCP_Server
    - _Requirements: spec 02 — Req 6.1_
  - [ ]* 12.5 Write property test for Capture_Note filename format
    - **Property: Filename always matches `YYYY-MM-DD-{project}-{slug}.md`
      pattern for any valid input**
    - **Validates: spec 02 — Req 6.3**
  - [ ]* 12.6 Write unit tests for Capture_Note structure
    - Test Links section omitted when empty
    - Test `unknown` project when not resolvable
    - Test valid markdown output
    - _Requirements: spec 02 — Req 6.2, Req 6.4, Req 6.5_

- [ ] 13. Implement capture confirmation messages
  - [ ] 13.1 Implement standard confirmation after successful write
    - Display: `Note saved: \`{filename}\`. It's in your inbox whenever you're
      ready to review it.`
    - Include filename; no full file paths or internal identifiers
    - _Requirements: spec 02 — Req 7.1, Req 7.2, Req 7.3, Req 7.4_
  - [ ] 13.2 Implement first-capture confirmation
    - When `00-inbox/` contained zero markdown files before this write, display
      instead:
      > Note saved to your inbox. Your vault is live — next session,
      > kiro-recall will load context automatically.
    - When `00-inbox/` already contains one or more files, display the standard
      confirmation only
    - _Requirements: spec 01 — Req 8.1, Req 8.2, Req 8.3; spec 02 — Req 7.5_
  - [ ]* 13.3 Write unit tests for confirmation message selection
    - Test first-capture message fires only on first note
    - Test standard message fires on subsequent notes
    - _Requirements: spec 01 — Req 8.3; spec 02 — Req 7.5_

- [ ] 14. Implement capture failure handling
  - [ ] 14.1 Detect write failure and surface warm error message
    - Display: `Couldn't save your note to the vault — here's what you captured
      so you don't lose it:`
    - Follow immediately with the full Capture_Note content in a markdown code
      block
    - _Requirements: spec 02 — Req 8.1, Req 8.2, Req 8.3_
  - [ ] 14.2 Ensure no stack traces, exception messages, or internal file paths
    appear in failure output
    - _Requirements: spec 02 — Req 8.4_
  - [ ] 14.3 Do not retry the write automatically on failure
    - _Requirements: spec 02 — Req 8.5_
  - [ ]* 14.4 Write unit tests for capture failure path
    - Test full note content appears in output on failure
    - Test no internal details leak
    - _Requirements: spec 02 — Req 8.1, Req 8.2, Req 8.4_

- [ ] 15. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass end-to-end. Ask the user if questions arise.

---

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements and acceptance criteria for traceability
- Checkpoints at tasks 5, 10, and 15 provide incremental validation gates
- The MCP server (task 1) is a hard dependency for all subsequent tasks
- Cold vault and first-capture paths share state about inbox contents — implement
  the inbox check once and reuse it in tasks 6 and 13
