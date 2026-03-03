## Context

`audit-schemas` intentionally shipped unpartitioned tables for MVP simplicity. This change introduces long-term lifecycle management for production scale.

## Goals / Non-Goals

**Goals:**
- Keep per-account query latency predictable as data grows
- Control storage cost with explicit retention and archive policies
- Preserve immutability and chain integrity across archive/restore operations

**Non-Goals:**
- Deleting audit data silently or ad hoc
- Changing API contracts for existing consumers

## Decisions

### Time-first partitioning
Use time-based partitions (for operational simplicity) while keeping account-prefixed indexes for tenant-scoped queries.

### Archive format
Archive records as immutable, checksummed bundles with metadata needed for audit-grade provenance.

### Controlled re-hydration
Re-hydration is temporary, explicit, and fully audited with approval metadata.

## Risks / Trade-offs

- More operational complexity (partition management jobs)
- Query plans must be monitored to avoid partition pruning regressions
