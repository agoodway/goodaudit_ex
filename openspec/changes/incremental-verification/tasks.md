## 1. Verification Engine

- [ ] 1.1 Add mode support (`:incremental`, `:full`) to verifier
- [ ] 1.2 Implement trusted checkpoint boundary selection
- [ ] 1.3 Implement fallback to full mode when no trusted checkpoint exists
- [ ] 1.4 Include mode and start sequence in report payload

## 2. Background Compliance Scan

- [ ] 2.1 Add scheduled full-scan worker/job
- [ ] 2.2 Emit discrepancy events and metrics from full scans

## 3. Tests

- [ ] 3.1 Incremental result parity with full scan for intact chain
- [ ] 3.2 Boundary correctness when latest checkpoint is invalid
- [ ] 3.3 Fallback behavior when no checkpoint exists
