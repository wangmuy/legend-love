## Front Matter Convention

Artifacts use YAML front matter for machine-readable status fields.
Read status O(1) with `head -10 <file>` without parsing the full document.

| Artifact | Front Matter Fields |
|----------|-------------------|
| `epic.md` | `status`, `created`, `abandoned: { reason, date, replaced_by, impact }` |
| `slice-proposal.md` | `status`, `parent_epic`, `abandoned: { reason, date, replaced_by }` |
| `change-manifest.md` | `parent_epic` |
| `profile.md` | `last_auto_derived` |

## Abandoned / Deprecated Lifecycle

Items no longer active but not completed move to `abandoned/` directories,
symmetrical to `archive/`:

```
openspec/epics/
├── <active-epic>/         # active | dormant
├── archive/               # done (all slices archived)
└── abandoned/             # abandoned | deprecated

openspec/changes/
├── <active-change>/       # active
├── archive/               # done
└── abandoned/             # abandoned | withdrawn
```

Status values in front matter:
- `active` — currently in progress
- `dormant` — no activity > 60 days
- `done` — completed (moved to archive/)
- `abandoned` — formally closed, not completed
- `deprecated` — replaced by another item

Commands handle lifecycle transitions:
| Command | Behavior |
|---------|----------|
| `/mvp:evaluate-scale` | Detects abandoned + dormant items in staleness check |
| `/mvp:audit` | Scans abandoned/ + archive/, detects orphan references |
| `/mvp:organize` | All lifecycle actions: merge, create, abandon, unarchive, reactivate |