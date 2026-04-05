# Implementation Plan: session-capture-bridge

## ⚠️ MANDATORY - READ BEFORE EVERY TASK ⚠️

**YOU MUST FOLLOW THESE RULES FOR EVERY TASK:**

1. **Shell Commands**: Use `controlPwshProcess` ONLY. NEVER use `executePwsh`.
2. **Gap Analysis**: Perform TWO gap analysis passes BEFORE marking any task complete.
3. **Show Your Work**: Gap analysis must be visible in your response.

If you skip any of these, you have violated the protocol.

---

## Overview

The deliverable is two JSON hook files: `.kiro/hooks/kiro-recall-session-capture.kiro.hook` (agentStop) and `.kiro/hooks/kiro-recall-session-capture-manual.kiro.hook` (userTriggered). Both use the same prompt logic with one difference: the Session-type value is hardcoded per hook. The prompt reviews session context, resolves the project name, generates a structured Session Summary (four fields + metadata), and writes it to `00-inbox/` via mcpvault. The session-capture-bridge (when running) handles syncing vault captures to Ami's S3 bucket. No Python code, no runtime changes. The prompt is the product.

Tasks are structured around building the first hook file incrementally: metadata and trigger first, then each prompt step in logical groups, then the second hook file by copy-and-modify, then validation checkpoints, then optional property-based tests.

## Development Principles

**IMPORTANT**: Follow these principles strictly during implementation:

1. **Build ugly and working before making it clean**
   - Get the hook prompt working first
   - Refactor wording later if needed
   - Don't optimize prompt phrasing prematurely

2. **If something isn't specified, ask - don't invent**
   - No assumptions about Ami's Discord parsing
   - No "improvements" to the Session Summary format
   - No extra fields or metadata beyond what's specified

3. **Build exactly what's specified. Nothing more.**
   - No extra hook files beyond the two specified
   - No extra vault folders or S3 prefixes
   - No extra error handling beyond what's in the design

4. **Stop and ask if stuck for 10+ minutes**
   - Don't waste time debugging MCP tool availability
   - Check existing hooks for reference patterns
   - Ask for clarification on ambiguous requirements

5. **Property tests are optional for MVP**
   - Tasks marked with `*` can be skipped
   - Focus on getting the two hook files working
   - Add comprehensive tests in v2

## Non-Requirements (What NOT to Build)

To maintain simplicity and focus, this implementation explicitly **DOES NOT** include:

❌ Direct S3 writes from the hook (handled by session-capture-bridge sync)
❌ Discord MCP for Ami Bridge (removed in v2.0.0 — vault-only write, bridge syncs to S3)
❌ AWS CLI configuration or IAM credentials on the local machine
❌ A third hook file for any other trigger type
❌ Automatic retry of failed Discord sends
❌ Vault folder creation (assumes `00-inbox/` exists via vault-scaffold hook)
❌ Parsing or validation of Ami's response to the Discord message
❌ Integration with the content-publish-pipeline beyond the agreed S3 prefix and format

**System Characteristics:**

✅ Two JSON hook files with near-identical prompts (Session-type value differs)
✅ Structured four-field Session Summary + metadata header
✅ Vault-only write to local inbox (mcpvault); S3 sync handled by session-capture-bridge
✅ Vault write failure displays summary in code block so no knowledge is lost
✅ Consistent with existing kiro-recall hook conventions

## Context7 MCP Usage (CRITICAL)

This feature produces JSON hook files with no compiled code or library dependencies. No Context7 queries are required. If property-based tests (Task 8) are implemented, query Context7 for:

- `fast-check` - Property-based testing setup and generators

**Don't assume you know the API. Don't use outdated patterns. Check Context7 first.**

---

## Tasks

- [x] 1. Create hook file with metadata, trigger, and prompt skeleton
  - [x] 1.1 Create `.kiro/hooks/kiro-recall-session-capture.kiro.hook` with the JSON structure: `name` ("kiro-recall: Session Capture"), `version` ("1.0.0"), `description`, `when.type` set to `agentStop`, and `then.type` set to `askAgent` with an empty prompt string
    - Follow the same JSON structure as the existing hooks in `.kiro/hooks/`
    - The `description` field: "Fires at session end. Reviews session context, generates a structured session summary, and writes it to 00-inbox/ via mcpvault."
    - _Requirements: 1.1, 1.3, 1.4, 9.1_

  - [x] 1.2 Add the Preamble (Check mcpvault availability) to the prompt
    - Before any steps, check mcpvault availability with a lightweight operation (list `00-inbox/`)
    - If mcpvault is unavailable, output a warm message and stop — no fallback destination exists
    - If mcpvault responds successfully, proceed to Step 1
    - Match the preamble pattern from the auto-vault-sync hook
    - _Requirements: 8.2, 9.3_

  - [x] 1.3 Add Step 1 (Gather session context) to the prompt
    - Inspect the conversation history and any spec files worked on during the session
    - Gather context about what was built, decided, or learned
    - If the session contains no meaningful work (empty session or trivial interaction), output "Nothing substantial to capture from this session." and stop
    - _Requirements: 2.1, 2.3_

