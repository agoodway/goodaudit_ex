## 1. Context Module

- [ ] 1.1 Create `lib/app/audit.ex` with `GA.Audit` module
- [ ] 1.2 Implement `create_log_entry(account_id, attrs)` — transaction with per-account advisory lock (`:erlang.phash2(account_id)`), fetch account's HMAC key via `GA.Accounts.get_hmac_key(account_id)`, per-account sequence computation, previous checksum fetch within account, HMAC computation via `Chain.compute_checksum(hmac_key, attrs, previous_checksum)`, chain field + account_id injection via `put_change`, insert
- [ ] 1.3 Implement `apply_chain_fields/3` helper — puts account_id, sequence_number, checksum, previous_checksum onto changeset
- [ ] 1.4 Implement `get_previous_checksum/2` — takes account_id, returns nil for genesis (seq 1 for this account), fetches previous entry's checksum within account otherwise
- [ ] 1.5 Implement default timestamp — set to `DateTime.utc_now()` when not provided in attrs

## 2. Querying

- [ ] 2.1 Implement `list_logs(account_id, opts)` — always filters by account_id, cursor-based pagination with `after_sequence`, limit clamping (default 50, max 1000), fetch limit+1 pattern
- [ ] 2.2 Implement `apply_filters/2` with `maybe_filter/3` pattern for all filter fields — base query always includes `WHERE account_id = ?`
- [ ] 2.3 Implement individual filters: `after_sequence`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `phi_accessed`, `from`, `to`
- [ ] 2.4 Implement `get_log(account_id, id)` — returns `{:ok, log}` or `{:error, :not_found}`, queries with both account_id and id to enforce tenant isolation

## 3. Checkpoint Management

- [ ] 3.1 Implement `create_checkpoint(account_id)` — reads latest log entry for the account, creates checkpoint with account_id, returns `{:ok, checkpoint}` or `{:error, :no_entries}`
- [ ] 3.2 Implement `list_checkpoints(account_id)` — checkpoints for the account ordered by sequence_number desc

## 4. Integration Tests

- [ ] 4.1 Test genesis entry creation — sequence 1, nil previous_checksum, valid checksum, correct account_id
- [ ] 4.2 Test chained entry — correct sequence, previous_checksum matches prior entry within same account
- [ ] 4.3 Test validation failure — missing fields return `{:error, changeset}`
- [ ] 4.4 Test concurrent writers within same account — 20 parallel tasks produce gap-free sequences 1..20
- [ ] 4.5 Test concurrent writers across accounts — parallel writes to different accounts don't block each other
- [ ] 4.6 Test account isolation — entries from account A are not visible when querying account B
- [ ] 4.7 Test cursor pagination — multi-page traversal with limit within an account
- [ ] 4.8 Test filters — user_id, action, date range, combined filters, all scoped to account
- [ ] 4.9 Test get_log — found within account, not found, and cross-account access denied
- [ ] 4.10 Test checkpoint creation — correct sequence/checksum from account's chain head
- [ ] 4.11 Test checkpoint on empty account — returns `{:error, :no_entries}`
- [ ] 4.12 Test checkpoint isolation — checkpoint for account A not returned when listing account B's checkpoints
