# Constitution

<!-- Hard constraints: MUST / NEVER / SHALL NOT.
     Violations are BLOCKING. AI agents check this before every change.
     Advisory guidance (SHOULD / PREFER) belongs in standards.md, not here.

     ## AI Agent Behavioral Rules (non-negotiable)

     These rules govern how AI agents interact with users at EVERY step:

     ### UX: Always Offer an Open Choice
     - Every choice menu presented to a user (scale assessment, fit-level,
       schema selection, skill selection, TODO triage, etc.) MUST include
       "Other — write your own" as the LAST option.
     - NEVER force users into predefined categories without a free-text escape.

     ### TODO.md Triage
     - Periodically scan openspec/project/TODO.md, openspec/epics/<name>/TODO.md,
       and change-level TODO.md files.
     - Surface triage prompts: "You have N items. Promote to a <level>
       (project-wide / new-epic / vertical-slice / simple-change) or dismiss?"
     - Items >90 days with no activity: flag as ◌ dormant. Do NOT auto-delete.
  -->

## Core Principles

<!-- 3-5 immutable design principles.
     Example:
     - All cross-service calls MUST go through the API gateway.
     - No circular dependencies between bounded contexts. -->

## Banned Patterns

<!-- Absolute prohibitions (NEVER).
     Example:
     - NEVER introduce a new state management library without architecture review.
     - NEVER hardcode credentials or secrets in any file. -->

## Required Patterns

<!-- Must-follow conventions (MUST).
     Example:
     - All new APIs MUST use REST with OpenAPI 3.0 specification.
     - All database migrations MUST be reversible. -->

## Compliance Requirements

<!-- Legal, security, or regulatory constraints.
     Example:
     - GDPR: user data MUST be deletable on request.
     - SOC2: all auth events MUST be logged. -->

## Tech Stack Constraints

<!-- Banned or required technologies.
     Example:
     - Banned: MongoDB for relational data.
     - Required: PostgreSQL >= 15 for persistent storage. -->
