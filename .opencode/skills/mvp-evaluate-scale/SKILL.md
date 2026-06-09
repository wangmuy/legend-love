---
name: mvp-evaluate-scale
description: Assess the project's current scale (Sketch/Blueprint/Modular/Ecosystem) and recommend schema setup. Use when onboarding a new project, re-evaluating mid-project, or debugging scale-related issues.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
---

Assess the project's current scale and recommend schema configuration.

**When to use this skill:**
- **New project onboarding** — "What scale should I use for my project?"
- **Mid-project re-evaluation** — "This feels bigger than when we started. Re-assess?"
- **Scale diagnosis** — "Are we using the right scale? Should we upgrade or downgrade?"
- **Post-mortem** — "Now that we've shipped, was the scale choice right?"

This is the primary entry point for the mvp-schemas system. It handles
both greenfield (first use) and brownfield (existing project) scenarios.

---

## Greenfield Detection

Before running the standard assessment, check if the project is being
used for the first time:

```bash
ls openspec/project/profile.md 2>/dev/null && HAS_PROFILE=true || HAS_PROFILE=false
```

If `HAS_PROFILE=false`, this is likely a new project. Proceed differently:

### Scenario A: No profile + no active changes (greenfield — first use)

```
I notice this is a fresh project. Let's figure out what you're building.
```

**Also check for project instructions:**

```bash
ls AGENTS.md CLAUDE.md 2>/dev/null && HAS_INSTRUCTIONS=true || HAS_INSTRUCTIONS=false
```

Explore freely. Listen for signals about the project identity, domains,
tech stack, scale indicators.

**Check skills**: Check `openspec/skills-profile.yaml` for suggested
skills under the `exploration` key. Offer to load any that exist —
skills are SUGGESTIONS only, user decides.

When things crystallize, offer:

```
Based on what we discussed, this looks like a <Sketch/Blueprint/Modular/
Ecosystem> project. Want me to bootstrap the project?

  → Create project-profile (profile.md, constitution.md, standards.md,
    architecture.md from our conversation)

<if HAS_INSTRUCTIONS=false:>
  → Create AGENTS.md/CLAUDE.md — project instructions for AI agents
    (use /init in OpenCode, or I'll create CLAUDE.md directly)

<end if>
  → Run a structured assessment if you want more precision

  → Keep exploring
```

Then, based on the scale assessment, recommend the next command:

| Scale/State    | Next Command           |
|----------------|------------------------|
| No profile     | `/mvp:init-profile`    |
| New initiative | `/mvp:create-epic`     |
| Single MVP     | `/mvp:create-slice`    |
| Simple fix     | `/opsx:propose`        |
| External docs  | `/mvp:ingest`          |
| Undocumented code | `/mvp:reverse`      |
| Scale mismatch | `/mvp:upgrade`         |

UX rule: If the user wants to create AGENTS.md, prefer the tool-native
approach: `/init` in OpenCode. If CLI is unavailable, create
`CLAUDE.md` manually with project conventions derived from the
conversation. The generated file MUST include a section describing
the MVP Multi-Scale SDD schema system (key commands: /mvp:evaluate-scale,
/opsx:explore, /opsx:propose, /opsx:apply, /opsx:archive; reference:
openspec/WORKFLOW.md).

### Scenario B: No profile + has active changes (brownfield — code exists)

Project has work in flight but was never bootstrapped.

```
This project has active work but no project-profile yet. I can bootstrap
one by scanning your existing specs and code.
```

**Also check for project instructions:**

```bash
ls AGENTS.md CLAUDE.md 2>/dev/null && HAS_INSTRUCTIONS=true || HAS_INSTRUCTIONS=false
```

When things crystallize, offer:

```
I can bootstrap your project setup:

  → Create project-profile (auto-derived from existing specs/code)

<if HAS_INSTRUCTIONS=false:>
  → Create AGENTS.md/CLAUDE.md — project instructions for AI agents
    (use /init in OpenCode, or I'll create CLAUDE.md directly)

<end if>
  → Run a scale assessment first

  → Keep exploring
```

### Scenario C: Profile exists

In addition to the standard scale assessment, check for staleness:

```bash
# Profile freshness — now in front matter
head -10 openspec/project/profile.md | grep "last_auto_derived" 2>/dev/null

# Vendor-spec freshness
find openspec/vendor-specs -name "*.md" -mtime +60 2>/dev/null

# Abandoned items
ls openspec/epics/abandoned/ 2>/dev/null
ls openspec/changes/abandoned/ 2>/dev/null
```

Include in the assessment report:

```
### Staleness Check
| Artifact | Status |
|----------|--------|
| profile.md | ✓ fresh / ⚠ stale |
| vendor-specs | ✓ fresh / ⚠ stale |
| abandoned items | N (if >0: "Use /mvp:audit or /mvp:organize") |
```

