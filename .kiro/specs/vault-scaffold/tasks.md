# Implementation Plan: vault-scaffold

## Overview

Create a single `userTriggered` Kiro hook JSON file that encodes a six-step
agent procedure for scaffolding the kiro-recall vault folder structure.

## Tasks

- [x] 1. Create the vault-scaffold hook file
  - [x] 1.1 Write `.kiro/hooks/kiro-recall-vault-scaffold.kiro.hook` with correct JSON schema fields
    - Set `when.type` to `"userTriggered"` and `then.type` to `"askAgent"`
    - _Requirements: 1.1, 6.1, 6.2_

  - [x] 1.2 Write the six-step agent prompt encoding the full scaffold procedure
    - Step 1: resolve vault path from `powers/kiro-recall/mcp.json`
    - Step 2: validate vault is reachable via mcp-obsidian; display exact error and stop on failure
    - Step 3: check and create each of the 8 standard folders (idempotent)
    - Step 4: check `06-permanent/` for existing markdown files
    - Step 5: write `vault-setup.md` starter note if `06-permanent/` is empty (exact verbatim content)
    - Step 6: display scaffold report listing each folder as `created` or `already existed`
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.2, 5.3_

  - [ ]* 1.3 Write unit tests for hook file structural validation
    - Hook schema test: valid JSON, correct fields, `when.type === "userTriggered"`, `then.type === "askAgent"`
    - No external dependencies test: no shell scripts, binaries, or non-mcp-obsidian server refs
    - Starter note content test: prompt contains verbatim `vault-setup.md` content
    - Vault unreachable message test: prompt contains exact error message from Requirement 5.2
    - All eight folders present test: prompt references all 8 standard folder names
    - _Requirements: 6.1, 6.2, 6.3, 4.4, 5.2, 2.1_

- [x] 2. Checkpoint — verify hook file is valid JSON and all prompt content is correct
  - Ensure all tests pass, ask the user if questions arise.
