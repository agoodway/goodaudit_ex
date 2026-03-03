## 1. Endpoint and Schema Surface

- [ ] 1.1 Add OpenAPI schemas for bulk and webhook ingestion requests/responses
- [ ] 1.2 Add router/controller actions for bulk ingest and webhook ingest
- [ ] 1.3 Add consistent error envelope handling across ingestion endpoints

## 2. Idempotency and Replay Safety

- [ ] 2.1 Implement account-scoped idempotency storage and lookup flow
- [ ] 2.2 Integrate idempotency logic into single and bulk write paths
- [ ] 2.3 Implement webhook signature validation and replay protection

## 3. Quotas, Telemetry, and Tests

- [ ] 3.1 Add per-account rate-limit and backpressure enforcement
- [ ] 3.2 Emit ingestion-mode metrics and traces for success/failure paths
- [ ] 3.3 Add tests for partial bulk success, duplicate retries, and webhook replay rejection
