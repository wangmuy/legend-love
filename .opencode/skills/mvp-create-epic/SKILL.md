---
name: mvp-create-epic
description: Create an epic to track a large initiative decomposed into vertical slices. Creates openspec/epics/YYYY-MM-slug/ with epic.md and TODO.md.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
---

Create an epic to decompose a large initiative into independently
testable vertical slices. Epics live in `openspec/epics/YYYY-MM-<slug>/`
and are tracking artifacts — never archived.

---

## Steps

### 1. Gather epic vision

Use the **AskUserQuestion tool**:

1. What's the epic about? (2-3 sentence business goal)
2. How many slices do you anticipate? Names or behaviors?
3. Any cross-cutting concerns (auth, performance, compliance)?

From the answers, derive a kebab-case slug.

### 2. Create epic directory

```bash
DATE=$(date +%Y-%m)
mkdir -p openspec/epics/$DATE-<slug>
```

### 3. Generate epic.md

Create `openspec/epics/$DATE-<slug>/epic.md` with YAML front matter then body:

```yaml
---
status: active
created: $DATE
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
  impact: []
---
# Epic: <Title>
```

Then populate sections:
- **Vision**: 2-3 sentences on the business goal
- **Vertical Slices**: Each independently testable and shippable.
  Feature / Infrastructure / Coordination types.
  For each: Business Value, Acceptance Criteria (DoD), Affected Domains,
  Implementation Changes, Status.
  CORRECT: "User can enroll in 2FA and verify their authenticator"
  WRONG: "Backend 2FA API" or "Frontend 2FA enrollment UI"
- **Slice Dependency Graph**: Mermaid or ASCII diagram
- **Global Acceptance Criteria**: Epic-level DoD

### 4. Create TODO.md

```bash
cat > openspec/epics/$DATE-<slug>/TODO.md << 'EOF'
# TODO — Future Slices & Ideas
- [ ] 
EOF
```

### 5. Show summary

```
## Epic Created: <slug>

openspec/epics/YYYY-MM-<slug>/
├── epic.md    — Vision + vertical slice decomposition
└── TODO.md    — Future slice ideas

Next: /mvp:create-slice <slice-name> for each slice
```

## Guardrails
**Skills**: Check `openspec/skills-profile.yaml` for suggested community
skills under key `mvp-create-epic`. Offer to load them — user decides.

- Choose the current month for the date prefix (YYYY-MM)
- Slices MUST be business-behavior MVPs, not tech-stack assignments
- Each slice must have a clear, testable DoD
- Epics are planning artifacts — NEVER archived