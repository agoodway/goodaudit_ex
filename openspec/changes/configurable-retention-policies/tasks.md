## 1. Framework Retention Declarations

- [ ] 1.1 Define `retention_policy/0` callback in the compliance framework behaviour
- [ ] 1.2 Implement `retention_policy/0` for HIPAA — `%{minimum_days: 2190, maximum_days: nil, recommendation_days: 2190, description: "..."}`
- [ ] 1.3 Implement `retention_policy/0` for SOC 2 — `%{minimum_days: 365, maximum_days: nil, recommendation_days: 365, description: "..."}`
- [ ] 1.4 Implement `retention_policy/0` for PCI-DSS — `%{minimum_days: 365, maximum_days: nil, recommendation_days: 1095, description: "..."}`
- [ ] 1.5 Implement `retention_policy/0` for GDPR — `%{minimum_days: 0, maximum_days: nil, recommendation_days: 365, description: "..."}`
- [ ] 1.6 Implement `retention_policy/0` for ISO 27001 — `%{minimum_days: 1095, maximum_days: nil, recommendation_days: 1095, description: "..."}`
- [ ] 1.7 Add compile-time/load-time validation for retention policy structure (non-negative minimum, maximum >= minimum when set)

## 2. Account Retention Schema

- [ ] 2.1 Create migration adding `retention_effective_days` (integer), `retention_override_days` (integer, nullable), `retention_computed_at` (utc_datetime), and `retention_conflicts` (array of strings) to `accounts` table
- [ ] 2.2 Update `GA.Accounts.Account` schema to include retention fields
- [ ] 2.3 Set default `retention_effective_days` to 0 (recomputation will populate correct values when frameworks are activated)

## 3. Retention Computation Module

- [ ] 3.1 Create `lib/app/compliance/retention.ex` with `GA.Compliance.Retention` module
- [ ] 3.2 Implement `framework_policies(account_id)` — returns list of `{framework_name, retention_policy_map}` tuples for active frameworks on account
- [ ] 3.3 Implement `compute_effective(account_id)` — computes `effective_minimum` (max of minimums), `effective_maximum` (min of non-nil maximums or nil), `effective_recommendation` (max of recommendations), `contributing_frameworks`, and `conflicts`
- [ ] 3.4 Implement conflict detection — flag when `effective_minimum > effective_maximum` with human-readable description naming the conflicting frameworks
- [ ] 3.5 Implement `recompute_and_persist(account_id)` — calls `compute_effective/1`, updates account retention columns, sets `retention_computed_at` to current UTC time

## 4. Override Validation

- [ ] 4.1 Implement `set_retention_override(account_id, days)` — validate `days >= effective_minimum`, reject with error naming frameworks if below, warn if above `effective_maximum`, store in `retention_override_days`
- [ ] 4.2 Implement `clear_retention_override(account_id)` — set `retention_override_days` to nil, trigger recomputation
- [ ] 4.3 Implement `effective_retention_days(account)` helper — returns `retention_override_days` if set, otherwise `retention_effective_days`

## 5. Recomputation Triggers

- [ ] 5.1 Hook framework activation to trigger `recompute_and_persist/1` for the affected account
- [ ] 5.2 Hook framework deactivation to trigger `recompute_and_persist/1` for the affected account
- [ ] 5.3 Add `recompute_all_accounts/0` for bulk recomputation (used after framework module code updates)

## 6. GDPR Purpose Tracking

- [ ] 6.1 Create migration for `retention_purposes` table — `account_id`, `purpose` (string), `description` (string), `expires_at` (utc_datetime, nullable), timestamps
- [ ] 6.2 Create `GA.Compliance.RetentionPurpose` schema
- [ ] 6.3 Implement `add_purpose(account_id, purpose, description, expires_at)` and `remove_purpose(account_id, purpose)`
- [ ] 6.4 Implement `expired_purposes(account_id)` — returns purposes past their `expires_at`
- [ ] 6.5 Integrate purpose expiry with partition aging — entries tagged with only expired purposes and past all framework minimums become archival candidates

## 7. Lifecycle Integration

- [ ] 7.1 Update `audit-log-lifecycle` partition aging job to read `effective_retention_days(account)` instead of global constant
- [ ] 7.2 Ensure each account's partitions age independently based on its own retention
- [ ] 7.3 Handle accounts with `retention_effective_days` of 0 — trigger recomputation or use system default

## 8. Retention Compliance API

- [ ] 8.1 Create `lib/app_web/controllers/retention_policy_controller.ex` — `show/2` (GET), `update/2` (PUT), `delete/2` (DELETE)
- [ ] 8.2 Create `lib/app_web/controllers/retention_policy_json.ex` — renders retention policy response with effective_days, computed values, contributing_frameworks, conflicts, data_age_range
- [ ] 8.3 Add routes: `GET /api/v1/retention-policy` to `:api_authenticated` scope, `PUT /api/v1/retention-policy` and `DELETE /api/v1/retention-policy` to `:api_write` scope
- [ ] 8.4 Implement data age range lookup — query oldest and newest audit entry timestamps for the account
- [ ] 8.5 Create `lib/app_web/schemas/retention_policy_response.ex` — `effective_days`, `computed_minimum_days`, `computed_maximum_days`, `computed_recommendation_days`, `override_days`, `contributing_frameworks` (array of objects), `conflicts`, `computed_at`, `data_age_range`
- [ ] 8.6 Create `lib/app_web/schemas/retention_policy_update_request.ex` — `override_days` (required integer)
- [ ] 8.7 Add OpenApiSpex operation annotations to `RetentionPolicyController` (`show`, `update`, `delete`) referencing the new schema modules
- [ ] 8.8 Return HTTP 422 with framework-specific error messages for invalid overrides

## 9. Tests

- [ ] 9.1 Test each framework's `retention_policy/0` returns correct values
- [ ] 9.2 Test retention policy structure validation rejects invalid configurations
- [ ] 9.3 Test `framework_policies/1` returns only active frameworks for account
- [ ] 9.4 Test `compute_effective/1` with single framework — values pass through
- [ ] 9.5 Test `compute_effective/1` with multiple frameworks — max of minimums, min of maximums, max of recommendations
- [ ] 9.6 Test `compute_effective/1` with no frameworks — returns system defaults
- [ ] 9.7 Test conflict detection when effective_minimum > effective_maximum
- [ ] 9.8 Test `set_retention_override/2` accepts override >= effective_minimum
- [ ] 9.9 Test `set_retention_override/2` rejects override < effective_minimum with framework names in error
- [ ] 9.10 Test `set_retention_override/2` warns but accepts override > effective_maximum
- [ ] 9.11 Test `clear_retention_override/1` resets to computed effective retention
- [ ] 9.12 Test recomputation triggers on framework activation and deactivation
- [ ] 9.13 Test partition aging uses per-account retention (override when set, computed otherwise)
- [ ] 9.14 Test GDPR purpose tracking — add/remove/expire purposes
- [ ] 9.15 Test purpose expiry with other framework minimums still active — entry retained
- [ ] 9.16 Test `GET /api/v1/retention-policy` returns full retention posture
- [ ] 9.17 Test `PUT /api/v1/retention-policy` validates and sets override
- [ ] 9.18 Test `DELETE /api/v1/retention-policy` clears override and recomputes
- [ ] 9.19 Test retention endpoints enforce auth — read key for GET, write key for PUT/DELETE
- [ ] 9.20 Test retention column defaults on new accounts
