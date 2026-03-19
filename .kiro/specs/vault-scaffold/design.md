# Design Document: vault-scaffold

## Overview

The vault-scaffold hook is a `userTriggered` Kiro hook that creates the standard
kiro-recall folder structure on demand. It is the third hook in the kiro-recall
Power, alongside the session-start and capture hooks.

The deliverable is a single JSON file:
`.kiro/hooks/kiro-recall-vault-scaffold.kiro.hook`

The hook contains no compiled code. All logic lives in the `prompt` field of an
`askAgent` action. The agent uses the mcp-obsidian MCP server (already declared
in `powers/kiro-recall/mcp.json`) to inspect and mutate the vault.

### Design Goals

- Idempotent: safe to run on a vault that is fully, partially, or not yet
  scaffolded
- Zero configuration: reads vault path from the same mcp-obsidian config used
  by the other hooks
- No surprises: reports exactly what was created vs. what already existed
- Warm vault guarantee: writes a starter note to `06-permanent/` so the vault
  is never cold after the first scaffold run

---

## Architecture

The hook follows the same pattern as the existing capture and session-start
hooks: a single `.kiro.hook` JSON file whose `then.prompt` encodes a numbered
step procedure for the agent to execute.

```
User triggers hook
       │
       ▼
┌─────────────────────────────────────────────────────┐
│  kiro-recall-vault-scaffold.kiro.hook               │
│                                                     │
│  when: { type: "userTriggered" }                    │
│  then: { type: "askAgent", prompt: "..." }          │
└─────────────────────────────────────────────────────┘
       │
       ▼  agent executes prompt steps
┌─────────────────────────────────────────────────────┐
│  Step 1 — Resolve vault path from mcp.json          │
│  Step 2 — Validate vault is reachable               │
│  Step 3 — Check / create each of 8 standard folders │
│  Step 4 — Check 06-permanent/ for markdown files    │
│  Step 5 — Write starter note if 06-permanent/ empty │
│  Step 6 — Display scaffold report                   │
└─────────────────────────────────────────────────────┘
       │
       ▼  via mcp-obsidian
┌─────────────────────────────────────────────────────┐
│  Vault filesystem                                   │
│  (path from powers/kiro-recall/mcp.json)            │
└─────────────────────────────────────────────────────┘
```

No new MCP servers, scripts, or runtime dependencies are introduced.

---

## Components and Interfaces

### Hook JSON structure

The hook file conforms to the Kiro hook schema:

```json
{
  "name": "kiro-recall: Vault Scaffold",
  "version": "1.0.0",
  "description": "...",
  "when": {
    "type": "userTriggered"
  },
  "then": {
    "type": "askAgent",
    "prompt": "..."
  }
}
```

Fields:
- `name` — display name shown in the Kiro hooks UI
- `version` — semver string
- `description` — one-sentence summary
- `when.type` — `"userTriggered"` (Requirement 1.1)
- `then.type` — `"askAgent"` (Requirement 6.2)
- `then.prompt` — the full step-by-step procedure (see Prompt Design below)

### Prompt Design

The prompt encodes six numbered steps. The agent executes them sequentially
using mcp-obsidian tool calls.

**Step 1 — Resolve vault path**
The agent reads `powers/kiro-recall/mcp.json` from the workspace to extract the
vault path from the mcp-obsidian `args` array. This is the same path used by
the session-start and capture hooks, satisfying Requirement 5.1.

**Step 2 — Validate vault access**
The agent attempts to list the vault root via mcp-obsidian. On failure it
displays the prescribed error message (Requirement 5.2) and stops. No stack
traces or internal paths are surfaced (Requirement 5.3).

**Step 3 — Check and create standard folders**
For each of the eight standard folders, the agent attempts to list its contents.
If the listing succeeds the folder exists — record it as `already existed`. If
the listing fails (folder not found), create it via mcp-obsidian and record it
as `created`. This is the idempotence mechanism (Requirement 2.1–2.4).

Standard folders in order:
`00-inbox/`, `01-projects/`, `02-job-search/`, `03-learning/`,
`04-knowledge/`, `05-community/`, `06-permanent/`, `07-templates/`

