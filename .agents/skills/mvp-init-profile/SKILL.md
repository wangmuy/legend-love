---
name: mvp-init-profile
description: Bootstrap project-profile (profile, constitution, standards, architecture) from conversation or existing code. Generates into openspec/project/ permanently.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
---

Bootstrap the project's identity by creating a project-profile change
that generates into `openspec/project/` (permanent, never archived).

---

## Steps

### 1. Detect project state

```bash
ls openspec/project/profile.md 2>/dev/null && HAS_PROFILE=true || HAS_PROFILE=false
openspec list --json 2>/dev/null
```

If `HAS_PROFILE=true`, warn: "Project-profile already exists. Re-create?"
If user says yes, back up the existing `openspec/project/` first.

### 2. Gather project identity

**Greenfield** (no existing code/changes): explore the idea with the user.
"What are you building? What's the tech stack? Any hard constraints?"

**Brownfield** (code/changes exist): scan existing specs, code structure,
and active changes to auto-derive the profile.

### 3. Create the project-profile change

```bash
openspec new change init-profile --schema project-profile
```

### 4. Generate artifacts

Use `openspec instructions <artifact> --change "init-profile" --json` for each:

- **profile.md** — Project identity card. Scan existing specs to populate
  Implemented Capabilities. Scan active changes for In-Progress Changes.
  Set `Last auto-derived: <date>`. Add Quick Start section.

- **constitution.md** — Hard governance rules. Core Principles (3-5),
  Banned Patterns (NEVER...), Required Patterns (MUST...), Tech Stack
  Constraints. Each rule must be specific enough for AI to check compliance.

- **standards.md** — Advisory coding conventions. Style, naming,
  best practices, testing style, project idioms. Use SHOULD/PREFER.

- **architecture.md** — Domain canvas. Bounded contexts mapped to spec
  domains, data flow topology, integration points, global constraints.

- **domain-map.md** (optional) — Domain-to-repo mapping table. Only if
  multi-repo or multi-team.

### 5. Persist to openspec/project/

```bash
cp openspec/changes/init-profile/profile.md openspec/project/profile.md
cp openspec/changes/init-profile/constitution.md openspec/project/constitution.md
cp openspec/changes/init-profile/standards.md openspec/project/standards.md
cp openspec/changes/init-profile/architecture.md openspec/project/architecture.md
```

### 6. Show summary

```
## Project Profile Created

openspec/project/
├── profile.md        — Identity + auto-derived status dashboard
├── constitution.md   — Hard governance constraints
├── standards.md      — Advisory coding conventions
└── architecture.md   — Domain canvas + bounded contexts

Next: /mvp:evaluate-scale to assess scale
      /mvp:create-epic to start your first epic
```

## Guardrails
**Skills**: Check `openspec/skills-profile.yaml` for suggested community
skills under key `mvp-init-profile`. Offer to load them — user decides.

- Constitution rules must be SPECIFIC and TESTABLE
- Profile status MUST be auto-derived from filesystem scan
- Architecture must reference all existing spec domains
- Standards are advisory (SHOULD), Constitution is binding (MUST/NEVER)
- Mark profile with "Last auto-derived: <date>"