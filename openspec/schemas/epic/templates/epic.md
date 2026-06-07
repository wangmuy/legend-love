---
# Epic front matter. Status is the single source of truth.
# Read with: head -10 epic.md | yq '.status'
status: active       # active | dormant | done | abandoned | deprecated
created: YYYY-MM
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
  impact: []
---
# Epic: <!-- Epic Title -->

<!-- Directory: openspec/epics/YYYY-MM-<slug>/epic.md
     
     ## Lifecycle
     
     - active: slices being created or implemented
     - dormant (◌): no slice activity for 60 days → signal to revisit
     - done (✓): all slices archived
     - abandoned: formally closed, not completed (moved to abandoned/)
     - deprecated: replaced by another epic (moved to abandoned/)
     - Epics are NEVER deleted — abandoned and completed epics remain as
       historical records. The profile.md dashboard auto-marks dormancy.
     
     ## Fit-Level Decision
     
     Before creating this epic, verify the work:
     1. Spans multiple independent testable streams (vertical slices)
     2. Cannot be achieved in a single vertical-slice or simple-change
     3. Does NOT change project identity or governance (that's project-wide)
     
     If the scope is unclear, use /opsx:explore first.
     Explorer concludes with: project-wide | new-epic | vertical-slice | simple-change -->

## Vision

<!-- 2-3 sentences on the business goal. What user value does this deliver? -->

## Vertical Slices

<!-- Each slice is independently testable and shippable.
     Types: Feature (user-facing), Infrastructure (build/devops),
     Coordination (integration).
     
     Status: [ ] Planned / [~] In Progress / [x] Done
     Derived from scanning openspec/changes/. -->

### MVP Slice N: <!-- Slice Name -->

- **Type**: Feature / Infrastructure / Coordination
- **Business Value**: <!-- What this slice enables -->
- **Acceptance Criteria (DoD)**: <!-- Observable, testable conditions -->
- **Affected Domains**: <!-- Bounded contexts touched -->
- **Implementation Changes**:
  - `change: <name>` → repo: <repo>
- **Status**: [ ] Planned

## Slice Dependency Graph

<!-- Mermaid or ASCII diagram. -->

## Global Acceptance Criteria

<!-- Epic-level DoD spanning all slices. -->

## Future Ideas

<!-- Emergent ideas for future slices. Feeds into TODO.md. -->
- [ ] <!-- idea -->