Proceed to the standard 4-step scale assessment below.

---

## How It Works

The assessment combines **auto-detected signals** (filesystem scan) with **manual signals**
(user interview) to determine the project's scale. Scale is about **coordination
complexity**, not lines of code or team size.

```
              ┌──────────────────────────┐
              │  /mvp:evaluate-scale     │
              └───────────┬──────────────┘
                          │
              ┌───────────▼──────────────┐
              │  Step 1: Auto-Detect     │
              │  Scan project filesystem  │
              └───────────┬──────────────┘
                          │
              ┌───────────▼──────────────┐
              │  Step 2: Ask User         │
              │  Interview for unknowns   │
              └───────────┬──────────────┘
                          │
              ┌───────────▼──────────────┐
              │  Step 3: Apply Tree       │
              │  Map signals → scale      │
              └───────────┬──────────────┘
                          │
              ┌───────────▼──────────────┐
              │  Step 4: Output           │
              │  Recommendation + actions │
              └──────────────────────────┘
```

---

## Step 1: Auto-Detect Project Signals

### 1.1 Scan `openspec/` Structure

```bash
ls openspec/project/ 2>/dev/null && echo "project-profile: present" || echo "project-profile: absent"
ls openspec/epics/ 2>/dev/null && echo "epics dir: present" || echo "epics dir: absent"
ls openspec/vendor-specs/ 2>/dev/null && echo "vendor-specs dir: present" || echo "vendor-specs dir: absent"
ls openspec/schemas/ 2>/dev/null
```

Detect: `has_project_profile`, `has_epics`, `has_vendor_specs`, `custom_schemas`

### 1.2 Count Active Changes

```bash
find openspec/changes/ -maxdepth 1 -mindepth 1 -type d ! -name 'archive' | wc -l
```

Derive: `active_changes_count`

### 1.3 Count Active Epics

```bash
find openspec/epics/ -maxdepth 1 -mindepth 1 -type d | wc -l
```

Derive: `active_epics_count`

### 1.4 Detect Repository Count

```bash
ls .gitmodules 2>/dev/null && echo "polyrepo (git submodules found)"
find . -maxdepth 1 \( -name 'go.mod' -o -name 'Cargo.toml' -o -name 'package.json' -o -name 'setup.py' -o -name 'pom.xml' -o -name 'build.gradle' \) 2>/dev/null
```

Derive: `repo_count` (1 = monorepo, 2+ = polyrepo), `root_module_count`

### 1.5 Estimate Bounded Contexts

```bash
find . -maxdepth 2 -mindepth 2 -type d \( -name 'src' -o -name 'lib' -o -name 'pkg' -o -name 'app' -o -name 'services' -o -name 'internal' \) 2>/dev/null | head -20
ls -d src/*/ 2>/dev/null | wc -l
ls -d pkg/*/ 2>/dev/null | wc -l
ls -d internal/*/ 2>/dev/null | wc -l
ls -d services/*/ 2>/dev/null | wc -l
```

Derive: `bounded_context_estimate`

### 1.6 Detect External API Definitions

```bash
find . -name '*.yaml' -o -name '*.yml' -o -name '*.json' 2>/dev/null | xargs grep -l 'openapi:\|swagger:\|paths:' 2>/dev/null | head -10
```

Derive: `external_api_spec_count`

### 1.7 Read Current Config

```bash
cat openspec/config.yaml 2>/dev/null
```

Derive: `current_schema`, `current_scale_intent`

### 1.8 Check Undocumented Code Ratio

```bash
spec_count=$(find openspec/specs/ -name '*.md' 2>/dev/null | wc -l)
```

Derive: `undocumented_ratio` (low/medium/high — heuristic based on spec-to-source ratio)

### Auto-Detect Summary Table

Present to the user:

```
## Auto-Detected Signals

| Signal                      | Value                        |
|-----------------------------|------------------------------|
| project-profile exists      | ✓ / ✗                        |
| active epics                | N                            |
| active changes              | N                            |
| repository count            | 1 (monorepo) / N (polyrepo)  |
| bounded contexts (approx)   | N                            |
| external API specs          | N                            |
| vendor-specs dir            | ✓ / ✗                        |
| undocumented code ratio     | low / medium / high          |
| current config schema       | spec-driven / enhanced       |
```

---

## Step 2: Interview User for Manual Signals

Use the AskUserQuestion tool. Ask ALL questions in a single multi-part question.

1. **How many human contributors?** (1 / 2-3 / 4-8 / 8+)
2. **How many AI agents or work streams?** (1 / 2-3 / 4+)
3. **External systems or vendors?** (none / 1-2 / 3+)
   If yes, are their docs (Swagger, PDFs, APIs) available?
