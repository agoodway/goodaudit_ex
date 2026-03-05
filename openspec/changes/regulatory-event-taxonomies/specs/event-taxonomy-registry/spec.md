## ADDED Requirements

### Requirement: Taxonomy behaviour contract

A `GA.Compliance.Taxonomy` behaviour MUST define callbacks that all framework taxonomy modules implement: `framework/0` returning the framework identifier string, `taxonomy_version/0` returning a semantic version string, `taxonomy/0` returning the full taxonomy tree as `%{category => %{subcategory => [action_name]}}`, and `actions/0` returning a flat list of all action names in the taxonomy.

#### Scenario: Behaviour enforcement
- **WHEN** a new taxonomy module is created without implementing all callbacks
- **THEN** a compilation warning is raised for each missing callback

#### Scenario: Taxonomy structure
- **WHEN** `taxonomy/0` is called on any framework module
- **THEN** it returns a map where keys are category strings, values are maps of subcategory strings to lists of action name strings

### Requirement: HIPAA taxonomy

`GA.Compliance.Taxonomies.HIPAA` MUST implement the `GA.Compliance.Taxonomy` behaviour with framework `"hipaa"` and define the following taxonomy tree:

- `"access"` -> `"phi"` -> `["phi_read", "phi_write", "phi_delete"]`; `"system"` -> `["login", "logout", "session_timeout"]`
- `"admin"` -> `"user"` -> `["user_provision", "user_deprovision", "role_change"]`; `"system"` -> `["config_change", "key_rotation"]`
- `"disclosure"` -> `"authorized"` -> `["treatment", "payment", "operations"]`; `"unauthorized"` -> `["breach"]`

#### Scenario: HIPAA taxonomy lookup
- **WHEN** `GA.Compliance.Taxonomies.HIPAA.taxonomy()` is called
- **THEN** it returns the full HIPAA taxonomy map with categories `"access"`, `"admin"`, and `"disclosure"`

#### Scenario: HIPAA flat action list
- **WHEN** `GA.Compliance.Taxonomies.HIPAA.actions()` is called
- **THEN** it returns a flat list containing all 15 HIPAA action names: `"phi_read"`, `"phi_write"`, `"phi_delete"`, `"login"`, `"logout"`, `"session_timeout"`, `"user_provision"`, `"user_deprovision"`, `"role_change"`, `"config_change"`, `"key_rotation"`, `"treatment"`, `"payment"`, `"operations"`, `"breach"`

#### Scenario: HIPAA version
- **WHEN** `GA.Compliance.Taxonomies.HIPAA.taxonomy_version()` is called
- **THEN** it returns `"1.0.0"`

### Requirement: SOC 2 taxonomy

`GA.Compliance.Taxonomies.SOC2` MUST implement the `GA.Compliance.Taxonomy` behaviour with framework `"soc2"` and define the following taxonomy tree:

- `"change"` -> `"deployment"` -> `["deploy", "config_update", "rollback"]`
- `"access"` -> `"production"` -> `["production_access", "privilege_escalation", "data_export"]`
- `"incident"` -> `"lifecycle"` -> `["detection", "response", "resolution"]`
- `"monitoring"` -> `"alerts"` -> `["alert_triggered", "alert_acknowledged"]`

#### Scenario: SOC 2 taxonomy lookup
- **WHEN** `GA.Compliance.Taxonomies.SOC2.taxonomy()` is called
- **THEN** it returns the full SOC 2 taxonomy map with categories `"change"`, `"access"`, `"incident"`, and `"monitoring"`

#### Scenario: SOC 2 flat action list
- **WHEN** `GA.Compliance.Taxonomies.SOC2.actions()` is called
- **THEN** it returns a flat list containing all 11 SOC 2 action names

### Requirement: PCI-DSS taxonomy

`GA.Compliance.Taxonomies.PCIDSS` MUST implement the `GA.Compliance.Taxonomy` behaviour with framework `"pci_dss"` and define the following taxonomy tree:

- `"cardholder"` -> `"data"` -> `["data_access", "data_modification", "data_deletion"]`
- `"authentication"` -> `"session"` -> `["login", "logout", "failed_auth", "mfa_challenge"]`
- `"key_management"` -> `"lifecycle"` -> `["key_creation", "key_rotation", "key_destruction"]`
- `"network"` -> `"security"` -> `["firewall_change", "access_rule_change"]`

#### Scenario: PCI-DSS taxonomy lookup
- **WHEN** `GA.Compliance.Taxonomies.PCIDSS.taxonomy()` is called
- **THEN** it returns the full PCI-DSS taxonomy map with categories `"cardholder"`, `"authentication"`, `"key_management"`, and `"network"`

#### Scenario: PCI-DSS flat action list
- **WHEN** `GA.Compliance.Taxonomies.PCIDSS.actions()` is called
- **THEN** it returns a flat list containing all 12 PCI-DSS action names

### Requirement: GDPR taxonomy

`GA.Compliance.Taxonomies.GDPR` MUST implement the `GA.Compliance.Taxonomy` behaviour with framework `"gdpr"` and define the following taxonomy tree:

- `"processing"` -> `"lifecycle"` -> `["collection", "storage", "use", "disclosure", "erasure"]`
- `"subject_request"` -> `"rights"` -> `["access", "rectification", "erasure", "portability", "restriction", "objection"]`
- `"consent"` -> `"management"` -> `["grant", "withdraw", "renewal"]`
- `"transfer"` -> `"cross_border"` -> `["cross_border", "adequacy_decision", "standard_clauses"]`

