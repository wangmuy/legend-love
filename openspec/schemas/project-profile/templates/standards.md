# Standards

<!-- Advisory guidance: SHOULD / PREFER.
     Deviations allowed with explicit justification.
     Contrasts with constitution.md where violations are blocking. -->

## Coding Style

<!-- Formatting, naming, file organization.
     Example:
     - Prefer `const` over `let`. Use `let` only for reassignment.
     - Use arrow functions for React components.
     - Files: one export per file for components, barrel exports for utilities. -->

## Best Practices

<!-- Recommended patterns, anti-patterns to avoid.
     Example:
     - Prefer composition over inheritance for React components.
     - Avoid deeply nested callbacks — use async/await or flatten.
     - Write pure functions where possible. -->

## Language Patterns

<!-- Idiomatic patterns for the tech stack.
     Example:
     - Use async/await over raw Promise chains.
     - Use optional chaining (?.) over nested null checks.
     - Prefer early returns over deep if/else nesting. -->

## Testing Style

<!-- Test organization, naming, coverage expectations.
     Example:
     - Unit tests: test behavior, not implementation.
     - Name tests: "should <expected behavior> when <condition>".
     - Aim for >80% coverage on new code. -->

## Project Idioms

<!-- Conventions specific to this project.
     Example:
     - All API handlers go in src/handlers/.
     - Use the project logger (src/lib/logger) — never console.log.
     - Feature flags: add to src/config/features.ts, check at boundaries. -->