- [x] 2. Add project resolution and summary generation steps to the prompt
  - [x] 2.1 Add Step 2 (Resolve project name) to the prompt
    - Primary signal: extract workspace folder name, compare case-insensitively against entries in `01-projects/` via mcpvault
    - Generic name bypass: if workspace name matches the generic names list (`src`, `dev`, `project`, `app`, `code`, `workspace`, `repo`, `main`, `test`, `build`, `website`, `frontend`, `backend`, `api`, `server`, `client`, `lib`, `library`, `core`, `base`), skip primary signal entirely
    - Secondary signal: scan open file paths for a project name match against `01-projects/` entries, then check `.kiro/steering/` for a `project` field
    - Fallback: use `unknown` when neither signal resolves
    - Reuse the same relevance detection logic and wording from the auto-vault-sync and session-start hooks
    - _Requirements: 2.2, 9.4_

  - [x] 2.2 Add Step 3 (Build Session Summary) to the prompt
    - Construct the Session Summary as a markdown file with seven `##` headings in this exact order: `## Date`, `## Project`, `## Session-type`, `## What was built`, `## What was decided`, `## What was learned`, `## Article candidate topics`
    - Date is today's ISO 8601 date. Project is the resolved name from Step 2. Session-type is hardcoded per hook file: `agentStop` in the agentStop hook, `userTriggered` in the manual hook. This is the one intentional difference between the two hook prompts
    - "What was built": 1-3 sentences describing concrete artifacts, features, or code
    - "What was decided": 1-3 sentences describing design decisions, trade-offs, or direction changes
    - "What was learned": 1-3 sentences describing new knowledge, insights, or patterns
    - "Article candidate topics": bulleted list of 1-3 concrete article angles grounded in session work (not generic topics)
    - When a narrative field has no relevant content, use "Nothing notable this session." as placeholder
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 7.1, 7.2, 7.3, 7.4, 10.1, 10.2, 10.3, 10.4_

  - [x] 2.3 Add Step 4 (Derive filename) to the prompt
    - Format: `YYYY-MM-DD-{project}-session-capture.md`
    - Fixed suffix `session-capture` (not a task slug like auto-vault-sync)
    - One session capture per project per day, overwritten on repeat
    - _Requirements: 4.2_

- [x] 3. Add vault write and outcome reporting steps to the prompt
  - [x] 3.1 Add Step 5 (Write to vault) to the prompt
    - Write the Session Summary to `00-inbox/{filename}` via mcpvault
    - If write succeeds, report success and stop
    - If write fails, display the Session Summary in a markdown code block so no knowledge is lost
    - If mcpvault was unavailable at preamble, the hook already stopped at the preamble
    - _Requirements: 4.1, 4.3, 4.4, 4.5, 6.1_

  - [x] 3.2 ~~Add Step 6 (Send to Ami via Discord) to the prompt~~ REMOVED in v2.0.0
    - Discord/Ami Bridge step removed. S3 sync handled by session-capture-bridge.
    - ~~_Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2_~~

  - [x] 3.3 Add Step 6 (Report outcome) to the prompt
    - Vault write succeeded: short success message
    - Vault write failed: display summary in code block
    - _Requirements: 6.2, 6.3, 6.4_

  - [x] 3.4 Add Error Output Rules section to the prompt
    - No stack traces, exception class names, or absolute file system paths in any output
    - Write failure displays Session Summary content in a code block
    - Discord send failure is a short warning, non-blocking
    - All failure messages use warm, conversational tone matching the existing hooks
    - _Requirements: 8.1, 8.3, 8.4, 8.5_

- [x] 4. Checkpoint — Validate first hook file structure
  - Ensure the hook file is valid JSON
  - Verify `when.type` is `agentStop` and `then.type` is `askAgent`
  - Verify the prompt contains the Preamble and all 7 steps in order
  - Verify the hook filename is `kiro-recall-session-capture.kiro.hook`
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Create the manual trigger hook file
  - [x] 5.1 Create `.kiro/hooks/kiro-recall-session-capture-manual.kiro.hook` by copying the agentStop hook and changing four fields
    - `name`: "kiro-recall: Session Capture (Manual)"
    - `description`: "Manually triggered session capture. Reviews session context, generates a structured session summary, and writes it to 00-inbox/ via mcpvault."
    - `when.type`: `userTriggered`
    - In the `then.prompt`, change the hardcoded Session-type value from `agentStop` to `userTriggered`
    - All other prompt logic must remain identical to the agentStop hook
    - _Requirements: 1.2, 1.3, 1.4, 9.1_

