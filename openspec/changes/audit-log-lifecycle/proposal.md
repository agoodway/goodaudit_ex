## Why

`audit_logs` will grow unbounded in production. Without partitioning, retention, and archive/re-hydration policies, query performance, storage cost, and maintenance burden will degrade over time.

## What Changes

1. **Partitioning strategy** - Partition `audit_logs` by time, with account-aware index patterns per partition.
2. **Retention policy** - Define online retention windows and archival cutover cadence.
3. **Archive + re-hydration** - Provide immutable archive export format and controlled temporary restore process.
4. **Lifecycle tooling** - Add maintenance jobs for partition creation, aging, and retirement.

## Capabilities

### New Capabilities
- `partitioned-audit-storage`: Partitioned audit log storage and index management
- `retention-archive-policy`: Retention, archival, and controlled re-hydration workflows

### Modified Capabilities
- `entry-querying`: Query planner and cursor behavior remain correct across partitions
- `verification-engine`: Full/incremental scans operate across partition boundaries

## Impact

- **New migrations**: partitioned table migration(s), partition index templates
- **Modified files**: query modules touching `audit_logs`
- **New files**: retention/archival jobs, re-hydration admin tooling
- **New tests**: cross-partition query correctness, retention safety, archive integrity
