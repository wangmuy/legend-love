---
# Change manifest front matter.
parent_epic: null    # epic slug or null for standalone slice
---
# Change Manifest: <!-- Slice Name -->

## Change Assignments

<!-- Each change is a spec-driven implementation unit. -->

### Change: <!-- kebab-case-name -->

- **Repository**: <!-- repo-name, or "this repo" for monorepo -->
- **Scope**: <!-- frontend / backend / fullstack / database / infra -->
- **Responsibility**: <!-- What this change owns in the slice -->
- **Depends On**: <!-- Other changes in this manifest, or "none" -->
- **Status**: [ ] Created / [~] In Progress / [x] Archived

## Shared Contract Stubs

<!-- API contracts enabling parallel development.
     Each contract must be precise enough for a frontend change
     to build complete UI mocks without the backend. -->

### <!-- Contract Name -->

```
<!-- Endpoint, method, request/response format -->
```

## Integration Test Plan

<!-- How to verify the slice end-to-end after all changes complete.
     E2E test scenarios. -->

#### Scenario: <!-- end-to-end behavior -->
- **GIVEN** <!-- precondition -->
- **WHEN** <!-- action spanning all changes -->
- **THEN** <!-- expected system behavior -->