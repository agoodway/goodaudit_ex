## Context

This is the first module in GoodAudit's tamper-evident audit logging system. It provides the cryptographic primitive — HMAC-SHA-256 chain computation — that all other components depend on. No database or web layer exists yet.

## Goals / Non-Goals

**Goals:**
- Deterministic, testable HMAC computation with zero side effects (no config reads, no DB)
- Canonical payload format that is unambiguous and easy to reconstruct from any language
- Constant-time comparison for verification (timing attack prevention)
- Key passed as parameter — the module is a pure function of its inputs

**Non-Goals:**
- Key storage, generation, or rotation (separate change: `account-hmac-keys`)
- Database interaction (this module is pure computation)
- Any awareness of Ecto schemas (accepts plain maps, returns strings)

## Decisions

### Key as explicit parameter, not config
The module accepts the HMAC key as the first argument to `compute_checksum/3` and `verify_checksum/3`. This makes it a true pure function — same inputs always produce same outputs, no hidden state. It also makes per-account keys trivial: the caller passes the right key for the account. Testing is simpler too — no config mocking needed.

### `account_id` as first field in payload
Even though keys are per-account, `account_id` is still included in the canonical payload. This provides defense-in-depth: even if the same key were accidentally used for two accounts, entries would produce different checksums. It also makes the payload self-describing for debugging.

### Pipe-delimited canonical format over JSON
A pipe-delimited string with fixed field ordering is simpler to implement, debug, and reproduce across languages than serializing the entire entry as JSON. Only the metadata field uses JSON (because it's variable-structure).

### `Plug.Crypto.secure_compare` for verification
Erlang's `:crypto` doesn't expose a constant-time comparison. `Plug.Crypto.secure_compare/2` is already available (Plug is a Phoenix dependency) and prevents timing side-channels.

### `Jason.OrderedObject` for canonical metadata
Jason's `OrderedObject` preserves insertion order during encoding. By sorting keys recursively before wrapping in `OrderedObject`, we guarantee deterministic JSON output regardless of Elixir map iteration order.

## Risks / Trade-offs

### `:crypto.mac` vs `:crypto.hmac`
`:crypto.hmac` was removed in OTP 24+. Using `:crypto.mac(:hmac, :sha256, key, data)` which is the current API. No risk as long as we're on OTP 24+.
