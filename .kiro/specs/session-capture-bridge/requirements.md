# Requirements Document

## Introduction

Session-capture-bridge is a kiro-recall hook that captures structured session summaries and writes them to two independent destinations: the local Obsidian vault (via mcpvault) and Ami's S3 second brain bucket (via Discord message to Ami). This bridges the gap between Mike's local knowledge store and Ami's cloud-side context, giving the content-publish-pipeline a continuous feed of source material grounded in real building work.

Today, kiro-recall hooks write exclusively to the local vault. Ami's S3 bucket (`ami-second-brain-724772056609` in ap-southeast-2) is a separate store that Ami writes to from her EC2 instance. Nothing from Kiro work sessions flows to Ami's bucket. The two stores do not sync.

This hook fires at session end (`agentStop`) or on demand (`userTriggered`), summarises what was built, decided, or learned, and writes the result to both destinations independently. If one destination fails, the other still succeeds. The structured output format includes article candidate topics that feed the content bullpen, satisfying Requirement 11 of the content-publish-pipeline spec.

## Glossary

- **Session_Capture_Hook**: The kiro-recall hook that fires on `agentStop` or `userTriggered` events and produces a structured session summary written to both the local vault and Ami's S3 bucket.
- **Session_Summary**: A structured markdown note containing four fields: what was built, what was decided, what was learned, and article candidate topics. Produced by the Session_Capture_Hook at the end of a work session.
- **Vault**: The local markdown folder structure managed by kiro-recall, accessed via the MCP_Vault server. Located at `C:\Users\Mike RT\Documents\second-brain`.
- **MCP_Vault**: The mcpvault MCP server that provides read/write access to the vault folder structure from disk.
- **Ami**: The always-on AI executive assistant running on EC2 in ap-southeast-2, accessible via Discord (#ami channel) and WhatsApp.
- **Second_Brain_Bucket**: The S3 bucket `ami-second-brain-724772056609` in ap-southeast-2, where Ami stores notes and context. Ami has write access via IAM role on the EC2 instance.
- **Ami_Bridge**: The mechanism for sending a structured message to Ami via Discord, requesting that Ami write the Session_Summary to the Second_Brain_Bucket under the `session-captures/` prefix. This avoids requiring local AWS CLI configuration.
- **Content_Bullpen**: The queue of article candidate topics derived from real session work, fed by the article candidate topics field in each Session_Summary.
- **Article_Candidate_Topic**: A potential article topic grounded in specific session work, included in the Session_Summary to feed the Content_Bullpen for the content-publish-pipeline.
- **Capture_Note**: The existing kiro-recall note format used by the capture and auto-vault-sync hooks, written to `00-inbox/`.

## Requirements

### Requirement 1: Hook Registration and Triggers

**User Story:** As Mike, I want the session capture hook to fire automatically at session end and also be available on demand, so that session knowledge is captured without manual effort but I can also trigger it mid-session when needed.

#### Acceptance Criteria

1. THE Session_Capture_Hook SHALL register as an `agentStop` event hook with an `askAgent` action in the kiro-recall hooks directory.
2. THE Session_Capture_Hook SHALL also be available as a `userTriggered` hook so Mike can invoke it on demand during a session.
3. THE Session_Capture_Hook SHALL follow the kiro-recall hook naming convention: `kiro-recall-session-capture.kiro.hook` for the agentStop hook and `kiro-recall-session-capture-manual.kiro.hook` for the userTriggered hook.
4. THE Session_Capture_Hook SHALL follow the same JSON structure and prompt format (## Step N sections) as the existing five kiro-recall hooks.

### Requirement 2: Session Context Gathering

**User Story:** As Mike, I want the hook to review what happened in the current session, so that the summary reflects actual work rather than generic filler.

#### Acceptance Criteria

1. WHEN the Session_Capture_Hook fires, THE Session_Capture_Hook SHALL inspect the conversation history and any spec files worked on during the session to gather context about what was built, decided, or learned.
2. WHEN the Session_Capture_Hook fires, THE Session_Capture_Hook SHALL identify the project name using the same relevance detection logic as the session-start and auto-vault-sync hooks (primary signal from workspace name, secondary signal from open files and steering files, fallback to `unknown`).
3. IF the session contains no meaningful work context (empty session or trivial interaction), THEN THE Session_Capture_Hook SHALL skip capture and exit with a short message: "Nothing substantial to capture from this session."

### Requirement 3: Structured Summary Generation

**User Story:** As Mike, I want each session summary to follow a consistent four-field structure, so that MCE and Ami can parse it programmatically and humans can scan it quickly.

#### Acceptance Criteria

1. THE Session_Capture_Hook SHALL produce a Session_Summary with the following four fields in order, using `##` second-level headings: "What was built", "What was decided", "What was learned", and "Article candidate topics".
2. THE "What was built" field SHALL contain 1 to 3 sentences describing concrete artifacts, features, or code produced during the session.
3. THE "What was decided" field SHALL contain 1 to 3 sentences describing design decisions, trade-offs chosen, or direction changes made during the session.
4. THE "What was learned" field SHALL contain 1 to 3 sentences describing new knowledge, insights, or patterns discovered during the session.
5. THE "Article candidate topics" field SHALL contain a bulleted list of 1 to 3 potential article topics, each grounded in specific session work rather than generic suggestions.
6. WHEN a field has no relevant content from the session, THE Session_Capture_Hook SHALL write "Nothing notable this session." for that field rather than omitting it, so the four-field structure remains consistent for programmatic parsing.
7. THE Session_Summary SHALL include a metadata header above the four fields containing: Date (YYYY-MM-DD), Project (resolved name), and Session-type (`agentStop` or `userTriggered`).

### Requirement 4: Vault Write

**User Story:** As Mike, I want the session summary written to my local vault inbox, so that it lands alongside other kiro-recall captures and is promotable via the existing /promote hook.

#### Acceptance Criteria

1. WHEN the Session_Capture_Hook produces a Session_Summary, THE Session_Capture_Hook SHALL write it to `00-inbox/` in the Vault using the MCP_Vault tools.
2. THE Session_Capture_Hook SHALL construct the vault filename using the format `YYYY-MM-DD-{project}-session-capture.md`, where `{project}` is the resolved project name.
3. WHEN a file with the same filename already exists in `00-inbox/`, THE Session_Capture_Hook SHALL overwrite the existing file with the new Session_Summary content (same deduplication pattern as auto-vault-sync).
4. IF the MCP_Vault server is unavailable when the Session_Capture_Hook fires, THEN THE Session_Capture_Hook SHALL output a short, warm warning that the vault write will be skipped, and continue to attempt the Ami_Bridge write. THE Session_Capture_Hook SHALL only display the Session_Summary in a markdown code block if the Ami_Bridge write also fails (no destination succeeded).
5. IF a write to `00-inbox/` fails for any reason, THEN THE Session_Capture_Hook SHALL continue to attempt the Ami_Bridge write. THE Session_Capture_Hook SHALL only display the Session_Summary content in a markdown code block if the Ami_Bridge write also fails (no destination succeeded).

### Requirement 5: Ami Bridge Write

**User Story:** As Mike, I want the same session summary sent to Ami via Discord so Ami can write it to the S3 second brain bucket, so that the content pipeline has access to session captures without requiring local AWS credentials.

#### Acceptance Criteria

1. WHEN the Session_Capture_Hook produces a Session_Summary, THE Ami_Bridge SHALL send a structured message to Ami via the Discord #ami channel requesting that Ami write the summary to the Second_Brain_Bucket.
2. THE Ami_Bridge message SHALL include the full Session_Summary content and an explicit instruction for Ami to write it to the `session-captures/` prefix in the Second_Brain_Bucket with the filename format `YYYY-MM-DD-{project}-session-capture.md`.
3. THE Ami_Bridge SHALL format the message so Ami can parse it without ambiguity: the message SHALL contain a clear action request, the target S3 key, and the summary content delimited by markdown code fences.
4. IF the Ami_Bridge message fails to send (Discord unavailable, MCP tool error, or any other failure), THEN THE Session_Capture_Hook SHALL log a short warning message and continue. The vault write is not affected by an Ami_Bridge failure.
5. THE Ami_Bridge write and the vault write SHALL be independent operations. A failure in one SHALL NOT prevent or roll back the other.

### Requirement 6: Independence of Write Destinations

**User Story:** As Mike, I want the vault write and the Ami bridge write to be fully independent, so that a failure in one channel does not block the other.

#### Acceptance Criteria

1. THE Session_Capture_Hook SHALL attempt the vault write and the Ami_Bridge write as two independent operations with separate error handling.
2. IF the vault write succeeds and the Ami_Bridge write fails, THEN THE Session_Capture_Hook SHALL report the vault write as successful and note the Ami_Bridge failure as a non-blocking warning.
3. IF the vault write fails and the Ami_Bridge write succeeds, THEN THE Session_Capture_Hook SHALL report the vault failure as a non-blocking warning and confirm the Ami_Bridge write as successful. No code block is needed because the summary reached S3.
4. IF both writes fail, THEN THE Session_Capture_Hook SHALL display the Session_Summary in a markdown code block so no captured knowledge is lost.

### Requirement 7: Article Candidate Topic Quality

**User Story:** As Mike, I want article candidate topics to be genuinely grounded in the session work, so that the content bullpen contains real ideas rather than generic suggestions.

#### Acceptance Criteria

1. THE Session_Capture_Hook SHALL derive each Article_Candidate_Topic from specific artifacts, decisions, or learnings that occurred during the session.
2. THE Session_Capture_Hook SHALL not generate generic topics such as "Getting Started with AWS" or "Introduction to AI" that are not tied to specific session work.
3. WHEN generating Article_Candidate_Topics, THE Session_Capture_Hook SHALL frame each topic as a concrete article angle (for example: "How kiro-recall uses postTaskExecution hooks to automate knowledge capture") rather than a broad category (for example: "Kiro hooks").
4. THE Session_Capture_Hook SHALL generate between 1 and 3 Article_Candidate_Topics per session. Zero topics is not permitted when the session contains meaningful work.

### Requirement 8: Error Handling and Tone

**User Story:** As Mike, I want the hook to handle failures gracefully with warm, conversational messages, so that errors feel like a helpful teammate reporting in rather than a crash log.

#### Acceptance Criteria

1. THE Session_Capture_Hook SHALL not surface stack traces, exception class names, or absolute file system paths in any failure scenario.
2. WHEN the MCP_Vault server is unavailable at hook start, THE Session_Capture_Hook SHALL output a short, warm message and continue to attempt the Ami_Bridge write.
3. WHEN any write fails, THE Session_Capture_Hook SHALL preserve the full Session_Summary content in chat output so no knowledge is lost.
4. THE Session_Capture_Hook SHALL not block or interfere with session completion. The hook fires after the session work is done and all failures are informational.
5. THE Session_Capture_Hook SHALL follow the same error handling tone as the existing kiro-recall hooks: warm, conversational, no jargon, no internal details.

### Requirement 9: Consistency with Existing Hooks

**User Story:** As a kiro-recall developer, I want the session capture hook to follow the same conventions as the existing five hooks, so that the hook ecosystem remains coherent and maintainable.

#### Acceptance Criteria

1. THE Session_Capture_Hook SHALL use the same JSON hook structure as the existing kiro-recall hooks: `name`, `version`, `description`, `when` (with `type`), and `then` (with `type: askAgent` and `prompt`).
2. THE Session_Capture_Hook prompt SHALL use `## Step N` sections with clear success and failure paths at each step, matching the prompt format of the auto-vault-sync and capture hooks.
3. THE Session_Capture_Hook SHALL check MCP_Vault availability as a preamble step before attempting vault operations, matching the pattern established by the auto-vault-sync hook.
4. THE Session_Capture_Hook SHALL use the same project name resolution logic (primary signal, secondary signal, fallback) as the session-start and auto-vault-sync hooks.

### Requirement 10: Parseable Output Format

**User Story:** As a developer of MCE and the content pipeline, I want the session summary format to be machine-parseable, so that downstream tools can extract fields programmatically without fragile text scraping.

#### Acceptance Criteria

1. THE Session_Summary SHALL use consistent `##` second-level markdown headings for all fields, with no variation in heading text across sessions.
2. THE Session_Summary metadata header SHALL use a consistent format: `## Date`, `## Project`, `## Session-type` headings followed by their values on the next line.
3. THE four content fields SHALL always appear in the same order: "What was built", "What was decided", "What was learned", "Article candidate topics".
4. THE "Article candidate topics" field SHALL use a markdown bulleted list (lines starting with `- `) so individual topics can be extracted by splitting on list markers.
