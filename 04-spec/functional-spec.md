# Functional Specification — Coloring App (Synced to Step 6 Hi‑Fi)

**Document ID:** FS-COLOR-001  
**Version:** 0.2  
**Status:** Review Draft  
**Step:** 7 — Functional / Data / API Specification Sync  

**Synced Against**
- `ui-spec.md` v1.0
- `design-system.md` v1.0
- `design-decisions.md` v1.0
- Hi‑Fi HTML prototype

---

# 1. Purpose

This version replaces the previous Step 7 functional specification as the current functional source of truth.

It aligns system behavior with the approved/current Hi‑Fi UI structure while preserving all Step 1–5 requirements.

Traceability:

`REQ → SCR → CMP → Functional Behavior → Test`

---

# 2. Functional Scope

MVP domains remain:

- App Entry
- Home & Discovery
- Category
- Drawing Preview
- Coloring Editor
- Progress / Autosave / Restore
- Completion
- My Works
- Monetization (conditional)
- Settings
- Local/offline content

No new MVP feature was introduced by the Hi‑Fi design.

---

# 3. UI Contract Rules

## FS-UI-001 — Stable Screen IDs

The native implementation must preserve equivalent identifiers for:

- `SCR-HOME-001`
- `SCR-CATEGORY-001`
- `SCR-PREVIEW-001`
- `SCR-EDITOR-001`
- `SCR-COMPLETE-001`
- `SCR-WORKS-001`
- `SCR-PAYWALL-001`
- `SCR-SETTINGS-001`

## FS-UI-002 — Stable Testability IDs

Interactive production UI should expose stable accessibility/test identifiers matching the design where practical.

Examples:

- `premium-home`
- `continue-coloring`
- `drawing-grid`
- `drawing-card-<drawingId>`
- `start-coloring`
- `coloring-canvas`
- `undo`
- `redo`
- `purchase`
- `my-works`
- `settings`

These are contracts for QA automation and should not depend on display text.

---

# 4. Home Functional Specification

## FS-HOME-001 — Home Assembly

**Screen:** SCR-HOME-001  
**Requirements:** REQ-HOME-001 → REQ-HOME-006  

Hi‑Fi Home contains:

1. App header
2. Premium CTA (conditional)
3. Continue Coloring (conditional)
4. Featured
5. Categories
6. Daily Pick (conditional)
7. Bottom navigation

### Continue Coloring

Component:
`CMP-HOME-CONTINUE`

Visibility:
- show when at least one valid In Progress record exists.

Default item:
- latest updated In Progress drawing.

Tap:
- opens `SCR-EDITOR-001` directly in V1 assumption.

### Featured

Must resolve valid Drawing entities.

Invalid content:
- hide invalid card or render safe fallback.
- Home must remain usable.

### Categories

Tap category:
`SCR-HOME-001 → SCR-CATEGORY-001`

---

# 5. Category Functional Specification

## FS-CAT-001 — Drawing Grid

**Screen:** SCR-CATEGORY-001  
**Component:** CMP-CAT-GRID  

Input:
- `categoryId`

Output:
- active drawings in category.

Card state priority:
1. Premium/Locked
2. Completed
3. In Progress
4. Default

### Filter Chips

Hi‑Fi V1 visually includes:
- All
- New
- Free

**Important:** Filters are visual prototype assumptions until Product explicitly confirms them.

If not confirmed:
- Dev may omit them from MVP.
- They must not be treated as a new requirement automatically.

---

# 6. Preview Functional Specification

## FS-PREVIEW-001 — Preview Resolution

**Screen:** SCR-PREVIEW-001

Load:
- artwork
- metadata
- state
- access
- progress

## FS-PREVIEW-002 — CTA Resolution

Component:
`CMP-PREVIEW-START`

Rule:

```text
Locked     → Unlock / Paywall
InProgress → Continue Coloring
Completed  → View / Color Again
Default    → Start Coloring
```

V1 keeps Preview as a dedicated screen.

If later removed, Step 4/5 must be updated first.

---

# 7. Coloring Editor — Hi‑Fi Functional Contract

**Screen:** SCR-EDITOR-001

Editor is the highest-risk functional area.

---

## 7.1 Editor UI Regions

### A. `CMP-EDITOR-TOPBAR`

Contains:
- Back
- Undo
- Redo
- Secondary tool shortcuts
- Done

### B. `CMP-EDITOR-CANVAS`

Contains:
- neutral workspace
- white artboard
- line-art
- fillable regions

### C. `CMP-EDITOR-TOOL-RAIL`

Contains:
- Brush
- Fill
- Erase
- Add/More

### D. `CMP-EDITOR-SLIDER`

