## 1. Governance Policy

- [ ] 1.1 Define break-glass policy with roles, approvals, and expiry constraints
- [ ] 1.2 Define signed intent schema and storage

## 2. Controlled Repair Workflow

- [ ] 2.1 Add guarded admin workflow for temporary bypass activation
- [ ] 2.2 Ensure bypass scope is minimal and time-bounded
- [ ] 2.3 Emit immutable repair-start/repair-end events

## 3. Post-repair Controls

- [ ] 3.1 Require verification run and report attachment before closure
- [ ] 3.2 Require after-action summary metadata (cause, impact, remediation)

## 4. Tests

- [ ] 4.1 Reject bypass without signed intent + approval
- [ ] 4.2 Enforce expiry and scope boundaries
- [ ] 4.3 Enforce mandatory post-repair verification
