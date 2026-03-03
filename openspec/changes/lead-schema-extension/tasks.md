## 1. Schema and Migration

- [ ] 1.1 Add `audit_logs` columns for actor model, lead dimensions, and `schema_version`
- [ ] 1.2 Add account-prefixed indexes for primary lead dimensions
- [ ] 1.3 Update `GA.Audit.Log` schema and changeset for compatibility rules

## 2. Entry Creation and Chain Integrity

- [ ] 2.1 Update `GA.Audit.create_log_entry/2` to validate/stamp actor and schema version fields
- [ ] 2.2 Extend canonical checksum payload to include new deterministic fields
- [ ] 2.3 Add verifier parity tests covering new canonical payload fields

## 3. API and Validation

- [ ] 3.1 Update request/response schemas for new fields
- [ ] 3.2 Add validation errors for unsupported schema versions
- [ ] 3.3 Add integration tests for legacy producer compatibility and system actor writes
