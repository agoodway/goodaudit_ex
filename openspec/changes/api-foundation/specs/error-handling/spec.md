## ALREADY IMPLEMENTED — No Changes Required

### Requirement: Fallback controller (IMPLEMENTED)

`GAWeb.FallbackController` handles error patterns returned by controllers: `{:error, %Ecto.Changeset{}}` → HTTP 422 with changeset errors, `{:error, :not_found}` → HTTP 404.

> **Note:** The original spec included `{:error, :no_entries}` → HTTP 422. If audit controllers need this pattern, it should be added as a new `call/2` clause in the existing FallbackController as part of the audit-endpoints change.

### Requirement: Changeset JSON rendering (IMPLEMENTED)

`GAWeb.ChangesetJSON` traverses changeset errors and renders them as a JSON-friendly map with field names as keys and error message lists as values.
