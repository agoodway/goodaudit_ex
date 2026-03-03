## 1. Data Model

- [ ] 1.1 Create versioned account HMAC key table with account FK and version uniqueness
- [ ] 1.2 Add `key_version` (not null) to `audit_logs`
- [ ] 1.3 Add `key_version` (not null) to `audit_checkpoints`
- [ ] 1.4 Backfill existing data to version `1` and enforce constraints

## 2. Accounts Context

- [ ] 2.1 Add APIs to create/activate/retire keys per account
- [ ] 2.2 Enforce single active key invariant per account
- [ ] 2.3 Add `get_hmac_key(account_id, version)` and active-key resolver

## 3. Audit Context + Verifier

- [ ] 3.1 Stamp active `key_version` on new log entries
- [ ] 3.2 Stamp checkpoint `key_version` on creation
- [ ] 3.3 Verify entries/checkpoints using recorded `key_version`
- [ ] 3.4 Implement dual-verify fallback only for configured cutover windows

## 4. APIs and Runbook

- [ ] 4.1 Add rotation endpoints (admin/internal scope) with reason + actor metadata
- [ ] 4.2 Add rotation runbook doc with pre-checks, cutover, rollback, and post-checks

## 5. Tests

- [ ] 5.1 Historical entries verify after rotation
- [ ] 5.2 New writes use new active key/version post-activation
- [ ] 5.3 Dual-verify window behavior is bounded and deterministic
- [ ] 5.4 Rollback restores previous active key safely
