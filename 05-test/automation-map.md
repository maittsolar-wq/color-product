# Automation Map — Coloring App (Synced to Hi‑Fi UI)

**Document ID:** AUTO-MAP-COLOR-001  
**Version:** 0.2  
**Status:** Ready for Implementation / Requires Native Build for Maestro  
**Step:** 9 — Automation Sync

**Synced Against**
- Step 6 Hi‑Fi UI
- Step 7 Synced Functional Spec
- Step 8 Synced Test Strategy / Test Cases

---

# 1. Purpose

Map stable test cases to automation implementation.

Traceability:

`REQ → SCR → CMP → TC → Automation File`

---

# 2. Selector Contract

**Status: Updated — 2026-08-14 re-baseline.** Full contract lives in `selectors-contract.md`; summary below. New IDs added for Library/Profile; legacy IDs preserved for screens no longer routed from the approved MVP core flow.

```text
home-screen
premium-home
home-category-section-<categoryId>
home-see-all-<categoryId>

nav-home
nav-library
nav-profile

library-screen
library-filter-all
library-filter-<categoryId>
library-grid

profile-screen
profile-empty-state
profile-explore-library
profile-segment-all
profile-segment-in-progress
profile-segment-completed
profile-grid
profile-settings-icon

drawing-card-<drawingId>

coloring-canvas
undo
redo
editor-done

tool-brush
tool-fill
tool-erase
tool-more

editor-slider

palette-color-green
palette-color-pink
palette-color-blue
palette-color-purple
palette-color-black

editor-fit

completion-recommended
completion-share
completion-save
completion-back-home

settings
settings-screen

paywall
paywall-close
purchase
restore-purchase
premium-active
```

Legacy (preserved, screen not routed from approved flow):
```text
category-screen
drawing-grid
drawing-preview
start-coloring
continue-coloring
my-works
my-works-screen
in-progress-section
completed-section
```

Important:
- Do not rely on display text when a stable ID can be exposed.
- Dynamic drawing card selector format:
  `drawing-card-<drawingId>`

---

# 3. Maestro Mapping

**Status: Updated — 2026-08-14 re-baseline.** New rows are mapped to planned file paths that do not exist yet (documentation/mapping only in this pass — no automation implementation performed, per re-baseline scope). Legacy rows keep their existing files, marked not routed from the approved MVP core flow.

| Test Case | Automation | Status |
|---|---|---|
| TC-SMOKE-001 → 005 | `maestro/smoke/smoke-main.yaml` | Active |
| TC-HOME-001, 005 | `maestro/discovery/home.yaml` | Active — needs update to drop TC-HOME-002/003/004 legacy steps |
| TC-HOME-006 → 009 | `maestro/discovery/home.yaml` *(planned addition)* | Planned — not yet implemented |
| TC-CAT-001 → 003 | `maestro/discovery/category.yaml` | Legacy — not routed |
| TC-PREVIEW-001 → 003 | `maestro/discovery/preview.yaml` | Legacy — not routed |
| TC-LIB-001 → 005 | `maestro/discovery/library.yaml` *(planned)* | Planned — not yet implemented |
| TC-PROFILE-001 → 006 | `maestro/profile/profile.yaml` *(planned)* | Planned — not yet implemented |
| TC-EDITOR-016 → 018 | `maestro/editor/tool-rail.yaml` | Active |
| TC-EDITOR-020 | `maestro/editor/palette.yaml` | Active |
| TC-EDITOR-006 → 009 | `maestro/editor/undo-redo.yaml` | Active |
| TC-EDITOR-013 → 015 | `maestro/editor/reset.yaml` | Active |
| TC-EDITOR-023 | `maestro/editor/fit-zoom.yaml` | Active |
| TC-EDITOR-024 | `maestro/editor/done.yaml` | Active |
| TC-COMPLETE-005/006 | `maestro/editor/done.yaml` *(planned addition)* | Planned — not yet implemented |
| TC-SAVE-001/002/004 | `maestro/progress/autosave-restore.yaml` | Active |
| TC-WORK-001 → 004 | `maestro/works/my-works.yaml` | Legacy — not routed from bottom nav |
| TC-MON-001/002 | `maestro/monetization/paywall-close.yaml` | Active |
| TC-MON-003 → 005 | `maestro/monetization/purchase-restore-template.yaml` | Active |
| TC-SET-001 → 004 | `maestro/settings/settings.yaml` | Active |

---

# 4. Playwright Mapping

**Status: Updated — 2026-08-14 re-baseline. Prototype code (`prototype.spec.js`) has NOT been modified in this pass — mapping below documents current coverage and flags what will need to change when implementation proceeds.**

Current prototype automation (unchanged, still reflects the legacy flow) covers:

- Home → Category *(legacy path — will break once Home routes artwork taps directly to Editor)*
- Category → Preview *(legacy path)*
- Preview → Editor *(legacy path)*
- Tool rail selection
- Palette selection
- Prototype Fill
- Fit/Zoom
- Done → Completion
- My Works *(legacy — targets `my-works` testid/`SCR-WORKS-001`)*
- Paywall *(`premium-home` → `SCR-PAYWALL-001` — already matches the approved PRO flow, no change needed)*
- Settings *(legacy — targets `settings` testid/`SCR-SETTINGS-001` directly from bottom nav)*

File:
`playwright/tests/prototype.spec.js`

These tests validate the Step 6 Hi‑Fi HTML, not the native APK.

**Planned test additions (not yet implemented):** Home → Library (See all), Home → Editor direct (resume/create), Library filter + artwork tap, Profile segments + empty state + artwork tap, Completion "Recommended for you", Bottom Nav → Library/Profile.

---

# 5. Content Validation

File:
`scripts/validate_content.py`

Validates:
- unique category IDs
- unique drawing IDs
- valid category references
- thumbnail field
- coloring asset field
- premium boolean

Maps to:
- TC-CONTENT-001 → TC-CONTENT-007

---

# 6. Partial / Test Hook Required

The following remain partial until the native app exposes suitable test hooks/state:

- TC-SMOKE-004
- TC-EDITOR-002
- TC-EDITOR-003
- TC-EDITOR-004
- TC-EDITOR-010
- TC-EDITOR-011
- TC-EDITOR-012
- TC-EDITOR-021
- TC-EDITOR-023
- TC-SAVE-003
- TC-SAVE-005
- TC-SAVE-006
- TC-COMPLETE-002 → 004
- TC-MON-003 → 009
- TC-OFFLINE-001 → 004

Recommended optional debug/test IDs:

```text
region-state-<regionId>-<colorKey>
editor-save-state
editor-zoom-state
editor-tool-state
editor-active-color
```

These should exist only in debug/testable builds if production accessibility semantics are insufficient.

---

# 7. Non-Mandatory Placeholder Controls

Do not make these release-blocking automation targets until Product approves them:

- Category filters: All/New/Free
- Tool More/Add
- Daily exact behavior
- Prototype trial/price strings
- secondary mini-tool icons

---

# 8. Step 9 Definition of Complete

Step 9 is complete when:
- automation map is synchronized;
- Maestro flows use current selectors;
- Playwright covers Hi‑Fi prototype;
- content validator is available;
- unresolved provider/build dependencies are explicit.

Actual native automation execution requires:
- real appId;
- installable build;
- stable native test IDs.

**2026-08-14 addendum:** This re-baseline updated the selector contract and mapping tables to cover Library/Profile/Home-direct-navigation/Completion. It did **not** implement any new Maestro YAML, Playwright spec, or prototype code changes — those remain planned/flagged above, consistent with the re-baseline's documentation-only scope.
