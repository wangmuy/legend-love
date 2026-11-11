---
name: mvp-upgrade
description: Upgrade project scale (Sketch→Blueprint→Modular→Ecosystem) with verification gate. Scans existing state, bootstraps new artifacts, verifies transition.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
---

Upgrade the project from one scale level to the next. Scans existing
project state, bootstraps new artifacts, and verifies the transition.

---

## Steps

### 1. Detect current scale

```bash
cat openspec/config.yaml
ls openspec/project/profile.md 2>/dev/null
ls openspec/epics/ 2>/dev/null
find openspec/changes/ -maxdepth 1 -mindepth 1 -type d ! -name 'archive' | wc -l
ls openspec/vendor-specs/ 2>/dev/null
```

Determine: Sketch / Blueprint / Modular / Ecosystem

### 2. Recommend target scale

If user didn't specify, recommend the next logical step.
Always include "Other — write your own target" as last option.

### 3. Create project-upgrade change

```bash
openspec new change upgrade-<from>-to-<to> --schema project-upgrade
```

### 4. Generate upgrade-plan

- Current Scale Assessment, Target Scale
- New Artifacts to Create (table)
- Migration Steps (ordered checklist)
- What Stays the Same, Rollback Plan

### 5. Execute migration

Create artifacts, update config.yaml, validate schemas.

### 6. Generate upgrade-verification

Checklist: artifacts exist, schemas validate, existing changes intact.
Acceptance test: create test change, verify AI reads constitution/architecture.

### 7. Show summary

Current → Target. New artifacts installed. Verification passed.

## Guardrails
**Skills**: Check `openspec/skills-profile.yaml` for suggested community
skills under key `mvp-upgrade`. Offer to load them — user decides.

- Upgrade is ADDITIVE — existing work is NEVER touched
- Verify before completing
- Always include a rollback plan
- If current scale is unclear, suggest `/mvp:evaluate-scale` first## Help

When invoked with `help` or `--help`:

```
/mvp:upgrade — migrate project to a higher scale

Usage:
  /mvp:upgrade [target-scale]

If no target specified, detects current scale and recommends next step.

Scale ladder:
  Sketch → Blueprint → Modular → Ecosystem

Examples:
  /mvp:upgrade                       # detect + recommend
  /mvp:upgrade Modular               # specific target
```
