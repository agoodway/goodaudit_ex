## Why

Per-account HMAC keys are currently single-version and non-rotatable. In production, keys eventually need rotation for incident response, crypto hygiene, and compliance controls. Without key versioning, rotation risks breaking historical verification or requiring unsafe bulk rewrites.

## What Changes

1. **Key versioning model** - Add versioned account key records and mark one active signing key per account.
2. **Log/checkpoint key version** - Persist `key_version` on `audit_logs` and `audit_checkpoints` so verification can resolve historical keys correctly.
3. **Dual-verify window** - Verification supports active + previous key versions during rotation cutovers.
4. **Rotation API** - Add controlled key rotation operations in `GA.Accounts` and admin API endpoints.
5. **Runbook + auditability** - Rotation workflow requires actor/reason metadata and produces explicit audit events.

## Capabilities

### New Capabilities
- `key-versioning`: Versioned per-account HMAC key lifecycle with active-key selection
- `key-rotation-api`: Controlled key rotation endpoints and runbook-backed execution

### Modified Capabilities
- `entry-creation`: Uses active key version and stamps `key_version` on new audit logs
- `checkpoint-management`: Stamps checkpoint `key_version` from chain head context
- `verification-engine`: Resolves keys by version and supports dual-verify window

## Impact

- **New migration(s)**: `CreateAccountHmacKeys`, `AddKeyVersionToAuditLogs`, `AddKeyVersionToAuditCheckpoints`
- **Modified files**: `lib/app/accounts.ex`, `lib/app/accounts/account.ex`, `lib/app/audit.ex`, `lib/app/audit/verifier.ex`
- **New files**: `lib/app/accounts/hmac_key.ex`, rotation policy module(s), optional admin controller/schema files
- **New tests**: key versioning, rotation cutover, dual verification, rollback safety
