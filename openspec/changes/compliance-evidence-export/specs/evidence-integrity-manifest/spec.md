## ADDED Requirements

### Requirement: Integrity manifest structure

Every compliance export MUST include an integrity manifest as a map/object with the following fields: `chain_verification` (the verification result for the chain segment within the exported date range), `checkpoint_anchors` (list of checkpoint anchor summaries that fall within the exported range), `export_checksum` (SHA-256 hex digest of the export content excluding the manifest itself), `generated_at` (ISO 8601 UTC timestamp of when the export was generated), and `generated_by` (string identifying the GoodAudit version, e.g., `"GoodAudit v1.x"`).

#### Scenario: Manifest contains all required fields
- **WHEN** an export is generated
- **THEN** the manifest includes `chain_verification`, `checkpoint_anchors`, `export_checksum`, `generated_at`, and `generated_by`

#### Scenario: Manifest generated_at matches export time
- **WHEN** an export is generated at `2025-06-15T10:30:00Z`
- **THEN** the manifest's `generated_at` is `"2025-06-15T10:30:00Z"`

### Requirement: Chain verification for exported range

The manifest's `chain_verification` field MUST contain the result of verifying the HMAC chain for entries within the exported date range for the given account. It MUST include `valid` (boolean), `total_entries` (integer count of entries in the range), `verified_entries` (integer count of entries whose checksums were verified), `first_failure` (failure details or `null`), and `sequence_gaps` (list of gap descriptions or empty list). The verification MUST use the existing `GA.Audit.Verifier` infrastructure scoped to the date range.

#### Scenario: Valid chain segment
- **WHEN** the chain is intact for the exported date range
- **THEN** `chain_verification.valid` is `true`, `verified_entries` equals `total_entries`, `first_failure` is `null`, and `sequence_gaps` is `[]`

#### Scenario: Chain segment with tampered entry
- **WHEN** an entry within the exported range has a mismatched checksum
- **THEN** `chain_verification.valid` is `false` and `first_failure` contains the sequence number and checksum mismatch details

#### Scenario: Chain segment with sequence gap
- **WHEN** entries within the exported range have a gap in sequence numbers
- **THEN** `chain_verification.valid` is `false` and `sequence_gaps` contains the gap details

### Requirement: Checkpoint anchor summaries

The manifest's `checkpoint_anchors` field MUST contain a list of checkpoint summaries for checkpoints whose `sequence_number` falls within the entry range of the export. Each summary MUST include `sequence_number`, `checksum`, `anchored` (boolean — true if `signature` is not null), `signature` (base64 string or null), `verified_at` (ISO 8601 or null), and `signing_key_id` (string or null). If external anchoring is not enabled, checkpoints without signatures are still listed with `anchored: false`.

#### Scenario: Checkpoint within exported range is anchored
- **WHEN** the exported range includes a checkpoint at sequence 500 with a valid signature
- **THEN** `checkpoint_anchors` includes `%{sequence_number: 500, checksum: "...", anchored: true, signature: "...", verified_at: "...", signing_key_id: "..."}`

#### Scenario: Checkpoint within exported range is not anchored
- **WHEN** the exported range includes a checkpoint at sequence 500 without a signature
- **THEN** `checkpoint_anchors` includes `%{sequence_number: 500, checksum: "...", anchored: false, signature: null, verified_at: null, signing_key_id: null}`

#### Scenario: No checkpoints in exported range
- **WHEN** no checkpoints fall within the exported date range
- **THEN** `checkpoint_anchors` is `[]`

### Requirement: Export checksum computation

`GA.Compliance.Manifest.compute_export_checksum(content)` MUST compute a SHA-256 hex digest of the export content. For JSON exports, the checksum is computed over the serialized `data` array only (not the manifest itself, to avoid circular dependency). For CSV exports, the checksum is computed over all data rows (header + data, excluding the manifest comment block). For PDF exports, the checksum is computed over the full PDF binary content.

#### Scenario: JSON export checksum
- **WHEN** a JSON export is generated with a data array
- **THEN** `export_checksum` is the SHA-256 hex digest of the JSON-serialized `data` array

#### Scenario: CSV export checksum
- **WHEN** a CSV export is generated
- **THEN** `export_checksum` is the SHA-256 hex digest of the header row plus all data rows (excluding manifest comment lines)

#### Scenario: Checksum is deterministic
- **WHEN** the same export data is checksummed twice
- **THEN** the same checksum is produced both times

### Requirement: Manifest generation orchestration

`GA.Compliance.Manifest.generate(account_id, entries, params)` MUST orchestrate manifest generation by: (1) running chain verification for the entries in the exported range, (2) loading checkpoint anchors for the account within the sequence number range of the exported entries, (3) computing the export checksum from the formatted content, (4) assembling and returning the complete manifest map.

#### Scenario: Full manifest generation
- **WHEN** `generate/3` is called with an account_id, list of exported entries, and export params
- **THEN** it returns a map with `chain_verification`, `checkpoint_anchors`, `export_checksum`, `generated_at`, and `generated_by`

#### Scenario: Manifest with no entries
- **WHEN** the export query matches zero entries
- **THEN** the manifest's `chain_verification` shows `total_entries: 0` and `checkpoint_anchors` is `[]`

### Requirement: Manifest serialization per format

The manifest MUST be serialized appropriately for each export format:
- **JSON**: included as a top-level `"manifest"` key in the output JSON object
- **CSV**: appended after the last data row as comment lines (each line prefixed with `#`), formatted as `# manifest.field: value` with nested fields using dot notation
- **PDF**: rendered as a dedicated footer section in the PDF document with labeled fields

#### Scenario: JSON manifest embedding
- **WHEN** a JSON export is generated
- **THEN** the output JSON has a `"manifest"` key containing the full manifest object

#### Scenario: CSV manifest embedding
- **WHEN** a CSV export is generated
- **THEN** the file ends with lines like `# manifest.chain_verification.valid: true`, `# manifest.export_checksum: abc123...`, etc.

#### Scenario: PDF manifest embedding
- **WHEN** a PDF export is generated
- **THEN** the PDF contains a section titled "Integrity Manifest" with the manifest fields displayed in a readable format

### Requirement: Manifest stored on async export record

When an async export completes, the integrity manifest MUST be stored in the `integrity_manifest` JSONB column of the `compliance_exports` table. This allows the manifest to be returned via `GET /api/v1/exports/:id` without re-reading the export file.

#### Scenario: Manifest persisted on completion
- **WHEN** an async export completes successfully
- **THEN** the `compliance_exports` record's `integrity_manifest` column contains the full manifest as a JSON object

#### Scenario: Manifest available via API
- **WHEN** `GET /api/v1/exports/:id` is called for a completed export
- **THEN** the response includes `"manifest"` with the stored integrity manifest
