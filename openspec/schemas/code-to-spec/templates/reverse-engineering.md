# Reverse Engineering

<!-- Reads source code and reverse-engineers observable behavior
     into BDD shadow specs. Output: openspec/vendor-specs/<module-name>/spec.md -->

## Source Inventory

| File | Language | Lines | Domain |
|------|----------|-------|--------|
| <!-- path --> | <!-- lang --> | <!-- N --> | <!-- domain --> |

## Extracted Specifications

<!-- BDD requirements with [REQ-CODE-XXX] IDs.
     Focus on OBSERVABLE BEHAVIOR — what inputs, outputs, errors, side effects.
     Do NOT describe internal implementation details. -->

#### Requirement: <!-- observed behavior --> [REQ-CODE-001]
<!-- What the code actually does, using SHALL/MUST -->

##### Scenario: <!-- normal path -->
- **GIVEN** <!-- precondition observed in code -->
- **WHEN** <!-- input/trigger observed in code -->
- **THEN** <!-- output/effect observed in code -->

## Fidelity Notes

- **Confidence**: <!-- High/Medium/Low -->
- **Uncovered Behavior**: <!-- Code paths whose purpose is unclear -->
- **Dead Code Suspects**: <!-- Code paths that appear unreachable -->

## Integration Surface

<!-- APIs, public functions, module exports forming the boundary. -->

| Function | Signature | Inputs | Outputs | Error Modes |
|----------|-----------|--------|---------|-------------|
| <!-- name --> | <!-- sig --> | <!-- type --> | <!-- type --> | <!-- conditions --> |
