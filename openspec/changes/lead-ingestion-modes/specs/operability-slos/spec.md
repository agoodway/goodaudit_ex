## ADDED Requirements

### Requirement: Ingestion mode telemetry

The system MUST emit ingestion telemetry segmented by mode (`single`, `bulk`, `webhook`) including request volume, failure count, and latency distributions.

#### Scenario: Bulk ingest metrics emitted
- **WHEN** bulk ingest requests are processed
- **THEN** counters and latency histograms are emitted with `ingestion_mode=bulk`

### Requirement: Quota and backpressure signals

Rate-limit and backpressure responses MUST emit explicit telemetry signals and alertable counters.

#### Scenario: Account over quota
- **WHEN** an account exceeds ingestion quota
- **THEN** requests are rejected with HTTP 429 and a quota-exceeded metric increments
