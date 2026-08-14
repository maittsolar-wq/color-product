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

Native app should expose stable accessibility/test IDs:

```text
home-screen
premium-home
continue-coloring

category-screen
drawing-grid
drawing-card-<drawingId>

drawing-preview
start-coloring
continue-coloring

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

my-works
my-works-screen
in-progress-section
completed-section

settings
settings-screen

paywall
paywall-close
purchase
restore-purchase
premium-active
```

Important:
- Do not rely on display text when a stable ID can be exposed.
- Dynamic drawing card selector format:
  `drawing-card-<drawingId>`

---

# 3. Maestro Mapping

| Test Case | Automation |
|---|---|
| TC-SMOKE-001 → 005 | `maestro/smoke/smoke-main.yaml` |
| TC-HOME-001 → 004 | `maestro/discovery/home.yaml` |
| TC-CAT-001 → 003 | `maestro/discovery/category.yaml` |
| TC-PREVIEW-001 → 003 | `maestro/discovery/preview.yaml` |
| TC-EDITOR-016 → 018 | `maestro/editor/tool-rail.yaml` |
| TC-EDITOR-020 | `maestro/editor/palette.yaml` |
| TC-EDITOR-006 → 009 | `maestro/editor/undo-redo.yaml` |
| TC-EDITOR-013 → 015 | `maestro/editor/reset.yaml` |
| TC-EDITOR-023 | `maestro/editor/fit-zoom.yaml` |
| TC-EDITOR-024 | `maestro/editor/done.yaml` |
| TC-SAVE-001/002/004 | `maestro/progress/autosave-restore.yaml` |
| TC-WORK-001 → 004 | `maestro/works/my-works.yaml` |
| TC-MON-001/002 | `maestro/monetization/paywall-close.yaml` |
| TC-MON-003 → 005 | `maestro/monetization/purchase-restore-template.yaml` |
| TC-SET-001 → 004 | `maestro/settings/settings.yaml` |

---

# 4. Playwright Mapping

Prototype automation covers:

- Home → Category
- Category → Preview
- Preview → Editor
- Tool rail selection
- Palette selection
- Prototype Fill
- Fit/Zoom
- Done → Completion
- My Works
- Paywall
- Settings

File:
`playwright/tests/prototype.spec.js`

These tests validate the Step 6 Hi‑Fi HTML, not the native APK.

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
