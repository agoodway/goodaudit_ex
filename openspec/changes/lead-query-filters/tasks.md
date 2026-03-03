## 1. Query Surface and Parsing

- [ ] 1.1 Extend endpoint and context filter option schemas with lead-domain parameters
- [ ] 1.2 Implement strict type coercion and validation for added filter params
- [ ] 1.3 Extend response `meta` with applied-filter and effective-limit diagnostics

## 2. Query Engine and Indexing

- [ ] 2.1 Update query builder to apply new predicates with mandatory account scoping
- [ ] 2.2 Add account-prefixed indexes for high-frequency compound lead filters
- [ ] 2.3 Validate cursor pagination correctness with compound lead predicates

## 3. Documentation and Tests

- [ ] 3.1 Update OpenAPI docs for new query params and metadata fields
- [ ] 3.2 Add endpoint tests for combined lead filters and parsing errors
- [ ] 3.3 Add performance-focused tests/assertions for index-backed query paths
