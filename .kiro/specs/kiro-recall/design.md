# Design: kiro-recall

## Architecture

kiro-recall is a Kiro Power implemented entirely as:
- Hook JSON files in `.kiro/hooks/` that fire at lifecycle events
- Steering instructions in `powers/kiro-recall/steering/` that define agent behaviour
- `mcp.json` that wires the mcp-obsidian MCP server for vault read/write access

There is no compiled code, no shell scripts, no build step. The "Relevance Detector" and all other named components from the spec are agent behaviours driven by steering instructions, not software objects.

---

## Component Map

```
.kiro/hooks/
├── kiro-recall-session-start.json   # Fires on promptSubmit — runs relevance detection + context injection
└── kiro-recall-capture.json         # Fires on userTriggered — runs /recall capture flow

powers/kiro-recall/
├── POWER.md                         # Power metadata, onboarding, UX messages
├── mcp.json                         # mcp-obsidian config — user sets vaultPath here
└── steering/
    ├── session-hook.md              # Agent instructions: relevance detection, cold vault, session summary
    ├── capture-hook.md              # Agent instructions: /recall flow, note structure, confirmations
    └── implementation-plan.md      # Build task list with requirement traceability

.kiro/specs/kiro-recall/
├── requirements.md                  # This project's requirements (EARS notation)
├── design.md                        # This file
└── tasks.md                         # Sequenced implementation tasks
```

---

## Hook Design

### Session Start Hook (`kiro-recall-session-start.json`)

- Event: `promptSubmit`
- Action: `askAgent`
- Fires once per session on first prompt
- Prompt instructs the agent to:
  1. Read `powers/kiro-recall/steering/session-hook.md` for full behaviour spec
  2. Verify vault accessibility via mcp-obsidian
  3. Run the Relevance Detector decision tree
  4. Inject resolved content as context
  5. Display Session Summary (or Cold Vault / failure message)

### Capture Hook (`kiro-recall-capture.json`)

- Event: `userTriggered`
- Action: `askAgent`
- Manually triggered by the user (maps to the `/recall` concept)
- Prompt instructs the agent to:
  1. Read `powers/kiro-recall/steering/capture-hook.md` for full behaviour spec
  2. Prompt user for capture content or infer from session context
  3. Build and write the Capture Note to `00-inbox/`
  4. Display appropriate confirmation

---

## Vault Path Configuration

User edits `vaultPath` in `powers/kiro-recall/mcp.json` directly. This is the same pattern used by all other Kiro Powers for API keys and config. No runtime config mechanism needed.

The session start hook validates accessibility at runtime by attempting a vault read via mcp-obsidian. If the read fails, it applies the failure handling defined in spec 02 Req 4.

---

## Vault Structure

```
{vaultPath}/
├── 00-inbox/       # Capture Note destination
├── 01-projects/    # Project Notes — matched by Relevance Detector
├── 06-permanent/   # Permanent Notes — loaded every session
└── ...             # Other folders (not read by hooks)
```

Only `00-inbox/`, `01-projects/`, and `06-permanent/` are accessed by the hooks.

---

## Data Flow: Session Start

```
promptSubmit event fires
        │
        ▼
kiro-recall-session-start hook triggers agent
        │
        ▼
Agent reads session-hook.md steering
        │
        ▼
Agent attempts vault access via mcp-obsidian
        ├─ FAIL → surface failure message → session continues
        └─ OK   → run Relevance Detector decision tree
                        │
                        ▼
                  Resolve Injection Payload
                  (primary / secondary / fallback / cold vault)
                        │
                        ▼
                  Inject content as context
                        │
                        ▼
                  Display Session Summary
```

## Data Flow: Capture

```
User triggers kiro-recall-capture hook
        │
        ▼
Agent reads capture-hook.md steering
        │
        ▼
Agent prompts user / infers from context
        │
        ▼
Agent builds Capture Note (markdown)
        │
        ▼
Agent writes to 00-inbox/ via mcp-obsidian
        ├─ FAIL → surface failure message + note content
        └─ OK   → display confirmation (first-capture or standard)
```