Contextual control.

### E. `CMP-EDITOR-PALETTE`

Color selection.

### F. `CMP-EDITOR-QUICK-ACTIONS`

Quick utility actions including fit/zoom.

---

# 8. Editor Session State

Minimum runtime session:

```text
drawingId
progressId
activeTool
activeColor
toolParameterValue
undoStack
redoStack
zoomScale
panOffset
dirty
saveState
```

### Persistence rule

Required persistent:
- region colors
- brush strokes
- completion state
- content/schema version

Not required to persist in MVP:
- active tool
- active color
- slider value
- zoom scale
- pan position

These may reset when Editor reopens.

---

# 9. Tool Selection

## FS-EDITOR-TOOL-001 — Brush

If Brush remains in approved MVP:

Selecting Brush:
- sets `activeTool = BRUSH`
- updates selected tool visual state
- slider maps to brush size or other defined parameter

## FS-EDITOR-TOOL-002 — Fill

Selecting Fill:
- sets `activeTool = FILL`
- tap on valid region performs region fill

## FS-EDITOR-TOOL-003 — Erase

Selecting Erase:
- sets `activeTool = ERASE`

For MVP:
- erases brush/free-drawing content

Region clearing behavior requires explicit product rule if added.

## FS-EDITOR-TOOL-004 — Add / More

The Hi‑Fi reference includes Add/More.

**Status:** UI placeholder / future extension.

It must not create undocumented MVP behavior.

---

# 10. Palette

## FS-EDITOR-COLOR-001 — Select Color

**Requirement:** REQ-EDITOR-002  
**Component:** CMP-EDITOR-PALETTE  

Tap swatch:
1. update `activeColor`
2. update selected state
3. do not alter artwork until an editing action occurs

Palette can be horizontally scrollable if colors exceed available width.

---

# 11. Context Slider

## FS-EDITOR-SLIDER-001

**Component:** CMP-EDITOR-SLIDER

Slider meaning depends on selected tool.

Recommended MVP mapping:

```text
Brush → Brush Size
Fill  → No required functional effect / may hide or disable
Erase → Eraser Size
```

Hi‑Fi prototype displays the slider continuously for visual fidelity.

Native implementation may contextualize it as long as design hierarchy remains consistent.

---

# 12. Tap-to-Fill

## FS-EDITOR-FILL-001

**Requirement:** REQ-EDITOR-003  

When activeTool = FILL:

1. Convert touch coordinate to art coordinate.
2. Distinguish tap from pan/gesture.
3. Resolve target region.
4. If valid:
   - apply activeColor
   - append undo action
   - clear redo
   - set dirty
   - schedule autosave
5. If invalid/outline:
   - no color-state change

Neighboring regions must not be modified.

---

# 13. Brush

## FS-EDITOR-BRUSH-001

If Brush is included:

On pointer down:
- begin stroke.

During move:
- collect path points.

On pointer up:
- finalize stroke.
- push undo action.
- clear redo.
- schedule autosave.

Stroke stores:
- ID
- tool
- color
- size
- points

---

# 14. Undo / Redo

## FS-EDITOR-HISTORY-001 — Undo

**Test ID:** undo

If stack exists:
- revert last action
- push to redo
- dirty = true
- autosave

Else:
- no-op
- disabled visual state

## FS-EDITOR-HISTORY-002 — Redo

**Test ID:** redo

If redo exists:
- restore action
- push to undo
- dirty
- autosave

A new edit after Undo clears Redo history.

---

# 15. Zoom / Pan

## FS-EDITOR-VIEW-001 — Zoom

Fit/zoom quick action may change viewport only.

Zoom state is not required to persist.

## FS-EDITOR-VIEW-002 — Pan

Pan:
- must be distinguished from tap-to-fill.
- should operate on zoomed artboard/workspace.

The tool rail must not intercept canvas gestures outside its bounds.

---

# 16. Back / Autosave

## FS-SAVE-001 — Back from Editor

On Back:
1. flush pending autosave
2. preserve last valid progress
3. return to Preview or previous context

No confirmation required for normal back because autosave is the product principle.

## FS-SAVE-002 — Background

On app background:
- force/attempt save flush.

## FS-SAVE-003 — Save Status

States:
- DIRTY
- SAVING
- SAVED
- ERROR

The Hi‑Fi prototype uses a small Saved indicator.

Native UI may keep this subtle.

---

# 17. Done / Completion

## FS-COMPLETE-001

Tap Done:
1. save current state
2. mark progress COMPLETED
3. set completedAt
4. open `SCR-COMPLETE-001`

Completion actions:
- Save Image
- Share
- My Works
- Home

