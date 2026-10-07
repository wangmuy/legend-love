# Upgrade Verification

<!-- Post-upgrade checklist. All checks must pass for VERIFIED status. -->

## Verification Checklist

- [ ] `openspec/project/profile.md` exists and accurately reflects state
- [ ] `openspec/project/constitution.md` exists with specific, testable rules
- [ ] `openspec/project/standards.md` exists with advisory guidance
- [ ] `openspec/project/architecture.md` covers all existing spec domains
- [ ] `openspec/config.yaml` updated with correct schema defaults
- [ ] New schemas validate: `openspec schema validate <name>` for each
- [ ] Existing changes are NOT broken — test with `openspec list --json`
- [ ] AI can read project context: test by creating a test change
- [ ] Profile auto-derivation works: status matches actual state

## Acceptance Test

<!-- Create a test spec-driven change. Verify AI behavior. -->

- [ ] AI references constitution for constraints
- [ ] AI references architecture for domain context
- [ ] AI does not violate any banned patterns
- [ ] AI loads skills from skills-profile.yaml (if configured)

## Verdict

<!-- ✓ VERIFIED — all checks passed.
     ✗ FAILED — see issues below. Do NOT proceed until resolved. -->
