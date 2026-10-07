---
# Slice proposal front matter. Status is the single source of truth.
status: active       # active | done | abandoned | deprecated
parent_epic: null    # epic slug (e.g., "2025-05-auth") or null for standalone
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: <!-- Slice Name -->

<!-- ## Fit-Level Context
     This slice was assessed as a vertical-slice (testable MVP).
     If scope expands during implementation, re-assess via /opsx:explore. -->

## Parent Epic

<!-- Link to openspec/epics/YYYY-MM-<slug>/epic.md, or "Standalone vertical slice."
     Keep in sync with the front matter parent_epic field. -->

## Slice Type

<!-- Feature / Infrastructure / Coordination -->

## User Story

<!-- "As a <role>, I can <action> so that <value>."
     For infrastructure: "The system can <capability>." -->

## In Scope

<!-- Specific behaviors this slice delivers.
     Include ALL layers (API, UI, DB) as a unified behavior. -->

## Out of Scope

<!-- Explicitly exclude behaviors belonging to OTHER slices.
     Prevents scope creep. -->

## Acceptance Criteria

<!-- E2E testable scenarios using Given-When-Then. -->

#### Scenario: <!-- name -->
- **GIVEN** <!-- precondition -->
- **WHEN** <!-- action -->
- **THEN** <!-- expected outcome -->

## Affected Domains

<!-- Bounded contexts from openspec/project/architecture.md touched by this slice. -->