**Step 4 — Check for existing permanent notes**
After ensuring `06-permanent/` exists, the agent lists its contents and counts
markdown files. This determines whether a starter note is needed (Requirement
4.1–4.2).

**Step 5 — Write starter note (conditional)**
If `06-permanent/` contained zero markdown files, write `vault-setup.md` with
the exact content specified in Requirement 4.4. Record it as `created` in the
report. If `06-permanent/` was non-empty, record that the starter note was
skipped (Requirement 4.6).

**Step 6 — Display scaffold report**
Output a clean, human-readable summary listing each folder with `created` or
`already existed`, and the starter note outcome. No file paths, stack traces, or
internal identifiers (Requirement 3.1–3.4).

### mcp-obsidian interface

The hook uses two mcp-obsidian operations:

| Operation | Purpose |
|-----------|---------|
| List directory | Check folder existence; count markdown files in `06-permanent/` |
| Create/write file | Create folders (via writing a placeholder or using the create-folder tool if available); write `vault-setup.md` |

mcp-obsidian is already declared in `powers/kiro-recall/mcp.json` — no new
server registration is needed.

---

## Data Models

### Standard Folders constant

The eight folders are an ordered list embedded in the prompt:

```
00-inbox/
01-projects/
02-job-search/
03-learning/
04-knowledge/
05-community/
06-permanent/
07-templates/
```

### Scaffold Report entry

Each entry in the report has two fields:

| Field | Values |
|-------|--------|
| folder | one of the eight standard folder names |
| outcome | `created` \| `already existed` |

The starter note entry uses:

| Field | Values |
|-------|--------|
| item | `06-permanent/vault-setup.md` |
| outcome | `created` \| `skipped (permanent notes already present)` |

### Starter Note content

Exact content as specified in Requirement 4.4 — reproduced verbatim in the
prompt so the agent writes it character-for-character.

### Vault path resolution

The vault path is the first element of the `args` array in the mcp-obsidian
server config in `powers/kiro-recall/mcp.json`. The agent reads this file from
the workspace root to resolve the path without requiring separate configuration.

---


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all
valid executions of a system — essentially, a formal statement about what the
system should do. Properties serve as the bridge between human-readable
specifications and machine-verifiable correctness guarantees.*

### Property 1: Scaffold idempotence

*For any* initial vault state (any subset of the eight standard folders
pre-existing, including none or all), running the scaffold hook SHALL result in
all eight standard folders existing in the vault. Running it a second time on
the same vault SHALL produce the same final state.

**Validates: Requirements 2.2, 2.3, 2.4**

### Property 2: Report completeness

*For any* scaffold run, the scaffold report SHALL contain exactly one entry for
each of the eight standard folders, and each entry SHALL be marked either
`created` or `already existed` — no other outcome values are permitted.

Edge case: when all eight folders already existed before the run, all eight
entries SHALL be marked `already existed`.

**Validates: Requirements 3.1, 3.2, 3.3**

### Property 3: Clean output

