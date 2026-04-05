# Requirements Document

## Introduction

Vault-s3-sync is the bridge mechanism that takes session capture files from the local Obsidian vault inbox (`00-inbox/`) and syncs them to Ami's S3 second brain bucket (`ami-second-brain-724772056609` in ap-southeast-2) under the `session-captures/` prefix. Without this bridge, the content-publish-pipeline (MCE) on Ami's EC2 instance generates content blind, with no session context from Mike's Kiro work sessions.

The v2.0.0 simplification of kiro-recall removed the Discord/Ami Bridge from the session capture hooks. The hooks now write vault-only. This sync mechanism is the replacement path for getting captures to S3. The existing hooks already reference this bridge in their Step 6 output: "The session-capture-bridge (when running) handles syncing vault captures to Ami's S3 bucket."

The bridge runs on Mike's local Windows machine (Palmerston North). The target S3 bucket is in ap-southeast-2 (Sydney). Mike's machine does not currently have AWS CLI configured for this bucket. The bridge needs to solve the credential and transport problem as part of its design.

The consumer is the content-publish-pipeline's Vault Context Assembler component on Ami's EC2 instance, which reads from `session-captures/*.md` in the S3 bucket, sorts by date (newest first), and caps at the 10 most recent captures for context assembly.

## Glossary

- **Vault_S3_Sync**: The bridge mechanism that syncs session capture files from the local vault inbox to Ami's S3 second brain bucket.
- **Session_Capture_File**: A structured markdown file written to `00-inbox/` by the kiro-recall session capture hooks, following the naming pattern `YYYY-MM-DD-{project}-session-capture.md`.
- **Vault_Inbox**: The `00-inbox/` folder in the local Obsidian vault at `C:\Users\Mike RT\Documents\second-brain`, where session capture hooks write their output.
- **Second_Brain_Bucket**: The S3 bucket `ami-second-brain-724772056609` in ap-southeast-2, where Ami stores notes and context.
- **Session_Captures_Prefix**: The S3 key prefix `session-captures/` inside the Second_Brain_Bucket, where synced session capture files are stored.
- **Content_Publish_Pipeline**: The MCE orchestration layer on Ami's EC2 that reads session captures from S3 as source material for content generation.
- **Vault_Context_Assembler**: The component within the Content_Publish_Pipeline that reads session captures from S3, sorts by date, and assembles context for MCE runs.
- **Sync_Run**: A single execution of the Vault_S3_Sync that scans the Vault_Inbox for session capture files and uploads any new or updated files to the Session_Captures_Prefix.

## Requirements

### Requirement 1: Session Capture File Detection

**User Story:** As Mike, I want the sync to identify which files in my vault inbox are session captures, so that only session capture files are synced to S3 and other inbox notes are left alone.

#### Acceptance Criteria

1. WHEN a Sync_Run executes, THE Vault_S3_Sync SHALL scan the Vault_Inbox for files matching the naming pattern `YYYY-MM-DD-{project}-session-capture.md`.
2. THE Vault_S3_Sync SHALL identify session capture files by filename pattern only, without parsing file content.
3. THE Vault_S3_Sync SHALL ignore all files in the Vault_Inbox that do not match the session capture naming pattern.

### Requirement 2: S3 Upload

**User Story:** As Mike, I want session capture files uploaded to the correct S3 prefix, so that the content-publish-pipeline can find them where it expects.

#### Acceptance Criteria

1. WHEN a Session_Capture_File is identified for sync, THE Vault_S3_Sync SHALL upload the file to the Second_Brain_Bucket under the Session_Captures_Prefix with the same filename as the local file.
2. THE Vault_S3_Sync SHALL upload files to the S3 key `session-captures/{filename}` where `{filename}` is the local vault filename unchanged.
3. WHEN a file with the same S3 key already exists in the Session_Captures_Prefix, THE Vault_S3_Sync SHALL overwrite the existing file with the new content.

### Requirement 3: Change Detection

**User Story:** As Mike, I want the sync to only upload files that are new or changed since the last sync, so that it runs efficiently and does not re-upload unchanged files every time.

#### Acceptance Criteria

1. WHEN a Sync_Run executes, THE Vault_S3_Sync SHALL compare local session capture files against what has already been synced.
2. THE Vault_S3_Sync SHALL upload a file only when the file is new (not previously synced) or the file content has changed since the last sync.
3. THE Vault_S3_Sync SHALL skip upload for files that have not changed since the last successful sync.
4. THE Vault_S3_Sync SHALL use a local sync state file to track which files have been synced and their content hashes at the time of last sync.

### Requirement 4: Sync Trigger Mechanism

**User Story:** As Mike, I want to control when the sync runs, so that I can trigger it when I know captures are ready without needing an always-on background process.

#### Acceptance Criteria