#### Scenario: GDPR taxonomy lookup
- **WHEN** `GA.Compliance.Taxonomies.GDPR.taxonomy()` is called
- **THEN** it returns the full GDPR taxonomy map with categories `"processing"`, `"subject_request"`, `"consent"`, and `"transfer"`

#### Scenario: GDPR flat action list
- **WHEN** `GA.Compliance.Taxonomies.GDPR.actions()` is called
- **THEN** it returns a flat list containing all 17 GDPR action names

### Requirement: ISO 27001 taxonomy

`GA.Compliance.Taxonomies.ISO27001` MUST implement the `GA.Compliance.Taxonomy` behaviour with framework `"iso_27001"` and define the following taxonomy tree:

- `"access_control"` -> `"identity"` -> `["authentication", "authorization", "privilege_change"]`
- `"asset_management"` -> `"lifecycle"` -> `["classification", "handling", "disposal"]`
- `"incident_management"` -> `"lifecycle"` -> `["detection", "assessment", "response", "lessons_learned"]`
- `"change_management"` -> `"workflow"` -> `["request", "approval", "implementation", "review"]`

#### Scenario: ISO 27001 taxonomy lookup
- **WHEN** `GA.Compliance.Taxonomies.ISO27001.taxonomy()` is called
- **THEN** it returns the full ISO 27001 taxonomy map with categories `"access_control"`, `"asset_management"`, `"incident_management"`, and `"change_management"`

#### Scenario: ISO 27001 flat action list
- **WHEN** `GA.Compliance.Taxonomies.ISO27001.actions()` is called
- **THEN** it returns a flat list containing all 14 ISO 27001 action names

### Requirement: Taxonomy registry lookup

`GA.Compliance.Taxonomy.get/1` MUST accept a framework identifier string and return `{:ok, module}` for a known framework or `{:error, :unknown_framework}` for an unrecognized one. `GA.Compliance.Taxonomy.list_frameworks/0` MUST return a list of all registered framework identifier strings.

#### Scenario: Known framework lookup
- **WHEN** `GA.Compliance.Taxonomy.get("hipaa")` is called
- **THEN** it returns `{:ok, GA.Compliance.Taxonomies.HIPAA}`

#### Scenario: Unknown framework lookup
- **WHEN** `GA.Compliance.Taxonomy.get("unknown")` is called
- **THEN** it returns `{:error, :unknown_framework}`

#### Scenario: List all frameworks
- **WHEN** `GA.Compliance.Taxonomy.list_frameworks()` is called
- **THEN** it returns `["gdpr", "hipaa", "iso_27001", "pci_dss", "soc2"]` (sorted alphabetically)

### Requirement: Taxonomy path resolution

`GA.Compliance.Taxonomy.resolve_path/2` MUST accept a framework module and a dot-separated path string, returning the matched actions. For a full path like `"access.phi.phi_read"` it returns `["phi_read"]`. For a category path like `"access.*"` it returns all actions under all subcategories of `"access"`. For a category+subcategory path like `"access.phi.*"` it returns all actions under that subcategory.

#### Scenario: Exact action path
- **WHEN** `resolve_path(GA.Compliance.Taxonomies.HIPAA, "access.phi.phi_read")` is called
- **THEN** it returns `{:ok, ["phi_read"]}`

#### Scenario: Subcategory wildcard
- **WHEN** `resolve_path(GA.Compliance.Taxonomies.HIPAA, "access.phi.*")` is called
- **THEN** it returns `{:ok, ["phi_read", "phi_write", "phi_delete"]}`

#### Scenario: Category wildcard
- **WHEN** `resolve_path(GA.Compliance.Taxonomies.HIPAA, "access.*")` is called
- **THEN** it returns `{:ok, ["phi_read", "phi_write", "phi_delete", "login", "logout", "session_timeout"]}`

#### Scenario: Invalid path
- **WHEN** `resolve_path(GA.Compliance.Taxonomies.HIPAA, "nonexistent.path")` is called
- **THEN** it returns `{:error, :invalid_path}`

### Requirement: Taxonomy versioning

Each taxonomy module MUST declare `taxonomy_version/0` returning a semantic version string (e.g., `"1.0.0"`). Taxonomy updates MUST be additive only -- new categories and actions may be added, but existing paths MUST NOT be renamed or removed.

#### Scenario: Version retrieval
- **WHEN** `taxonomy_version/0` is called on any framework module
- **THEN** it returns a string matching the pattern `"MAJOR.MINOR.PATCH"`

#### Scenario: Additive update
- **WHEN** a taxonomy module adds new actions in a minor version bump
- **THEN** all previously existing paths remain valid and resolvable

### Requirement: Taxonomy listing API endpoint

`GET /api/v1/taxonomies` MUST return a list of all registered frameworks with their versions. `GET /api/v1/taxonomies/:framework` MUST return the full taxonomy tree for a specific framework. Both endpoints require read access.

#### Scenario: List all taxonomies
- **WHEN** `GET /api/v1/taxonomies` is called with a valid read key
- **THEN** it returns `{"data": [{"framework": "hipaa", "version": "1.0.0"}, ...]}` for all registered frameworks

#### Scenario: Get specific taxonomy
- **WHEN** `GET /api/v1/taxonomies/hipaa` is called with a valid read key
- **THEN** it returns `{"data": {"framework": "hipaa", "version": "1.0.0", "taxonomy": {...}}}` with the full category/subcategory/action tree

#### Scenario: Unknown framework
- **WHEN** `GET /api/v1/taxonomies/unknown` is called
- **THEN** it returns HTTP 404 with `{"status": 404, "message": "Unknown framework: unknown"}`
