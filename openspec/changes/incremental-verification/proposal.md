## Why

Full-chain verification from genesis is correct but becomes expensive as chains grow. Production verification should default to incremental checks from the latest trusted checkpoint, while still preserving a periodic full-scan compliance path.

## What Changes

1. **Default incremental mode** - `verify_chain` starts from latest trusted checkpoint when available.
2. **Checkpoint trust model** - Define trusted checkpoint criteria (valid chain match + optional valid external anchor).
3. **Background full scan** - Add scheduled full verification job for compliance and drift detection.
4. **Mode-aware reporting** - Verification report includes mode (`incremental` or `full`) and start boundary.

## Capabilities

### New Capabilities
- `incremental-verification`: Default bounded verification from trusted checkpoint to head
- `compliance-full-scan`: Scheduled full-chain verification and drift reporting

### Modified Capabilities
- `verification-engine`: Adds verification modes and trust-boundary selection

## Impact

- **Modified files**: `lib/app/audit/verifier.ex`, `lib/app/audit.ex`
- **New files**: full-scan worker/job module, reporting hooks
- **New tests**: incremental boundary correctness, parity with full mode, trust fallback behavior
