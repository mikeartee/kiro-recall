# Relevance Detection

This is the canonical definition of kiro-recall's relevance detection algorithm.
All hooks that need to resolve a project name or load vault context MUST reference
this file rather than embedding the logic inline.

---

## Generic Name List

The following workspace folder names are considered generic and do not reliably
identify a project. When the Workspace Name matches any entry in this list
(case-insensitive), skip Primary Signal evaluation and proceed directly to
Secondary Signal.

`src`, `dev`, `project`, `app`, `code`, `workspace`, `repo`, `main`, `test`,
`build`, `website`, `frontend`, `backend`, `api`, `server`, `client`, `lib`,
`library`, `core`, `base`

---

## Decision Tree

Execute the following steps in order. Stop at the first step that produces a result.

### Step 1 — Extract Workspace Name

Take the final path segment of the current workspace root folder path.

Example: from `C:\Dev\kiro-recall` the Workspace Name is `kiro-recall`.

### Step 2 — Check for Generic Name

Compare the Workspace Name (case-insensitive) against the Generic Name List above.

- If it matches → skip Step 3, go directly to Step 4 (Secondary Signal)
- If it does not match → proceed to Step 3 (Primary Signal)

### Step 3 — Primary Signal

Use mcpvault to list the contents of `01-projects/` in the vault.

Search for a file or subfolder whose name case-insensitively matches the Workspace Name.

- If a match is found → use it as the resolved project identifier, record source as `primary`, stop
- If no match is found → proceed to Step 4

### Step 4 — Secondary Signal

**Open file paths:** Inspect the paths of all files currently open in the workspace.
For each open file path, split the path into its individual segments (folder and
file names). Check whether any segment case-insensitively matches a subfolder name
inside `01-projects/` in the vault. Use the first such match as the resolved project
identifier.

**Steering file:** If no open-file match is found, attempt to read the files inside
`.kiro/steering/` in the current workspace. If any steering file contains a `project`
field (e.g. a line like `project: my-project` or a YAML/markdown frontmatter field
named `project`), use that value as a candidate project identifier — but only if it
case-insensitively matches a subfolder name in `01-projects/`.

- If a match is found via either method → use it as the resolved project identifier, record source as `secondary`, stop
- If no match is found → proceed to Step 5

### Step 5 — Fallback

Neither primary nor secondary resolved a project.

Use mcpvault to list the contents of `06-permanent/` and `00-inbox/`.

**Cold Vault check:** If `06-permanent/` contains zero markdown files AND `00-inbox/`
contains zero markdown files, the vault is a Cold Vault. Output the cold vault
message and stop — do not attempt context injection.

**Cold vault message (verbatim):**
> Your vault is empty — no context loaded yet. That's fine, you're just getting
> started. Use `/recall` during this session to capture your first note. It'll
> land in your inbox and kiro-recall will confirm it worked.

**Fallback load:** If `06-permanent/` contains at least one markdown file, load all
markdown files from `06-permanent/`, record source as `fallback`, and proceed with
context injection.

---

## Source Record Values

| Signal path | Record as |
|---|---|
| Primary Signal matched | `primary` |
| Secondary Signal matched | `secondary` |
| Fallback (no project match) | `fallback` |
