# Tasks: kiro-recall

Sequenced implementation tasks. All deliverables are hook JSON files and steering content — no compiled code.

References:
- spec 01 = spec/01-relevance-and-cold-vault.md
- spec 02 = spec/02-session-hook-and-capture.md
- design = .kiro/specs/kiro-recall/design.md

---

- [x] 1. Wire MCP server and vault path configuration
  - [x] 1.1 `powers/kiro-recall/mcp.json` — mcp-obsidian registered with vaultPath placeholder
  - [x] 1.2 `powers/kiro-recall/POWER.md` — vault path config documented in onboarding
  - [x] 1.3 `.kiro/hooks/kiro-recall-session-start.json` — session start hook with vault validation and failure messages
  - Acceptance: hook fires on `promptSubmit`; on vault/MCP failure surfaces correct verbatim message; no stack traces; session continues without delay
  - _Requirements: spec 02 — Req 1.1, Req 4.1, Req 4.2, Req 4.3, Req 4.4, Req 4.5, Req 4.6, Req 4.7_

- [x] 2. Implement Relevance Detector — generic name list and primary signal
  - [x] 2.1 Update `.kiro/hooks/kiro-recall-session-start.json` prompt with Workspace_Name extraction logic
    - Extract final path segment from workspace root path
    - _Requirements: spec 01 — Req 1.1_
  - [x] 2.2 Add Generic_Name list and bypass logic to hook prompt
    - Full list: `src`, `dev`, `project`, `app`, `code`, `workspace`, `repo`, `main`, `test`, `build`, `website`, `frontend`, `backend`, `api`, `server`, `client`, `lib`, `library`, `core`, `base`
    - Generic names skip primary signal entirely and proceed to secondary
    - _Requirements: spec 01 — Req 2.1, Req 2.2, Req 2.3_
  - [x] 2.3 Add Primary Signal matching to hook prompt
    - Case-insensitive match of Workspace_Name against names in `01-projects/`
    - On match: load Project Note + all Permanent Notes from `06-permanent/`; record source as `primary`; display Session Summary; stop
    - _Requirements: spec 01 — Req 1.2, Req 1.3, Req 1.4_

- [x] 3. Implement Relevance Detector — secondary signal
  - [x] 3.1 Add open-file path scanning to hook prompt
    - Inspect paths of all files currently open in the workspace
    - Match any path segment case-insensitively against subfolder names in `01-projects/`
    - Use first match as resolved project identifier
    - _Requirements: spec 01 — Req 3.1, Req 3.2_
  - [x] 3.2 Add `.kiro/steering` project field fallback to hook prompt
    - If no open-file match, read `.kiro/steering` and use `project` field value as candidate if it matches a name in `01-projects/`
    - _Requirements: spec 01 — Req 3.3_
  - [x] 3.3 On secondary match: load Project Note + all Permanent Notes; record source as `secondary`; display Session Summary; stop
    - _Requirements: spec 01 — Req 3.4, Req 3.5_

- [x] 4. Implement Relevance Detector — fallback and full decision tree
  - [x] 4.1 Add fallback path to hook prompt
    - When neither primary nor secondary resolves a project, load all Permanent Notes from `06-permanent/`; record source as `fallback`
    - _Requirements: spec 01 — Req 4.1, Req 4.2_
  - [x] 4.2 Wire complete ordered decision tree in hook prompt
    - Order: generic check → primary → secondary → fallback; stop at first match
    - _Requirements: spec 01 — Req 5.1, Req 5.2_

- [x] 5. Checkpoint — Relevance Detector complete
  - [x] 5.1 Manually test all four decision tree branches against real vault
  - [x] 5.2 Verify Session Summary output matches spec 02 Req 3.5 format exactly

- [x] 6. Implement cold vault detection and UX message
  - [x] 6.1 Add Cold Vault check to hook prompt
    - Cold Vault = `06-permanent/` contains zero markdown files AND `00-inbox/` contains zero markdown files
    - Non-empty inbox alone prevents Cold Vault classification
    - _Requirements: spec 01 — Req 6.1_
  - [x] 6.2 Wire cold vault path: skip context injection, no error, display verbatim message
    - Message: "Your vault is empty — no context loaded yet. That's fine, you're just getting started. Use `/recall` during this session to capture your first note. It'll land in your inbox and kiro-recall will confirm it worked."
    - No diagnostic output, stack traces, or file paths alongside message
    - _Requirements: spec 01 — Req 6.2, Req 6.3, Req 7.1, Req 7.2, Req 7.3_

- [x] 7. Implement session hook — full wiring and session summary
  - [x] 7.1 Finalise `.kiro/hooks/kiro-recall-session-start.json` with complete prompt covering all paths
  - [x] 7.2 Verify Session Summary format for all three match sources
    - Primary/secondary: `Loaded {project} note ({source} match) + {N} permanent notes.`
    - Fallback: `Loaded {N} permanent notes (fallback — no project match found).`
    - Zero permanent notes alongside project note: omit count entirely
    - _Requirements: spec 02 — Req 3.1, Req 3.2, Req 3.3, Req 3.4, Req 3.5, Req 3.6_

- [x] 8. Checkpoint — Session hook complete
  - [x] 8.1 End-to-end test: cold vault, primary match, secondary match, fallback
  - [x] 8.2 All UX messages verified verbatim against spec

- [x] 9. Implement capture hook
  - [x] 9.1 Create `.kiro/hooks/kiro-recall-capture.json` as `userTriggered` hook
    - _Requirements: spec 02 — Req 5.1, Req 5.2, Req 5.3_
  - [x] 9.2 Hook prompt: prompt user or infer from context; build Capture Note with correct structure
    - Fields: Date, Project, What happened, Why it matters, Links (omit if empty)
    - Filename: `YYYY-MM-DD-{project}-{slug}.md`
    - _Requirements: spec 02 — Req 5.4, Req 6.1, Req 6.2, Req 6.3, Req 6.4, Req 6.5_
  - [x] 9.3 Hook prompt: write to `00-inbox/` via mcp-obsidian; select correct confirmation message
    - First capture (inbox was empty): verbatim first-capture message
    - Subsequent captures: standard confirmation with filename
    - _Requirements: spec 02 — Req 7.1, Req 7.2, Req 7.3, Req 7.4, Req 7.5; spec 01 — Req 8.1, Req 8.2, Req 8.3_
  - [x] 9.4 Hook prompt: on write failure, surface warm message + full note content in markdown code block; no retry
    - _Requirements: spec 02 — Req 8.1, Req 8.2, Req 8.3, Req 8.4, Req 8.5_

- [x] 10. Final checkpoint
  - [x] 10.1 Full end-to-end test of session start + capture flow
  - [x] 10.2 All UX messages verified verbatim against spec
