---
# Profile front matter. last_auto_derived is updated on each refresh.
last_auto_derived: "<date>"
---
# Project Profile

<!-- Run `/opsx:verify project-profile` to refresh.
     
     Canonical reference: openspec/WORKFLOW.md
     (zoom model, bootstrap guide, walkthrough, upgrade paths)
     
     ## Fan-Out Convention
     
     If this file exceeds ~500 lines, split into sub-documents:
     
     openspec/project/profile/
     ├── _index.md        # This file — summary + links to sub-docs
     ├── identity.md      # One-liner, tech stack, license, repo links
     ├── status.md        # Auto-derived dashboard (FULLY REPLACED on refresh)
     └── quickstart.md    # Getting started guide (PRESERVED across refreshes)
     
     Rules:
     - _index.md is ALWAYS the entry point — AI agents read this first
     - Auto-refresh replaces auto-derived sub-docs in-place (e.g., status.md)
     - User-authored sub-docs are preserved across refreshes (e.g., quickstart.md)
     - Fan-out threshold: ~500 lines per file
     - After fan-out, the original file is replaced by the directory
     -->

## Fan-Out Guide

<!-- If this document grows beyond ~500 lines, split into sub-documents:

     1. Create openspec/project/profile/ directory
     2. Move this content into:
        profile/_index.md       — Summary + links to sub-docs (ENTRY POINT)
        profile/identity.md     — One-liner, tech stack, repo links (PRESERVED)
        profile/status.md       — Auto-derived dashboard (FULLY REPLACED on refresh)
        profile/quickstart.md   — Getting started guide (PRESERVED)
     3. Auto-refresh behavior:
        - status.md is fully replaced on each refresh (auto-derived content)
        - identity.md and quickstart.md are PRESERVED (user-authored content)
        - _index.md is updated to reflect new sub-doc links
     4. _index.md is always the entry point — AI agents read this first
     5. The original profile.md file is replaced by the profile/ directory
 -->

## Identity

<!-- One-sentence description of what this project is.
     Examples: "A simplified WeChat clone for learning distributed systems."
     "An open-source World of Warcraft server implementation." -->

**Tech Stack**: <!-- Languages, frameworks, databases, infrastructure -->

**Repository**: <!-- Link(s) -->

**License**: <!-- SPDX identifier -->

## Current Status

### Implemented Capabilities

<!-- Auto-derived from openspec/specs/. Each spec folder = a capability. -->

| Capability | Spec | Description |
|-----------|------|-------------|
| <!-- name --> | <!-- specs/<name>/spec.md --> | <!-- brief description --> |

### Active Epics

<!-- Auto-derived from openspec/epics/ (excluding abandoned/). -->

| Epic | Created | Slices (done/total) | Status |
|------|---------|---------------------|--------|
| <!-- name --> | <!-- YYYY-MM --> | <!-- N/M --> | <!-- in-progress/dormant/completed --> |

### In-Progress Changes

<!-- Auto-derived from openspec/changes/ (non-archive, non-abandoned). -->

| Change | Schema | Artifacts | Tasks |
|--------|--------|-----------|-------|
| <!-- name --> | <!-- schema --> | <!-- done/total --> | <!-- done/total --> |

## Quick Start

<!-- Minimal steps to get the project running locally. -->

## Notes

<!-- User notes preserved across auto-refreshes. -->