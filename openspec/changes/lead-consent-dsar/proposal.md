## Why

Non-HIPAA lead systems still carry significant privacy and communications obligations (for example TCPA, DNC, and state privacy laws). The current proposals include retention and archive controls but do not define first-class consent provenance, revocation, suppression, or DSAR workflows.

## What Changes

1. **Consent evidence model** - Add immutable consent provenance fields (capture source, timestamp, policy text/version hash, jurisdiction).
2. **Revocation and suppression events** - Define explicit audit events and status models for opt-out, DNC/suppression list checks, and enforcement outcomes.
3. **DSAR workflow contract** - Define access, deletion/anonymization, and objection processing flows with approval and SLA metadata.
4. **Append-only compatible privacy handling** - Specify how records are tombstoned or anonymized while preserving chain integrity evidence.
5. **Regulatory reporting support** - Add query/report requirements for consent lineage and DSAR completion proofs.

## Capabilities

### New Capabilities
- `consent-provenance`: Immutable capture and verification of consent evidence
- `suppression-governance`: Audit-visible revocation and suppression enforcement lifecycle
- `dsar-workflows`: Account-scoped data subject request lifecycle and evidence trail

### Modified Capabilities
- `retention-archive-policy`: Integrate DSAR and suppression constraints into lifecycle operations
- `entry-querying`: Add privacy/compliance-oriented filters and retrieval patterns

## Impact

- **Modified files**: audit schemas, querying logic, archival/rehydration tooling
- **New files**: DSAR policy docs, admin workflow modules, compliance response schemas
- **New tests**: anonymization integrity, suppression enforcement, DSAR SLA and audit evidence correctness
