---
name: mvp-organize
description: Execute structural reorganization — merge standalone items into existing structures or create new parent containers. Supports merge and create actions.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
---

Execute structural reorganization based on audit results. Merge standalone
changes into existing slices, standalone slices into existing epics, or
create new containers from clustered items.

---

## Steps

### 1. Scan (or use audit results)

Run the same scan as `/mvp:audit` unless specific target provided.

### 2. Present action items

For each recommendation, show context and ask confirmation:
- HIGH confidence: pre-select Y
- MEDIUM confidence: pre-select N
- LOW confidence: don't offer as action

### 3. Execute merge — change into slice

1. Read target slice's `change-manifest.md`
2. Append change assignment entry with detected scope/repo
3. Update merged change's `proposal.md` parent reference

### 4. Execute merge — slice into epic

1. Read target epic's `epic.md`
2. Append slice entry under correct slice type
3. Update dependency graph
4. Update merged slice's `slice-proposal.md` parent reference

### 5. Execute create — new container

- Change clusters → `/mvp:create-slice` with pre-populated manifest
- Slice clusters → `/mvp:create-epic` with pre-populated slice list

### 6. Execute abandon — mark item as abandoned

When audit detects dormant items or user explicitly requests:

1. Ask for reason: scope-changed / replaced-by / technical-dead-end / other
2. Move item: `mv` to abandoned/ directory (epics/abandoned/ or changes/abandoned/)
3. Update front matter: status → abandoned/deprecated, reason, date, replaced_by, impact
4. Check for orphans — items referencing the abandoned item. Offer to reassign.
5. Report: "✓ Abandoned <item> → .../abandoned/<item>"

### 7. Show completion summary

### 8. Unarchive — restore archived item for modification

1. Move from archive/ → active directory
2. Update front matter status → `active`
3. For archived slices: unarchive the slice AND all child changes together
4. Report: "✓ Unarchived <item>. Fix and re-archive when done."

### 9. Reactivate — restore abandoned item

1. Move from abandoned/ → active directory
2. Update front matter: status → active, clear abandoned fields
3. Audit for reference conflicts
4. Report: "✓ Reactivated <item>. Run /mvp:audit to verify."

### 10. Help

When invoked with `help` or `--help`, output the action summary and examples.

## Guardrails

- Always ask before modifying files
- HIGH → pre-select Y, MEDIUM → pre-select N, LOW → skip
- Append, never overwrite existing structure
- Abandon makes items read-only historical records — reactivate is possible
- Unarchive is for bug fixes — re-archive when done

List all actions taken, remaining standalone items.

## Guardrails
**Skills**: Check `openspec/skills-profile.yaml` for suggested community
skills under key `mvp-organize`. Offer to load them — user decides.

- Always ask before modifying files
- HIGH → pre-select Y, MEDIUM → pre-select N, LOW → skip
- Append, never overwrite existing structure