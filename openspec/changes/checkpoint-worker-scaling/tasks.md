## 1. Scheduling and Overlap Control

- [ ] 1.1 Implement run lease/lock guard
- [ ] 1.2 Add configurable jitter to schedule
- [ ] 1.3 Ensure lease cleanup on crash/timeout

## 2. Fan-out Scaling

- [ ] 2.1 Add chunked account iteration
- [ ] 2.2 Add bounded concurrency for checkpoint creation
- [ ] 2.3 Add run-level timeout and per-account timeout guards

## 3. Backoff

- [ ] 3.1 Add per-account failure counters/backoff windows
- [ ] 3.2 Reset backoff on successful checkpoint creation

## 4. Tests

- [ ] 4.1 Verify no overlap under concurrent scheduler triggers
- [ ] 4.2 Verify max concurrency cap is respected
- [ ] 4.3 Verify failing account does not block healthy accounts
