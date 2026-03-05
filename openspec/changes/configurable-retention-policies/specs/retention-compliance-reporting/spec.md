## ADDED Requirements

### Requirement: Retention policy read endpoint

`GET /api/v1/retention-policy` MUST return the account's effective retention policy. The response MUST include `effective_days` (the operative retention: override if set, otherwise computed), `computed_minimum_days`, `computed_maximum_days` (integer or null), `computed_recommendation_days`, `override_days` (integer or null), `contributing_frameworks` (list of objects with `name`, `minimum_days`, `maximum_days`, `recommendation_days`, and `description`), `conflicts` (list of strings), `computed_at` (ISO 8601 timestamp or null), and `data_age_range` (object with `oldest_entry_days` and `newest_entry_days` for the account). The endpoint MUST require read access (`:api_authenticated` pipeline).

#### Scenario: Account with HIPAA and SOC 2, no override
- **WHEN** `GET /api/v1/retention-policy` is called for an account with HIPAA and SOC 2 active and no override
- **THEN** the response is HTTP 200 with:
  ```json
  {
    "data": {
      "effective_days": 2190,
      "computed_minimum_days": 2190,
      "computed_maximum_days": null,
      "computed_recommendation_days": 2190,
      "override_days": null,
      "contributing_frameworks": [
        {
          "name": "hipaa",
          "minimum_days": 2190,
          "maximum_days": null,
          "recommendation_days": 2190,
          "description": "HIPAA requires retention of audit records for a minimum of 6 years (2190 days)"
        },
        {
          "name": "soc2",
          "minimum_days": 365,
          "maximum_days": null,
          "recommendation_days": 365,
          "description": "SOC 2 requires retention of audit logs for a minimum of 1 year (365 days)"
        }
      ],
      "conflicts": [],
      "computed_at": "2026-03-04T12:00:00Z",
      "data_age_range": {
        "oldest_entry_days": 412,
        "newest_entry_days": 0
      }
    }
  }
  ```

#### Scenario: Account with override set
- **WHEN** `GET /api/v1/retention-policy` is called for an account with `retention_override_days` of 2555
- **THEN** `effective_days` is 2555 and `override_days` is 2555

#### Scenario: Account with no active frameworks
- **WHEN** `GET /api/v1/retention-policy` is called for an account with no frameworks
- **THEN** `contributing_frameworks` is `[]`, `computed_minimum_days` is 0, and `effective_days` reflects system defaults

### Requirement: Retention policy override endpoint

`PUT /api/v1/retention-policy` MUST accept a JSON body with `override_days` (integer) and set the account's retention override. The endpoint MUST validate the override against the effective minimum. On success it MUST return the updated retention policy (same shape as the GET response). On validation failure (below minimum) it MUST return HTTP 422 with an error message naming the frameworks requiring the longer period. The endpoint MUST require write access (`:api_write` pipeline).

#### Scenario: Valid override
- **WHEN** `PUT /api/v1/retention-policy` is called with `{"override_days": 2555}` for an account with `effective_minimum` of 2190
- **THEN** the response is HTTP 200 with the updated retention policy showing `override_days: 2555` and `effective_days: 2555`

#### Scenario: Override below minimum rejected
- **WHEN** `PUT /api/v1/retention-policy` is called with `{"override_days": 180}` for an account with `effective_minimum` of 2190 (HIPAA)
- **THEN** the response is HTTP 422 with `{"errors": [{"detail": "Retention of 180 days is below the minimum of 2190 days required by hipaa"}]}`

#### Scenario: Override above maximum accepted with warning
- **WHEN** `PUT /api/v1/retention-policy` is called with `{"override_days": 3650}` for an account with `effective_maximum` of 2555
- **THEN** the response is HTTP 200 with the updated policy and a `warnings` field containing the over-retention notice

#### Scenario: Missing or invalid override_days
- **WHEN** `PUT /api/v1/retention-policy` is called with `{}` or `{"override_days": "abc"}`
- **THEN** the response is HTTP 422 with a validation error for the `override_days` field

### Requirement: Retention policy clear endpoint

`DELETE /api/v1/retention-policy` MUST clear the account's retention override, set `retention_override_days` to nil, trigger recomputation of the effective retention from active frameworks, and return the updated retention policy (same shape as the GET response). The endpoint MUST require write access (`:api_write` pipeline).

#### Scenario: Override cleared
- **WHEN** `DELETE /api/v1/retention-policy` is called for an account with `retention_override_days` of 2555 and `effective_minimum` of 2190
- **THEN** the response is HTTP 200 with `override_days: null` and `effective_days: 2190`

#### Scenario: Clear when no override set
- **WHEN** `DELETE /api/v1/retention-policy` is called for an account that has no override
- **THEN** the response is HTTP 200 with the current retention policy unchanged (idempotent)

### Requirement: Retention endpoint authentication and authorization

All retention policy endpoints MUST use the existing API authentication pipelines. `GET /api/v1/retention-policy` MUST require the `:api_authenticated` pipeline (read or write keys). `PUT /api/v1/retention-policy` and `DELETE /api/v1/retention-policy` MUST require the `:api_write` pipeline (write keys only).

#### Scenario: Read key can view retention policy
- **WHEN** `GET /api/v1/retention-policy` is called with a `pk_*` (read) key
- **THEN** the response is HTTP 200 with the retention policy

#### Scenario: Read key cannot modify retention policy
- **WHEN** `PUT /api/v1/retention-policy` is called with a `pk_*` (read) key
- **THEN** the response is HTTP 403

#### Scenario: Write key can modify retention policy
- **WHEN** `PUT /api/v1/retention-policy` is called with a `sk_*` (write) key
- **THEN** the override is accepted (if valid) and the updated policy is returned

### Requirement: Retention response shape consistency

All three retention endpoints (`GET`, `PUT`, `DELETE`) MUST return the retention policy in the same `{"data": {...}}` envelope shape. The response MUST include all fields described in the GET requirement. `PUT` and `DELETE` responses represent the state after the mutation.

#### Scenario: PUT and GET return same shape
- **WHEN** `PUT /api/v1/retention-policy` succeeds and is immediately followed by `GET /api/v1/retention-policy`
- **THEN** both responses have identical structure and matching values for all retention fields
