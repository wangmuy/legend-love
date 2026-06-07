# Spec Extraction

<!-- Converts external sources into BDD shadow specs.
     Output: openspec/vendor-specs/<source-name>/spec.md -->

## Source: <!-- Source ID from manifest -->

### Extracted Specifications

<!-- BDD-format requirements with [REQ-VENDOR-XXX] or [REQ-LEGACY-XXX] IDs.
     Given/When/Then scenarios. Focus on EXTERNAL BEHAVIOR. -->

#### Requirement: <!-- Name --> [REQ-VENDOR-001]
<!-- Requirement description using SHALL/MUST -->

##### Scenario: <!-- name -->
- **GIVEN** <!-- precondition -->
- **WHEN** <!-- action -->
- **THEN** <!-- expected outcome -->

### Fidelity Assessment

- **Confidence**: <!-- High / Medium / Low -->
- **Assumptions**: <!-- What we assumed during extraction -->
- **Missing Information**: <!-- What the source doesn't specify -->

### Integration Contract

<!-- Interface boundary between our system and this external source. -->

- **Input Contract**: <!-- What we send them -->
- **Output Contract**: <!-- What they send us -->
- **Error Handling**: <!-- Expected error modes -->
- **SLA**: <!-- Performance expectations, if known -->
