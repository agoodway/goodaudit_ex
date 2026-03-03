## Why

The HMAC chain module and database schemas exist, but nothing wires them together. We need the Phoenix context module (`GA.Audit`) that orchestrates the core operations: creating chain-linked entries with gap-free sequence numbers, querying with pagination and filtering, and managing checkpoints — all **scoped to an account** for multi-tenant isolation.

## What Changes

A new context module `GA.Audit` that:
- Creates audit log entries atomically **within an account**: acquires a per-account advisory lock, fetches the account's HMAC key via `GA.Accounts.get_hmac_key/1`, assigns the next per-account sequence number, computes HMAC checksum using that key chained to the previous entry in that account's chain, inserts in a single transaction
- Lists entries with cursor-based pagination and filters, **always scoped to an account**
- Gets a single entry by ID (verifying account ownership)
- Creates checkpoints from the current chain head **for an account**
- Lists checkpoints **for an account**

All public functions accept an `account_id` parameter (or `%Account{}` struct) as the first argument, establishing the tenant boundary.

> **Multi-tenancy note:** The app already has `GA.Accounts.Account` with `account_users` and per-account API keys. This context integrates with that infrastructure — the `account_id` will come from `conn.assigns.current_account` at the controller layer (resolved from the API key by the existing `GAWeb.Plugs.ApiAuth`).

## Capabilities

### New Capabilities
- `entry-creation`: Atomic audit log entry creation with per-account gap-free sequencing and HMAC chaining
- `entry-querying`: Cursor-based pagination and multi-field filtering for audit log entries, scoped to an account
- `checkpoint-management`: Per-account checkpoint creation and listing from the current chain state

### Modified Capabilities

## Impact

- **New file**: `lib/app/audit.ex`
- **New tests**: `test/app/audit_test.exs`
- **Dependencies**: Uses `GA.Audit.Chain` (from hmac-chain), `GA.Audit.Log` and `GA.Audit.Checkpoint` (from audit-schemas), `GA.Accounts.Account` and `GA.Accounts.get_hmac_key/1` (from account-hmac-keys)
