---
name: mvp-audit
description: Scan project structure for standalone items and propose hierarchical reorganization (merge or create). Read-only structural drift detection.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
---

Scan the project for structural drift — standalone changes, standalone
slices, and missing project foundation. Compute affinity between items
and existing structures, then recommend merge or create actions.

Read-only. Never modifies files.

---

## Steps

### 1. Scan project state

```bash
# List active changes (exclude archive + abandoned)
find openspec/changes/ -maxdepth 1 -mindepth 1 -type d ! -name 'archive' ! -name 'abandoned'

# Also list archived + abandoned — potential merge/reactivate targets
ls openspec/changes/archive/ 2>/dev/null
ls openspec/changes/abandoned/ 2>/dev/null
ls openspec/epics/archive/ 2>/dev/null
ls openspec/epics/abandoned/ 2>/dev/null

# List active epics with front matter status
for epic in openspec/epics/*/; do
  [ "$(basename $epic)" = "abandoned" ] && continue
  [ "$(basename $epic)" = "archive" ] && continue
  head -10 "$epic/epic.md" | grep "status:"
done
```

### 2. Classify each change

Check active + archived change-manifests for ownership.

### 3. Classify each slice + detect orphans

Check active + archived epics for ownership. Check abandoned items for orphan references.

### 4. Compute affinity — active + archived + abandoned

| Target State | If matched | Recommendation |
|-------------|-----------|----------------|
| Active slice | HIGH affinity | merge (standard) |
| Archived slice | HIGH affinity | unarchive + merge |
| Abandoned slice | HIGH affinity | reactivate + merge |
| Active epic | HIGH affinity | merge (standard) |
| Archived epic | HIGH affinity | unarchive epic + merge |
| Abandoned epic | HIGH affinity | reactivate epic + merge |

### 2. Classify each change

For each non-archive change, check if referenced in any slice change-manifest.
If found → owned. If not → standalone.

### 3. Classify each slice

For each vertical-slice change, check if referenced in any epic.md.
If found → owned. If not → standalone slice.

### 4. Compute affinity — merge candidates

**Change → Existing Slice** affinity:
| Signal | Detection | Weight |
|--------|-----------|--------|
| Domain prefix | Same `<domain>-` prefix | STRONG |
| Blast radius | Same `src/<path>/` | STRONG |
| Shared contract | Same API endpoint | MEDIUM |
| Parent context | Same epic/slice slug | STRONG |

**Slice → Existing Epic** affinity:
| Signal | Detection | Weight |
|--------|-----------|--------|
| Affected domains | Same bounded contexts | STRONG |
| Sequential dependency | B depends on A | STRONG |
| Naming family | Same prefix | MEDIUM |

Confidence: HIGH (2+ STRONG) / MEDIUM (1 STRONG) / LOW (only weak)

### 5. Compute affinity — create candidates

Cluster standalone items without existing-structure matches:
- Changes: group by domain prefix + blast radius
- Slices: group by affected domains + naming family
2+ items → CREATE candidate.

### 6. Output structured report

```
## Structure Audit

### Layer 0 — Foundation
✓ or ✗ for each: profile, constitution, architecture

### Layer 1 — Changes
Owned N | Standalone M
Merge candidates (HIGH → MEDIUM): item → target, with affinity signals
Create candidates: cluster → suggested container name
Truly standalone: list

### Layer 2 — Slices
Owned N | Standalone M
(same format)

### Summary table
Next: /mvp:organize
```

## Guardrails
**Skills**: Check `openspec/skills-profile.yaml` for suggested community
skills under key `mvp-audit`. Offer to load them — user decides.

- Read-only — never modify files
- Always check merge BEFORE create
- HIGH → recommend, MEDIUM → suggest, LOW → note only
- Truly standalone items are normal## Help

When invoked with `help` or `--help`:

```
/mvp:audit — scan project structure for standalone items

Usage:
  /mvp:audit [target]

Targets:
  all            Full scan (default) — all layers
  structure      Project foundation only (profile, constitution, architecture)
  changes         Standalone changes → slice merge/create candidates
  slices          Standalone slices → epic merge/create candidates

The audit considers ALL items for merge targets:
  • active — standard merge
  • archived — suggests unarchive + merge (reopen)
  • abandoned — suggests reactivate + merge (revive)

Examples:
  /mvp:audit                        # full scan
  /mvp:audit changes                # only change→slice affinity
  /mvp:audit slices                 # only slice→epic affinity

Next: /mvp:organize to apply recommendations
```
