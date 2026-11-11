---
name: mvp-reverse
description: Reverse-engineer behavioral specs from existing source code into BDD shadow specs. Reads code, extracts observable behavior, produces vendor-specs with fidelity assessment.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
---

Reverse-engineer behavioral specifications from existing undocumented
source code into BDD shadow specs with fidelity assessment.

---

## Steps

### 1. Gather source scope

Use the **AskUserQuestion tool**:

1. Which source code paths to analyze?
2. What module name should the specs use?
3. Any known behavioral boundaries or interfaces?

### 2. Create the code-to-spec change

```bash
openspec new change reverse-<module-name> --schema code-to-spec
```

### 3. Generate reverse-engineering report

- **Source Inventory**: Files, language, lines, domain
- **Extracted Specifications**: BDD with [REQ-CODE-XXX] IDs.
  Focus on OBSERVABLE BEHAVIOR (inputs, outputs, errors, side effects).
  Do NOT describe internals. Do NOT guess intent.
- **Fidelity Report**: Confidence per extraction, uncovered behavior,
  dead code suspects
- **Integration Surface**: APIs, public functions, module exports

### 4. Generate fidelity-report

- Coverage assessment, ambiguity report, gap recommendations
- Spec promotion candidates (requires human review)

### 5. Create shadow specs

```bash
mkdir -p openspec/vendor-specs/<module-name>
```

### 6. Show summary

```
## Reverse Engineering Complete: <module-name>

### Analysis
| Files | Lines | Domains Covered |

### Fidelity
| Extraction | Confidence | Notes |

### Output
openspec/vendor-specs/<module-name>/spec.md

### Recommended
→ Create change to add tests for uncovered error paths
→ Promote high-confidence specs (requires human review)
```

## Guardrails
**Skills**: Check `openspec/skills-profile.yaml` for suggested community
skills under key `mvp-reverse`. Offer to load them — user decides.

- Shadow specs are REFERENCE ONLY — do NOT participate in delta merge
- Report what the code ACTUALLY DOES, not what it should do
- Distinguish observed behavior from inferred intent
- Flag dead code and ambiguous paths explicitly
- Spec promotion requires human review — never auto-promote## Help

When invoked with `help` or `--help`:

```
/mvp:reverse — reverse-engineer specs from undocumented code

Usage:
  /mvp:reverse [path-or-module]

Workflow:
  reverse-engineering → fidelity-report → vendor-specs/<module>/spec.md

Examples:
  /mvp:reverse                          # prompt for paths
  /mvp:reverse src/auth/                # specific source dir
  /mvp:reverse backend/db               # module name
```
