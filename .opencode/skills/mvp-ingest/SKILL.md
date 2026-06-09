---
name: mvp-ingest
description: Ingest external/vendor/brownfield documents into BDD shadow specs with gap analysis. Produces vendor-specs and actionable recommendations.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
---

Ingest external documents (Swagger, PDF, Wiki, Postman collections)
into OpenSpec-compatible BDD shadow specs with gap analysis.

---

## Steps

### 1. Gather sources

Use the **AskUserQuestion tool**:

1. What sources do you have? (URLs, file paths, API docs, Swagger specs)
2. What domain or epic does this relate to?
3. Is this a vendor API, legacy system, or external dependency?

### 2. Create the external-ingest change

```bash
openspec new change ingest-<source-name> --schema external-ingest
```

### 3. Generate source-manifest

Record for each source: Source ID ([VNDR-XXX] / [LEGACY-XXX]), Type
(Swagger/PDF/Word/Wiki/Postman), Location, Provider, Version, Relevance.

### 4. Generate spec-extraction

For each source:
- **Extracted Specs**: BDD format with [REQ-VENDOR-XXX] IDs.
  Given/When/Then scenarios. Focus on EXTERNAL BEHAVIOR.
- **Fidelity Assessment**: Confidence (High/Med/Low), assumptions.
- **Integration Contract**: Input/output contracts, error handling, SLA.

Mark ALL extractions as "Shadow Specs — vendor-maintained."
Store in `openspec/vendor-specs/<source-name>/spec.md`.

### 5. Generate gap-analysis

- Compare external specs against existing project specs
- Identify conflicts, gaps, integration risks
- Produce concrete actionable recommendations

### 6. Show summary

```
## Ingestion Complete: <source-name>

### Sources Ingested
| ID | Type | Provider | Confidence |

### Gaps Found
| Issue | Risk | Recommended Action |

### Output
openspec/vendor-specs/<source-name>/spec.md
```

## Guardrails
**Skills**: Check `openspec/skills-profile.yaml` for suggested community
skills under key `mvp-ingest`. Offer to load them — user decides.

- Shadow specs are REFERENCE ONLY — do NOT participate in delta merge
- Always mark extractions with confidence level
- Be explicit about assumptions made during extraction
- Gap analysis MUST produce concrete actionable recommendations## Help

When invoked with `help` or `--help`:

```
/mvp:ingest — ingest external docs into BDD shadow specs

Usage:
  /mvp:ingest [source-name]

Workflow:
  source-manifest → spec-extraction → gap-analysis → vendor-specs/

Examples:
  /mvp:ingest                              # prompt for sources
  /mvp:ingest push-notification-api        # named source
```