---

# 18. My Works

## FS-WORK-001

**Screen:** SCR-WORKS-001

Tabs/segments:
- In Progress
- Completed

Data source:
Progress records.

Recommended sort:
`updatedAt DESC`

Tap In Progress:
- direct to Editor.

Tap Completed:
- Preview/Result based on final product decision.

---

# 19. Paywall

## FS-MON-001

**Screen:** SCR-PAYWALL-001

Hi‑Fi V1 includes:
- close
- premium value statement
- premium artwork benefit
- no ads benefit
- extra tools benefit
- offer
- purchase CTA
- restore
- legal

**Important:** Exact price/trial text is placeholder until monetization is confirmed.

No hardcoded placeholder pricing should ship.

---

# 20. Settings

## FS-SET-001

**Screen:** SCR-SETTINGS-001

V1 contains:
- Premium/manage
- Sound
- Haptic
- Privacy
- Terms
- Rate App
- Version

Sound/Haptic are SHOULD-level behaviors.

---

# 21. Offline

No change from previous Step 7:

- local coloring works offline
- local progress works offline
- bundled/cached artwork works offline
- remote optional sections degrade gracefully

---

# 22. Error Handling

## Editor Asset Error
- do not open blank editable state over saved work
- show recoverable error

## Save Error
- do not display false Saved
- retain dirty status
- preserve last good snapshot

## Missing Content
- do not crash whole list/home

## Purchase Failure
- no entitlement granted

---

# 23. Traceability — Hi‑Fi Components

| Requirement | Screen | Hi‑Fi Component | Functional Spec |
|---|---|---|---|
| REQ-HOME-006 | SCR-HOME-001 | CMP-HOME-CONTINUE | FS-HOME-001 |
| REQ-CAT-002 | SCR-CATEGORY-001 | CMP-CAT-GRID | FS-CAT-001 |
| REQ-PREVIEW-002 | SCR-PREVIEW-001 | CMP-PREVIEW-START | FS-PREVIEW-002 |
| REQ-EDITOR-001 | SCR-EDITOR-001 | CMP-EDITOR-CANVAS | Editor section |
| REQ-EDITOR-002 | SCR-EDITOR-001 | CMP-EDITOR-PALETTE | FS-EDITOR-COLOR-001 |
| REQ-EDITOR-003 | SCR-EDITOR-001 | CMP-EDITOR-CANVAS / TOOL-RAIL | FS-EDITOR-FILL-001 |
| REQ-EDITOR-004 | SCR-EDITOR-001 | CMP-EDITOR-TOOL-RAIL | FS-EDITOR-BRUSH-001 |
| REQ-EDITOR-006 | SCR-EDITOR-001 | CMP-EDITOR-TOPBAR | FS-EDITOR-HISTORY-001 |
| REQ-EDITOR-007 | SCR-EDITOR-001 | CMP-EDITOR-TOPBAR | FS-EDITOR-HISTORY-002 |
| REQ-EDITOR-011 | SCR-EDITOR-001 | Save indicator | FS-SAVE-* |
| REQ-EDITOR-014 | SCR-EDITOR-001 | Done | FS-COMPLETE-001 |
| REQ-WORK-002 | SCR-WORKS-001 | Work grid/segments | FS-WORK-001 |
| REQ-MON-002 | SCR-PAYWALL-001 | Paywall CTA | FS-MON-001 |

---

# 24. Open Decisions Preserved

The following remain unresolved and must not be silently finalized:

- Platform
- Brush in final MVP
- Daily in MVP
- Preview retention
- Monetization provider/model
- Premium scope
- Final brand tokens
- Audience classification

---

# 25. Definition of Synced Step 7 Complete

- Functional behavior reflects Hi‑Fi structure.
- No unsupported UI placeholder became a requirement.
- Editor components are mapped.
- Stable test IDs are identified.
- Persistence remains compatible.
- No unnecessary backend introduced.
- Impact to data/API is documented.

---

# AI EXECUTION INSTRUCTIONS — STEP 7 HANDOFF

## Step Identity
**Step 7 = Functional / Data / API Specification synced to Hi‑Fi UI**

## Primary Artifact
`functional-spec.md`

## Supporting Artifacts
- `data-model.md`
- `api-spec.md`
- `step7-impact-analysis.md`

## Next Step
**Step 8 — Test Strategy & Test Case Sync**

AI must:
1. Read the new Step 6 Hi‑Fi prototype.
2. Read this synced functional spec.
3. Preserve existing TC IDs where behavior is unchanged.
4. Update cases/selectors impacted by the new UI.
5. Add tests for the new concrete component/state contracts.
