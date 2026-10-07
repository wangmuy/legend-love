---
name: mvp-apply-slice
description: Apply a vertical-slice change by implementing all its child changes in dependency order. Tracks progress across the change-manifest and updates statuses as child changes are archived.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
---

Apply a vertical-slice change by iterating through its change-manifest
and implementing each child change in order. Tracks progress across
all child changes and updates the manifest.

**When to use this skill:**
- After creating a slice with `/mvp:create-slice`
- Continuing work on a partially completed slice
- Coordinating parallel changes in a vertical slice

---

## Steps

### 1. Select the slice change

If a name is provided, use it. Otherwise:

```bash
openspec list --json
```

Filter for changes with schema `vertical-slice`. If multiple, use the
**AskUserQuestion tool** to let the user select.

If only one, use it. Announce: "Applying slice: <name>"

If none, suggest: "No active vertical-slice changes. Create one first: /mvp:create-slice"

### 2. Read the change-manifest

Read `openspec/changes/<slice-name>/change-manifest.md`. Parse:
- Each change assignment (name, repository, scope, depends-on, status)
- Shared contract stubs (for contract adherence checks)
- Integration test plan (for final verification)

### 3. Show status dashboard

```
## Slice: <slice-name>

| #  | Child Change | Repo   | Depends On | Status    |
|----|-------------|--------|------------|-----------|
| 1  | be-auth-api | backend| —          | 3/5 tasks |
| 2  | fe-login-ui | front  | be-auth-api| Not started |
| 3  | e2e-tests   | qa     | 1,2        | Not started |

**Shared contracts** (all changes must adhere):
- POST /api/v1/auth/login → { token, user }

**Progress**: 1/3 child changes archived | Next: #2 fe-login-ui
```

### 4. Apply child changes in dependency order

Process each child change whose dependencies are met (all "depends-on" changes
are archived or in-progress with contracts satisfied):

For each ready child change:
1. **Create if not exists**:
   ```bash
   openspec new change "<child-name>" --schema spec-driven-enhanced
   ```
   Write minimal `proposal.md` referencing the parent slice.

2. **Run /opsx:apply** on the child change:
   - Implement tasks
   - Respect blast radius from tasks.md
   - Verify against contract stubs

3. **When child change tasks are all done:**
   - Confirm contract adherence (outputs match stubs)
   - Archive the child change
   - Update change-manifest.md: mark child as `[x] Archived`

4. **Move to next ready child change**

### 5. On completion

When all child changes are archived:

```
## Slice Complete: <slice-name>

All child changes archived ✓

### Verification
- [ ] All shared contracts satisfied
- [ ] Integration tests pass (from integration test plan)
- [ ] Slice acceptance criteria met (from slice-proposal)
```

### 6. Pause conditions

Pause the apply loop if:
- A child change has failing dependencies (wait for them to complete)
- Contract stubs are violated (discuss with user — update manifest or fix code)
- User interrupts
- A child change needs scope re-evaluation (suggest `/opsx:explore`)

## Guardrails
**Skills**: Check `openspec/skills-profile.yaml` for suggested community
skills under key `mvp-apply-slice`. Offer to load them — user decides.

- Always process in dependency order (respect "Depends On" column)
- Check each child change for contract adherence before archiving
- Don't start a child change if its dependencies aren't met
- Update change-manifest.md statuses immediately after archiving each child
- The slice is "done" when ALL child changes are Archived — no partial success
- If scope creeps, suggest updating the manifest rather than silently expanding## Help

When invoked with `help` or `--help`:

```
/mvp:apply-slice — implement all child changes from a slice manifest

Usage:
  /mvp:apply-slice [slice-name]

Reads change-manifest.md, applies child changes in dependency order,
archives each when done, completes when all archived.

Examples:
  /mvp:apply-slice                         # select from active slices
  /mvp:apply-slice slice-payment            # specific slice
```
