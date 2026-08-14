# Automation Candidates — Coloring App (Synced to Hi‑Fi UI)

**Document ID:** AUTO-CAND-COLOR-001  
**Version:** 0.2  
**Status:** Review Draft

---

# 1. Stable Selector Contract

Recommended production selectors:

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
settings

paywall
paywall-close
purchase
restore-purchase
```

---

# 2. Automate Now — Maestro

High-value stable UI cases:

- TC-SMOKE-001
- TC-SMOKE-002
- TC-SMOKE-003
- TC-HOME-001
- TC-HOME-002
- TC-HOME-003
- TC-HOME-004
- TC-CAT-001
- TC-CAT-002
- TC-PREVIEW-001
- TC-PREVIEW-002
- TC-PREVIEW-003
- TC-EDITOR-001
- TC-EDITOR-016
- TC-EDITOR-017
- TC-EDITOR-018
- TC-EDITOR-020
- TC-EDITOR-022
- TC-EDITOR-006
- TC-EDITOR-007
- TC-EDITOR-008
- TC-EDITOR-009
- TC-EDITOR-013
- TC-EDITOR-014
- TC-EDITOR-015
- TC-EDITOR-024
- TC-WORK-001
- TC-WORK-002
- TC-WORK-003
- TC-WORK-004
- TC-COMPLETE-001
- TC-MON-001
- TC-MON-002
- TC-SET-001
- TC-SET-002
- TC-SET-003
- TC-SET-004

---

# 3. Partial / Needs Test Hook

- TC-SMOKE-004 — region assertion
- TC-EDITOR-002 — stable fill region
- TC-EDITOR-003 — outline coordinate
- TC-EDITOR-004 — small region
- TC-EDITOR-010 — zoom gesture
- TC-EDITOR-011 — pan
- TC-EDITOR-012 — gesture conflict
- TC-EDITOR-021 — slider value assertion
- TC-EDITOR-023 — viewport state assertion
- TC-SAVE-001 → 006
- TC-COMPLETE-002 → 004
- TC-MON-003 → 009
- TC-OFFLINE-001 → 004

---

# 4. Manual / Visual

- TC-EDITOR-019
- TC-UI-001
- TC-UI-002
- TC-UI-003
- TC-UI-004
- TC-UI-005
- TC-UX-* existing exploratory cases
- long-session feel/performance

---

# 5. Playwright Hi‑Fi Prototype Candidates

The Step 6 Hi‑Fi HTML can now validate:

- Home → Category
- Category → Preview
- Preview → Editor
- Palette selection
- Tool Rail selection
- Basic prototype Fill
- Fit/Zoom button
- Done → Completion
- My Works
- Paywall
- Settings

Prototype automation is valuable before native implementation but does not replace APK testing.

---

# 6. Do Not Automate as Mandatory Product Behavior Yet

Unless Product approves:

- Category filters All/New/Free
- Tool More/Add feature
- exact Daily behavior
- exact Premium trial/price
- unconfirmed secondary mini-tool actions

---

# 7. Step 9 Sync Requirement

Step 9 must:
- regenerate selectors based on this file;
- preserve TC IDs;
- update Maestro YAML;
- update Playwright prototype tests;
- not promote placeholders into required tests.
