## 1. Verification Engine

- [ ] 1.1 Create `lib/app/audit/verifier.ex` with `GA.Audit.Verifier` module
- [ ] 1.2 Implement `verify(account_id)` — fetches account's HMAC key via `GA.Accounts.get_hmac_key(account_id)`, loads checkpoints for the account into a map, calls `stream_and_verify/3` scoped to account with key, measures duration
- [ ] 1.3 Implement `do_verify_batches/4` — recursive batch loading (1000 entries per batch via `WHERE account_id = ? AND sequence_number > ? ORDER BY sequence_number ASC LIMIT 1000`), reduces over `verify_entry/3`
- [ ] 1.4 Implement `verify_entry/4` — checks sequence continuity within account, recomputes checksum via `Chain.verify_checksum(hmac_key, entry, previous_checksum)`, checks checkpoint anchors, updates accumulator state
- [ ] 1.5 Add `verify_chain(account_id)` to `GA.Audit` context — delegates to `Verifier.verify(account_id)`

## 2. Checkpoint Worker

- [ ] 2.1 Create `lib/app/audit/checkpoint_worker.ex` with `GA.Audit.CheckpointWorker` GenServer
- [ ] 2.2 Implement `init/1` — reads interval from opts (default 1 hour), schedules first checkpoint run
- [ ] 2.3 Implement `handle_info(:create_checkpoints, state)` — iterates all active accounts via `GA.Repo.all(from a in GA.Accounts.Account, where: a.status == :active)`, calls `GA.Audit.create_checkpoint/1` for each, logs results per account, reschedules
- [ ] 2.4 Add `GA.Audit.CheckpointWorker` to `GA.Application` children list before `GAWeb.Endpoint`

## 3. Tests

- [ ] 3.1 Test valid chain verification for an account — all entries pass, report shows `valid: true`
- [ ] 3.2 Test tampered checksum detection — manually inserted entry with wrong checksum produces `valid: false` with `first_failure` details
- [ ] 3.3 Test sequence gap detection — entries with non-contiguous sequence numbers within an account produce `sequence_gaps` in report
- [ ] 3.4 Test checkpoint validation — valid and invalid checkpoint anchors for the account reflected in `checkpoint_results`
- [ ] 3.5 Test duration tracking — `duration_ms` is a non-negative integer
- [ ] 3.6 Test verification is account-scoped — verifying account A does not check entries from account B
- [ ] 3.7 Test CheckpointWorker creates checkpoints for all active accounts — verify multiple accounts get checkpoints on timer
- [ ] 3.8 Test CheckpointWorker skips suspended accounts
- [ ] 3.9 Test CheckpointWorker handles account with no entries gracefully (logs, continues to next)
