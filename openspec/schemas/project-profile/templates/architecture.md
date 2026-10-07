# Architecture Canvas

<!-- Last verified: <date>. Living document — update when boundaries change.

     ## Fan-Out Convention

     If this file exceeds ~500 lines, split into sub-documents:

     openspec/project/architecture/
     ├── _index.md          # Summary + global constraints + links to sub-docs
     ├── domains.md         # Bounded contexts (preserved across refreshes)
     ├── data-flows.md      # Topology diagrams (preserved across refreshes)
     └── integrations.md    # External system integrations (preserved across refreshes)

     Rules:
     - _index.md is the entry point — AI agents read this first
     - Auto-refresh updates _index.md summary; sub-docs are preserved
     - Fan-out when any section exceeds ~200 lines or total >500 lines
  -->

## Bounded Contexts

<!-- Each domain with responsibility, key entities, and spec link.
     Derive from openspec/specs/ structure. -->

### <!-- Domain Name -->

- **Responsibility**: <!-- What this domain owns -->
- **Spec**: `openspec/specs/<domain>/spec.md`
- **Key Entities**: <!-- Core concepts in this domain -->

## Data Flow Topology

<!-- How domains connect. Use Mermaid for visual clarity. -->

```mermaid
graph TD
    <!-- Domain relationships -->
```

## Integration Points

<!-- External systems, APIs, message queues.
     For each: protocol, direction, criticality. -->

| System | Protocol | Direction | Criticality |
|--------|----------|-----------|-------------|
| <!-- name --> | <!-- REST/gRPC/MQ --> | <!-- inbound/outbound --> | <!-- High/Medium/Low --> |

## Global Constraints

<!-- Cross-cutting architectural rules.
     Example: "All services communicate via the Gateway." -->

## Evolution Log

<!-- Dated log of significant architectural changes.
     Auto-populated from archived changes that touched architecture. -->

| Date | Change | Description |
|------|--------|-------------|
| <!-- YYYY-MM-DD --> | <!-- change name --> | <!-- what changed --> |
