## 1. Partitioning

- [ ] 1.1 Create partitioned `audit_logs` strategy and migration plan
- [ ] 1.2 Add partition creation/rollover automation
- [ ] 1.3 Define index templates per partition for account-scoped access patterns

## 2. Retention and Archive

- [ ] 2.1 Implement retention policy configuration and enforcement jobs
- [ ] 2.2 Implement immutable archive export bundles with checksums/manifests
- [ ] 2.3 Implement controlled re-hydration flow with expiry and cleanup

## 3. Query + Verification Compatibility

- [ ] 3.1 Validate list/query APIs across partition boundaries
- [ ] 3.2 Validate verification paths across online + restored data windows

## 4. Tests

- [ ] 4.1 Cross-partition pagination and filtering correctness
- [ ] 4.2 Retention cutoff safety and non-destructive archive behavior
- [ ] 4.3 Re-hydration workflow audit logging and cleanup
