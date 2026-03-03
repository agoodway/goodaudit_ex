## ADDED Requirements

### Requirement: Canonical payload format

The module MUST compute checksums over a pipe-delimited canonical payload with fields in a fixed order: `{account_id}|{sequence_number}|{previous_checksum}|{ISO8601_timestamp}|{user_id}|{user_role}|{session_id}|{action}|{resource_type}|{resource_id}|{outcome}|{failure_reason}|{phi_accessed}|{source_ip}|{user_agent}|{canonical_json_metadata}`. The `account_id` MUST be the first field for multi-tenant isolation. Nil fields MUST be rendered as empty strings (producing `||`). The genesis entry (sequence_number 1) MUST use the literal string `"genesis"` as previous_checksum in the payload.

#### Scenario: Deterministic output
- **WHEN** `compute_checksum/3` is called twice with the same key, attrs, and previous_checksum
- **THEN** both calls return the same 64-character lowercase hex string

#### Scenario: Field sensitivity
- **WHEN** any single field in the attrs map is changed
- **THEN** the resulting checksum differs from the original

#### Scenario: Genesis entry
- **WHEN** `compute_checksum/3` is called with `nil` as previous_checksum
- **THEN** the payload uses the literal string `"genesis"` in the previous_checksum position

#### Scenario: Nil field handling
- **WHEN** optional fields (session_id, source_ip, user_agent, failure_reason) are nil
- **THEN** they are rendered as empty strings in the payload, producing `||`

#### Scenario: Different keys produce different checksums
- **WHEN** `compute_checksum/3` is called with two different keys but identical attrs
- **THEN** the resulting checksums differ

#### Scenario: Different account_ids produce different checksums
- **WHEN** `compute_checksum/3` is called with the same key but different `account_id` values in attrs
- **THEN** the resulting checksums differ

### Requirement: Metadata canonicalization

The module MUST canonicalize metadata maps by sorting keys alphabetically (recursively for nested maps) and encoding as compact JSON. Empty or nil metadata MUST produce `"{}"`.

#### Scenario: Key ordering independence
- **WHEN** two metadata maps contain the same keys and values but were constructed in different insertion order
- **THEN** their canonical JSON representations are identical and produce the same checksum

#### Scenario: Nested map sorting
- **WHEN** metadata contains nested maps
- **THEN** keys at every nesting level are sorted alphabetically

#### Scenario: Empty metadata
- **WHEN** metadata is nil or an empty map
- **THEN** the canonical representation is the string `"{}"`

### Requirement: Checksum verification

The module MUST provide a `verify_checksum/3` function that accepts a key, a log entry struct, and the previous_checksum, recomputes the expected checksum, and compares it against the stored checksum using constant-time comparison to prevent timing attacks.

#### Scenario: Valid entry verification
- **WHEN** `verify_checksum/3` is called with the correct key, an unmodified log entry, and its correct previous_checksum
- **THEN** the function returns `true`

#### Scenario: Tampered entry detection
- **WHEN** `verify_checksum/3` is called with a log entry whose stored checksum does not match the recomputed value
- **THEN** the function returns `false`

#### Scenario: Wrong key detection
- **WHEN** `verify_checksum/3` is called with a key different from the one used to compute the original checksum
- **THEN** the function returns `false`

### Requirement: Key as explicit parameter

All functions that use the HMAC key MUST accept it as an explicit parameter (raw binary). The module MUST NOT read keys from application config, environment variables, or any other source. The caller is responsible for providing the correct key.

#### Scenario: No implicit key loading
- **WHEN** the module is used
- **THEN** it never calls `Application.fetch_env!` or reads any config — the key is always a function argument
