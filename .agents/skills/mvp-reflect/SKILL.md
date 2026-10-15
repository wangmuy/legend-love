---
name: mvp-reflect
description: Post-completion reflection — look at what just finished and recommend the most impactful next action. Reactive-only, invoked after change/slice/epic completion.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
---

**IMPORTANT: This skill is reactive-only.** It is meant to be invoked
AFTER something completes — never proactively. It is not a standalone
workflow that users type directly.

Triggered by:
- `/opsx:archive` completing a change
- `/mvp:apply-slice` completing all child changes
- An epic's last slice reaching done

The AI or parent command invokes it via the Skill tool:
`Skill: mvp-reflect`

---

## Steps

### 1. Detect what just completed

Read the conversation context. What was just archived or finished?
- A single change (spec-driven)
- A vertical slice (all child changes archived)
- An epic (all slices done)

### 2. Check sibling progress

If a **change** was just archived, check if it belongs to a slice:

```bash
# Find which slice's change-manifest contains this change
grep -rl "<change-name>" openspec/changes/*/change-manifest.md 2>/dev/null
```

If found, read the change-manifest and count: total children / done (archived) / remaining.

```
Slice "payment-integration": 2/3 children done.
Next: fe-pay-checkout (depends on: none)
```

If this was the LAST child → slice is now complete. Move to step 4.

If the change was standalone (no parent slice) → go to step 5.

### 3. If a slice just completed (last child done)

Check if the slice belongs to an epic:

```bash
head -10 openspec/changes/<slice>/slice-proposal.md | grep "parent_epic"
```

If it has a parent epic, check that epic's status — are other slices still pending?

```
Epic "2025-05-chat": 2/3 slices done.
Next: slice-online-status (depends on: slice-send-receive)
```

If this was the LAST slice in the epic → epic is complete.

### 4. If an epic just completed (all slices done)

```
## Reflection

✓ Epic "2025-05-chat" complete — all 3 slices archived.

Recommended:
  → /mvp:organize — archive the epic (move to epics/archive/)
  → /mvp:audit — check for new standalone items accumulated during this epic
  → /mvp:evaluate-scale — reassess: has the project scale changed?
```

### 5. If it was a standalone change (no parent)

```
## Reflection

✓ Change "be-hotfix-timeout" archived (standalone).

Project state:
  • Active changes: 3 (2 standalone, 1 in slice)
  • Standalone items: accumulating

Recommended:
  → /mvp:audit — 2 standalone changes might form a slice
  → Check project/TODO.md — any ideas to promote?
```

### 6. If nothing active remains

```
## Reflection

No active changes, slices, or epics.

Check:
  → openspec/project/TODO.md — 3 items waiting (triage?)
  → /mvp:evaluate-scale — reassess project scale and direction
  → /mvp:audit — verify project structure is clean
```

### 7. Always check for TODO items

```bash
cat openspec/project/TODO.md 2>/dev/null
```

If items exist, surface: "project/TODO.md has N items. Promote to a change, slice, or dismiss?"

## Output format

Always structured:
```
## Reflection

**Completed**: <item> → <status>

**Context**: <parent/sibling info>

**Recommendation**: <single most impactful next action>
  → /<command> <args>

**Alternatively**: <other options>
```

## Guardrails

- Read-only — never modify files
- Recommend ONE primary action, not a list of all possibilities
- If there's a clear next step (continue sibling), prioritize that over broader checks
- Don't recommend audit/organize if there are no structural issues to fix
- If unsure, suggest `/mvp:evaluate-scale` as safe default