4. **Single team or cross-team?** (single / multiple)
5. **Current scale setup feel?** (works fine / too heavy / too light / unsure)

---

## Step 3: Apply Decision Tree

### Primary Signal: Work Stream Count

```
work_streams = max(active_changes_count, active_epics_count + active_changes_count,
                   human_contributors + ai_agents_in_use)
```

| Work Streams | Scale Candidate |
|--------------|-----------------|
| 1-2          | Sketch          |
| 2-5          | Blueprint       |
| 5-12         | Modular         |
| 12+          | Ecosystem       |

### Modifier Signals (adjust up/down on the scale ladder)

| Condition | Adjustment |
|-----------|------------|
| polyrepo (>= 2 repos) | +1 |
| external vendors >= 3 | +1 |
| multi-team | +1 |
| bounded contexts > 8 | +1 |
| high undocumented ratio | +1 |
| external API specs > 3 | +1 |
| has project-profile | -1 |
| single team AND monorepo | -1 |
| solo dev + 1 AI agent | -1 |

### Final Recommendation

```
Raw work_stream signal:        N → <candidate scale>
Modifier adjustments:          +N / -N
Modified scale:                <final scale>

Decision table lookup:
  Sketch     → schemas: spec-driven (stock)
                structure: openspec/changes/ only
                
  Blueprint  → schemas: project-profile + spec-driven-enhanced
                structure: + openspec/project/ + spec-driven-enhanced fork
                
  Modular    → schemas: + epic + vertical-slice
                structure: + openspec/epics/ + domain-map
                
  Ecosystem  → schemas: + external-ingest + code-to-spec
                structure: + openspec/vendor-specs/
```

---

## Step 4: Output Structured Recommendation

Present in canonical format:

```
## Scale Assessment

**Current setup**: <what exists in openspec/ today>
**Detected scale**: <Sketch / Blueprint / Modular / Ecosystem>
**Confidence**: <High / Medium / Low>

### Signal Summary

| Signal                    | Value    | Weight |
|---------------------------|----------|--------|
| Work streams (detected)   | N        | primary|
| Repository count          | N        | +N/-N  |
| Bounded contexts          | N        | +N/-N  |
| External vendors          | N        | +N/-N  |
| Teams                     | single/multi | +N/-N |
| Undocumented code         | low/med/high | +N/-N |

### Schema Recommendation

| Schema               | Status        |
|----------------------|---------------|
| project-profile      | ✓ installed / ✗ missing |
| epic                 | ✓ installed / ✗ missing |
| vertical-slice       | ✓ installed / ✗ missing |
| spec-driven-enhanced | ✓ installed / ✗ missing |
| external-ingest      | ✓ installed / ✗ missing |
| code-to-spec         | ✓ installed / ✗ missing |
| project-upgrade      | ✓ installed / ✗ missing |

### Next Actions

<If current scale matches config and all schemas installed:>
  ✓ Your project is properly configured for <scale> scale.

<If mismatch or missing:>
  **Detected <detected> but configured for <current>.**
  → `/opsx:explore` to discuss the recommendation
  → `openspec new change upgrade-<from>-to-<to> --schema project-upgrade`
  → Or manually add missing schemas + update config.yaml

<If signals conflict:>
  **Signals mixed.** Confidence Low.
  → Start with lighter setup, upgrade when needed
  → Run `/opsx:explore` to discuss
  → Try Blueprint as safe default
```

### UX Rule

After presenting recommendation, last option must be:
"Other — discuss further or override the recommendation"

---

## Guardrails

- **Read-only** — Never create, edit, or delete files.
- **Always ask user interview** — Auto-detection alone is insufficient.
- **Recommendation is advisory** — User may override or defer.
- **Don't default to Ecosystem** — Only if clear polyrepo + multi-vendor + multi-team.
- **Don't confuse code size with scale** — Large CRUD app with one stream is still Sketch/Blueprint.
- **Explain the "why"** — Always show signal → scale mapping.
- **Suggest `/opsx:explore` as follow-up** — If user wants to discuss before acting.
- **Handle "this feels wrong"** — If user disagrees, discuss signals and adjust.## Help

When invoked with `help` or `--help`:

```
/mvp:evaluate-scale — assess project scale + bootstrap

Usage:
  /mvp:evaluate-scale

Scenarios (auto-detected):
  Greenfield:  No profile + no changes → explore → offer to bootstrap profile + AGENTS.md
  Brownfield:  No profile + has changes → scan code → offer to bootstrap
  Bootstrapped: Profile exists → full scale assessment + staleness check

The assessment checks: work stream count, repo count, bounded contexts,
external vendors, dormant epics, stale profile, abandoned items.

Examples:
  /mvp:evaluate-scale
```