1. THE Vault_S3_Sync SHALL be invocable as a manual command that Mike can run from a terminal.
2. THE Vault_S3_Sync SHALL complete a Sync_Run and exit, rather than running as a persistent background process or watcher.
3. WHEN invoked, THE Vault_S3_Sync SHALL report the number of files synced and any errors encountered.

### Requirement 5: AWS Credential Management

**User Story:** As Mike, I want the sync to authenticate with AWS without requiring a full AWS CLI installation or permanent credentials on my local machine, so that the setup is lightweight and credentials are scoped to this specific use case.

#### Acceptance Criteria

1. THE Vault_S3_Sync SHALL authenticate to the Second_Brain_Bucket using AWS credentials configured for the ap-southeast-2 region.
2. THE Vault_S3_Sync SHALL support reading credentials from a local configuration file specific to the sync tool, separate from any system-wide AWS CLI configuration.
3. THE Vault_S3_Sync SHALL support reading credentials from environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`) as an alternative to the configuration file.
4. IF no valid credentials are found, THEN THE Vault_S3_Sync SHALL report a clear error message explaining what credentials are needed and where to configure them.

### Requirement 6: Sync State Persistence

**User Story:** As Mike, I want the sync to remember what it has already uploaded, so that repeated runs are fast and do not re-upload everything.

#### Acceptance Criteria

1. THE Vault_S3_Sync SHALL maintain a sync state file on the local filesystem that records the filename and content hash of each successfully synced file.
2. WHEN a file is successfully uploaded to S3, THE Vault_S3_Sync SHALL update the sync state file with the filename and current content hash.
3. IF the sync state file does not exist (first run), THEN THE Vault_S3_Sync SHALL treat all matching session capture files as new and upload them all.
4. IF the sync state file is corrupted or unreadable, THEN THE Vault_S3_Sync SHALL log a warning, treat all files as new, and recreate the sync state file after the sync completes.

### Requirement 7: Error Handling

**User Story:** As Mike, I want the sync to handle failures gracefully and tell me what went wrong in plain language, so that I can fix issues without digging through stack traces.

#### Acceptance Criteria

1. IF an individual file upload fails, THEN THE Vault_S3_Sync SHALL continue uploading remaining files and report the failure at the end of the Sync_Run.
2. IF the Vault_Inbox path does not exist or is not readable, THEN THE Vault_S3_Sync SHALL report a clear error message and exit.
3. IF the S3 upload fails due to authentication errors, THEN THE Vault_S3_Sync SHALL report a clear message about credential configuration and exit.
4. THE Vault_S3_Sync SHALL not surface raw stack traces or exception class names in its output. Error messages SHALL be short and actionable.
5. WHEN a Sync_Run completes, THE Vault_S3_Sync SHALL report a summary: files found, files uploaded, files skipped (unchanged), and files failed.

### Requirement 8: Filename and Key Mapping

**User Story:** As a developer of the content-publish-pipeline, I want the S3 keys to match the local vault filenames exactly, so that the Vault_Context_Assembler can parse dates and project names from the key without transformation.

#### Acceptance Criteria

1. THE Vault_S3_Sync SHALL preserve the local filename exactly as the S3 object key under the Session_Captures_Prefix.
2. THE S3 key for a synced file SHALL follow the format `session-captures/YYYY-MM-DD-{project}-session-capture.md`.
3. THE Vault_S3_Sync SHALL not rename, transform, or add prefixes to the filename during upload.

### Requirement 9: Content Integrity

**User Story:** As Mike, I want the synced files in S3 to be byte-for-byte identical to the local vault files, so that the content-publish-pipeline reads exactly what the hooks wrote.

#### Acceptance Criteria

1. THE Vault_S3_Sync SHALL upload the file content as-is, without modifying, transforming, or re-encoding the markdown content.
2. THE Vault_S3_Sync SHALL set the S3 object content type to `text/markdown` for uploaded files.
3. WHEN a file is overwritten in S3, THE Vault_S3_Sync SHALL replace the entire object with the current local file content.

### Requirement 10: Implementation Constraints

**User Story:** As a kiro-recall developer, I want the sync tool to be a simple, standalone script that fits the kiro-recall project structure, so that it does not introduce heavy dependencies or complex build tooling.

#### Acceptance Criteria

1. THE Vault_S3_Sync SHALL be implemented as a standalone script that can run on Windows without requiring a complex build or install process.
2. THE Vault_S3_Sync SHALL have minimal external dependencies, limited to what is needed for S3 access and file hashing.
3. THE Vault_S3_Sync SHALL store its configuration (vault path, S3 bucket, S3 prefix, region) in a configuration file rather than hardcoding values.
4. THE Vault_S3_Sync SHALL include a configuration template or example file so Mike can set up the tool without guessing the required fields.

