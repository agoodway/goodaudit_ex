## 1. HMAC Chain Module

- [x] 1.1 Create `lib/app/audit/chain.ex` with `GA.Audit.Chain` module — `compute_checksum/3`, `verify_checksum/3`, `canonical_payload/2`
- [x] 1.2 Implement canonical payload builder — pipe-delimited, fixed field order starting with `account_id`, nil-to-empty-string, genesis previous_checksum handling
- [x] 1.3 Implement metadata canonicalization — recursive key sorting via `Jason.OrderedObject`, nil/empty → `"{}"`
- [x] 1.4 Implement `compute_checksum(key, attrs, previous_checksum)` — builds canonical payload, computes `:crypto.mac(:hmac, :sha256, key, payload)`, returns lowercase hex. Key is raw binary (caller decodes).
- [x] 1.5 Implement `verify_checksum(key, entry, previous_checksum)` — extracts attrs from log entry struct, recomputes checksum with provided key, compares with `Plug.Crypto.secure_compare/2`
- [x] 1.6 Implement `entry_to_attrs/1` helper — converts `GA.Audit.Log` struct to attrs map for checksum computation

## 2. Unit Tests

- [x] 2.1 Create `test/app/audit/chain_test.exs`
- [x] 2.2 Test deterministic output — same key + inputs produce same 64-char hex checksum
- [x] 2.3 Test field sensitivity — changing any single field produces a different checksum
- [x] 2.4 Test previous_checksum sensitivity — different previous checksums produce different results
- [x] 2.5 Test genesis handling — nil previous_checksum uses "genesis" literal
- [x] 2.6 Test nil field handling — optional nil fields produce empty strings in payload
- [x] 2.7 Test metadata key ordering independence — same keys in different order produce same checksum
- [x] 2.8 Test nested metadata sorting
- [x] 2.9 Test empty/nil metadata produces "{}"
- [x] 2.10 Test different keys produce different checksums for same payload
- [x] 2.11 Test different account_ids produce different checksums for same key and data