*For any* scaffold run (success or failure), the output SHALL contain no
filesystem path separators (`/` used as internal paths, `\`), no stack trace
keywords (`Error`, `Exception`, `Traceback`, `at line`), and no internal
identifiers beyond the eight standard folder names.

**Validates: Requirements 3.4, 5.3**

### Property 4: Starter note conditional

*For any* vault where `06-permanent/` contains zero markdown files before the
scaffold hook runs, the folder SHALL contain `vault-setup.md` after the hook
completes. *For any* vault where `06-permanent/` already contains one or more
markdown files before the hook runs, those files SHALL be unchanged after the
hook completes and no additional `vault-setup.md` SHALL be written (unless it
was already present).

**Validates: Requirements 4.1, 4.2**

---

## Error Handling

### Vault unreachable

When the mcp-obsidian listing of the vault root fails for any reason (path not
found, permission denied, MCP server unavailable), the agent SHALL output
exactly:

> Couldn't reach your vault — scaffold aborted. Check that your vault path is
> correct in `powers/kiro-recall/mcp.json`.

Then stop. No folders are created, no starter note is written, no partial
scaffold report is shown.

### Folder creation failure

If creating an individual folder fails after the vault root was confirmed
reachable, the agent SHALL note the failure in the scaffold report for that
folder (e.g. `failed — could not create`) and continue attempting the remaining
folders. The report still lists all eight entries.

### Starter note write failure

If writing `vault-setup.md` fails, the agent SHALL note it in the scaffold
report as `failed — could not write starter note` and still display the
complete folder report. The user is not left without output.

### No stack traces

In all failure paths, the agent SHALL NOT surface exception messages, stack
traces, or internal file paths. Output is limited to the prescribed messages and
the scaffold report.

---

## Testing Strategy

Because the deliverable is a JSON hook file (not compiled code), testing
operates at two levels:

### Unit tests — structural validation of the hook file

These tests assert properties of the `.kiro.hook` JSON artifact itself. They
can be run with any JSON-capable test runner (e.g. Jest, Vitest, or a simple
Node.js script).

- **Hook schema test**: Assert the file exists at
  `.kiro/hooks/kiro-recall-vault-scaffold.kiro.hook`, is valid JSON, and
  contains `name`, `version`, `description`, `when.type === "userTriggered"`,
  `then.type === "askAgent"`, and `then.prompt` (non-empty string).
  *(Validates: Requirements 6.1, 6.2)*

- **No external dependencies test**: Assert the JSON does not contain
  references to shell scripts, binary paths, or any MCP server name other than
  `mcp-obsidian`.
  *(Validates: Requirement 6.3)*

- **Starter note content test**: Assert the `then.prompt` string contains the
  exact starter note content specified in Requirement 4.4 (verbatim match of
  the `vault-setup.md` body).
  *(Validates: Requirement 4.4)*

- **Vault unreachable message test**: Assert the `then.prompt` string contains
  the exact error message specified in Requirement 5.2.
  *(Validates: Requirement 5.2)*

- **All eight folders present test**: Assert the `then.prompt` string references
  all eight standard folder names: `00-inbox/`, `01-projects/`, `02-job-search/`,
  `03-learning/`, `04-knowledge/`, `05-community/`, `06-permanent/`,
  `07-templates/`.
  *(Validates: Requirement 2.1)*

### Property-based tests — behavioural correctness

These tests validate the four correctness properties above. Because the hook
executes as an agent prompt (not a pure function), property tests are written
against a thin harness that simulates the vault filesystem state and asserts
post-conditions on the agent's output.

Use a property-based testing library appropriate to the project language (e.g.
`fast-check` for TypeScript/JavaScript).

Each property test runs a minimum of 100 iterations.

---

**Property Test 1: Scaffold idempotence**
`Feature: vault-scaffold, Property 1: Scaffold idempotence`

Generate a random subset of the eight standard folders as the initial vault
state. Run the scaffold procedure. Assert all eight folders exist in the
resulting state. Run the scaffold procedure again on the same state. Assert the
state is unchanged.

**Property Test 2: Report completeness**
`Feature: vault-scaffold, Property 2: Report completeness`

Generate a random initial vault state. Run the scaffold procedure. Parse the
scaffold report output. Assert it contains exactly eight folder entries. Assert
each entry's outcome is either `created` or `already existed`. For the
all-present edge case (all eight pre-existing), assert all entries are `already
existed`.

**Property Test 3: Clean output**
`Feature: vault-scaffold, Property 3: Clean output`

Generate a random initial vault state (including the failure case where the
vault root is unreachable). Run the scaffold procedure. Assert the output
contains no path separators used as internal paths, no stack trace keywords, and
no internal identifiers.

**Property Test 4: Starter note conditional**
`Feature: vault-scaffold, Property 4: Starter note conditional`

Generate two cases: (a) a vault where `06-permanent/` is empty, (b) a vault
where `06-permanent/` contains one or more random markdown files. For case (a),
assert `vault-setup.md` exists in `06-permanent/` after scaffold. For case (b),
assert the pre-existing files are unchanged and no new `vault-setup.md` was
added (unless it was already there).