- [x] 6. Review prompt quality and consistency with existing hooks
  - [x] 6.1 Compare prompt patterns against existing hooks for consistency
    - Verify step numbering format matches (`## Step N — Title`) and preamble format
    - Verify error message tone matches the auto-vault-sync and capture hooks
    - Verify mcpvault tool usage patterns match existing hooks
    - Verify the Session Summary format has all seven `##` headings in the correct order
    - Verify the Ami Bridge message format matches the design spec exactly
    - _Requirements: 1.4, 9.1, 9.2, 9.3, 9.4_

  - [x] 6.2 Verify requirements coverage
    - Walk through each requirement (1 through 10) and confirm the prompt addresses every acceptance criterion
    - Confirm the `session-captures/` S3 prefix and article candidate topics field are consistent with content-publish-pipeline Requirement 11
    - Confirm both hook files share near-identical prompt text (only difference: Session-type value is `agentStop` in one, `userTriggered` in the other)
    - _Requirements: all_

- [x] 7. Final checkpoint — Both hook files complete
  - Ensure both hook files are valid JSON
  - Verify agentStop hook has `when.type` of `agentStop`, manual hook has `userTriggered`
  - Verify both hooks have `then.type` of `askAgent` and near-identical prompt text (only Session-type value differs)
  - Verify hook filenames match the naming convention
  - Ensure all tests pass, ask the user if questions arise.

- [ ]* 8. Property-based tests for extractable logic (optional)
  - [ ]* 8.1 Set up test infrastructure for fast-check property tests
    - Create a minimal test file (e.g. `tests/session-capture-bridge.property.test.js`) with fast-check configured
    - Extract the testable logic (project resolution, filename derivation, summary structure validation, Ami Bridge message format) as pure functions
    - Note: the kiro-recall repo may not have a JS/TS test framework set up. This task includes any necessary setup (package.json, test runner config)

  - [ ]* 8.2 Write property test for project resolution priority chain
    - **Property 1: Project resolution priority chain**
    - Generate random workspace names and `01-projects/` listings. Verify the resolver returns the correct priority match. Include generic names to verify primary signal bypass
    - **Validates: Requirements 2.2, 9.4**

  - [ ]* 8.3 Write property test for Session Summary structure compliance
    - **Property 2: Session Summary structure compliance**
    - Generate random session context (built/decided/learned content, article topics). Build a summary and verify it contains exactly seven `##` headings in order: Date, Project, Session-type, What was built, What was decided, What was learned, Article candidate topics
    - **Validates: Requirements 3.1, 3.7, 10.1, 10.2, 10.3**

  - [ ]* 8.4 Write property test for narrative field sentence count
    - **Property 3: Narrative field sentence count**
    - Generate random narrative content for each of the three fields (including empty content). Verify each field has 1-3 sentences, with empty fields using the placeholder "Nothing notable this session."
    - **Validates: Requirements 3.2, 3.3, 3.4, 3.6**

  - [ ]* 8.5 Write property test for article candidate topics format
    - **Property 4: Article candidate topics format**
    - Generate random article topic lists. Verify the field contains 1-3 bullet items starting with `- ` when meaningful work occurred
    - **Validates: Requirements 3.5, 7.4, 10.4**

  - [ ]* 8.6 Write property test for vault filename format compliance
    - **Property 5: Vault filename format compliance**
    - Generate random dates and project names. Verify the filename matches `YYYY-MM-DD-{project}-session-capture.md`
    - **Validates: Requirements 4.2**

  - [ ]* 8.7 Write property test for Ami Bridge message format compliance
    - **Property 6: Ami Bridge message format compliance**
    - Generate random summaries and metadata. Verify the Discord message contains the action identifier (`session-capture-write`), S3 key (`session-captures/YYYY-MM-DD-{project}-session-capture.md`), and code-fenced content
    - **Validates: Requirements 5.2, 5.3**

  - [ ]* 8.8 Write property test for write failure content preservation
    - **Property 7: Write failure preserves content**
    - Generate random summary content, simulate write failures, verify the content appears verbatim in the output
    - **Validates: Requirements 4.5, 6.4, 8.3**

  - [ ]* 8.9 Write property test for no internal details in error output
    - **Property 8: No internal details in error output**
    - Generate random error messages with injected stack traces and file paths. Verify the output contains no stack trace patterns or absolute paths
    - **Validates: Requirements 8.1, 8.5**

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- The core deliverable is tasks 1 through 7: two valid hook files with identical prompts
- The Discord/Ami Bridge step was removed in v2.0.0. S3 sync is handled by the session-capture-bridge (separate feature)
- Property-based tests (task 8) require setting up a JS/TS test framework in the kiro-recall repo, which currently has none
- Each property test maps 1:1 to a correctness property from the design document
- The `session-captures/` S3 prefix and article candidate topics field are integration points with the content-publish-pipeline spec (Requirement 11)
- The Session Summary format differs from the existing Capture Note format: four content fields (built/decided/learned/topics) instead of two (happened/matters)
