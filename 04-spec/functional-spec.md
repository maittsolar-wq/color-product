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

**Status: Updated — 2026-08-14 re-baseline.**

The native implementation must preserve equivalent identifiers for:

- `SCR-HOME-001`
- `SCR-LIBRARY-001` *(new)*
- `SCR-PROFILE-001` *(new)*
- `SCR-EDITOR-001`
- `SCR-COMPLETE-001`
- `SCR-PAYWALL-001`
- `SCR-SETTINGS-001`

Legacy (preserved, not routed from approved MVP core flow — do not delete or rename):

- `SCR-CATEGORY-001`
- `SCR-PREVIEW-001`
- `SCR-WORKS-001`

## FS-UI-002 — Stable Testability IDs

Interactive production UI should expose stable accessibility/test identifiers matching the design where practical.

Examples:

- `premium-home`
- `home-category-section-<categoryId>`
- `home-see-all-<categoryId>`
- `library-filter-<categoryId>`
- `drawing-grid`
- `drawing-card-<drawingId>`
- `coloring-canvas`
- `undo`
- `redo`
- `purchase`
- `library`
- `profile`
- `profile-segment-all` / `profile-segment-in-progress` / `profile-segment-completed`
- `profile-explore-library`
- `profile-settings-icon`
- `completion-recommended`
- `settings`

Legacy identifiers (preserved, no longer part of the approved routing contract but still valid if the legacy screens are reached):
- `continue-coloring`
- `start-coloring`
- `my-works`

These are contracts for QA automation and should not depend on display text.

---

# 4. Home Functional Specification

## FS-HOME-001 — Home Assembly

**Status: Updated — 2026-08-14 re-baseline.**

**Screen:** SCR-HOME-001  
**Requirements:** REQ-HOME-001, REQ-HOME-002, REQ-HOME-004, REQ-HOME-007, REQ-HOME-008, REQ-HOME-009, REQ-HOME-010  

Approved Home contains:

1. App header with PRO pill
2. Repeatable category sections (title, "See all", horizontally scrollable artwork cards) — e.g. Manga, Animal, Nature
3. Bottom navigation (Home / Library / Profile)

**Legacy content blocks (superseded, preserved — REQ-HOME-003/005/006):** Continue Coloring, Featured, icon-based Categories grid, Daily Pick. Not part of the approved assembly.

### Category Sections

Each section resolves a set of Drawing entities for its category.

Invalid content:
- a section that fails to load does not block other sections from rendering (REQ-HOME-007).
- hide invalid card or render safe fallback.

### Artwork Card Tap

See `FS-DISCOVERY-RESOLVE-001` (§4.1) — shared resolution logic used by Home, Library, Profile, and Completion.

### See All

Tap "See all" on a category section:
`SCR-HOME-001 → SCR-LIBRARY-001` with that category's filter pre-applied (`REQ-HOME-008`).

### PRO

Tap PRO pill:
`SCR-HOME-001 → SCR-PAYWALL-001` (unchanged from prior behavior).

---

## 4.1 FS-DISCOVERY-RESOLVE-001 — Artwork-Tap Resolution *(new — 2026-08-14, shared logic)*

**Requirements:** REQ-HOME-009, REQ-LIB-003, REQ-PROFILE-005, REQ-EDITOR-017

Applies whenever an artwork card is tapped on `SCR-HOME-001`, `SCR-LIBRARY-001`, `SCR-COMPLETE-001` ("Recommended for you"), or `SCR-PROFILE-001`.

```text
On artwork card tap:
1. Look up Progress record for (drawingId, user).
2. If Progress exists and status = IN_PROGRESS or COMPLETED:
   - restore that Progress
3. If no Progress exists:
   - create a new Progress record (status = IN_PROGRESS)
4. Open SCR-EDITOR-001 with the resolved/created Progress.
```

**Note:** On `SCR-PROFILE-001` specifically, the artwork always has an existing Progress record (Profile only lists personal artwork) — step 3 (create) does not apply there; see `REQ-PROFILE-005`.

This resolver replaces the CTA-resolution role previously owned exclusively by `SCR-PREVIEW-001` (`FS-PREVIEW-002`). Locked-artwork handling (`REQ-PREVIEW-004`) is preserved as part of this resolver: if the artwork is locked, route to `SCR-PAYWALL-001` instead of `SCR-EDITOR-001`.

---

## 4.2 Library Functional Specification *(new — 2026-08-14)*

### FS-LIB-001 — Library Assembly

**Screen:** SCR-LIBRARY-001  
**Requirements:** REQ-LIB-001, REQ-LIB-002, REQ-LIB-005, REQ-LIB-006

Contains:
1. Category filter control (All / Manga / Animal / Nature / Food / …)
2. Filtered artwork grid

### FS-LIB-002 — Filter Resolution

**Requirement:** REQ-LIB-004

```text
On open from Home "See all":
  filter = the category tapped
On open from Bottom Nav:
  filter = All
On open from Profile "Explore Library":
  filter = All
```

### FS-LIB-003 — Artwork Tap

**Requirement:** REQ-LIB-003

Tap artwork card → `FS-DISCOVERY-RESOLVE-001` (§4.1).

---

# 5. Category Functional Specification

**Status: LEGACY — `SCR-CATEGORY-001` not routed from approved Home flow (2026-08-14). Preserved for traceability.**

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

**Status: LEGACY — `SCR-PREVIEW-001` not routed from approved MVP core discovery flow (2026-08-14). Preserved for traceability. CTA resolution logic (`FS-PREVIEW-002`) is superseded by the shared `FS-DISCOVERY-RESOLVE-001` (§4.1).**

## FS-PREVIEW-001 — Preview Resolution

**Screen:** SCR-PREVIEW-001

Load:
- artwork
- metadata
- state
- access
- progress

## FS-PREVIEW-002 — CTA Resolution *(LEGACY — logic superseded by FS-DISCOVERY-RESOLVE-001, §4.1)*

Component:
`CMP-PREVIEW-START`

Rule:

```text
Locked     → Unlock / Paywall
InProgress → Continue Coloring
Completed  → View / Color Again
Default    → Start Coloring
```

**Status:** Preview is no longer routed from the approved MVP core discovery flow (2026-08-14). Step 4 (`information-architecture-user-flow.md`) and Step 5 (`requirements.md`) have been updated accordingly, per the condition originally stated here. This CTA rule is preserved for traceability; its equivalent logic now lives in `FS-DISCOVERY-RESOLVE-001`.

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

**Status: Updated — 2026-08-15 correction (header Back).**

Tap Done:
1. save current state
2. mark progress COMPLETED
3. set completedAt
4. open `SCR-COMPLETE-001`

Completion actions (approved):
- Header Back (top-left) → **corrected 2026-08-15**, see `FS-COMPLETE-003` — distinct from Back to Home
- Share → native device share sheet
- Save/Download → save rendered colored artwork image to device
- Back to Home → `SCR-HOME-001`, unchanged
- Recommended for you → artwork cards; tap resolves via `FS-DISCOVERY-RESOLVE-001` (§4.1), opens `SCR-EDITOR-001` directly

**Legacy actions (superseded, preserved):** View in My Works, undifferentiated "Home" action folded into "Back to Home".

## FS-COMPLETE-002 — Recommended For You *(new — 2026-08-14)*

**Component:** `CMP-COMPLETE-RECOMMENDED`  
**Requirement:** REQ-EDITOR-017

Populate with a set of Drawing entities (source/algorithm not specified by this pass — implementation may start with simple same-category or "not yet started" heuristics). Tap → `FS-DISCOVERY-RESOLVE-001`.

## FS-COMPLETE-003 — Header Back to Same Artwork *(new — 2026-08-15 correction)*

**Requirement:** REQ-EDITOR-018
**Test ID:** `completion-back` (distinct from `completion-back-home`)

```text
On header Back tap:
1. Resolve drawingId = the artwork that was just completed (the same one Done was pressed on).
2. Look up its existing Progress record — it always exists (status = COMPLETED).
3. Restore that Progress into the Editor (same rule as FS-DISCOVERY-RESOLVE-001's restore branch;
   the create branch never applies here).
4. Open SCR-EDITOR-001. Do not route through SCR-PREVIEW-001 or SCR-CATEGORY-001.
5. status remains COMPLETED — this action must not silently revert it to IN_PROGRESS.
```

If the user edits further and taps Done again: save current state, keep status COMPLETED (not re-derived from scratch), set/refresh completedAt, reopen `SCR-COMPLETE-001` — i.e. `FS-COMPLETE-001` steps 1–4 run again unchanged.

**Not to be confused with:** "Back to Home" (`FS-COMPLETE-001`), which always goes to `SCR-HOME-001` regardless of which artwork was completed.

---

# 18. My Works

**Status: LEGACY — `SCR-WORKS-001` superseded by `SCR-PROFILE-001` (§18.1) (2026-08-14). Preserved for traceability, not routed from bottom navigation.**

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

## 18.1 Profile (supersedes My Works) *(new — 2026-08-14)*

### FS-PROFILE-001 — Profile Assembly

**Screen:** SCR-PROFILE-001  
**Requirements:** REQ-PROFILE-001 → REQ-PROFILE-004

Segments:
- All
- Completed
- In Progress

Data source:
Progress records (same underlying entity as legacy My Works — no new persistence model, see `data-model.md`).

Recommended sort:
`updatedAt DESC`

Empty state (no Progress records at all):
- show empty state with "Explore Library" CTA → `SCR-LIBRARY-001` (`REQ-PROFILE-002`).

### FS-PROFILE-002 — Artwork State Rule

**Business Rule:** BR-PROFILE-001

```text
On Editor exit without Done:
  Progress.status = IN_PROGRESS
  → appears in Profile/All, Profile/In Progress
  → does not appear in Profile/Completed

On Editor Done:
  Progress.status = COMPLETED
  → appears in Profile/All, Profile/Completed
  → no longer appears in Profile/In Progress
```

### FS-PROFILE-003 — Artwork Tap

Tap artwork card → `FS-DISCOVERY-RESOLVE-001` (§4.1). Always resolves to restore (Profile artwork always has an existing Progress record).

### FS-PROFILE-004 — Settings Icon

Tap Settings icon → `SCR-SETTINGS-001` (`REQ-PROFILE-006`). Settings remains a separate screen; Profile does not absorb Settings content.

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

**Status column added 2026-08-14.**

| Requirement | Screen | Hi‑Fi Component | Functional Spec | Status |
|---|---|---|---|---|
| REQ-HOME-006 | SCR-HOME-001 | CMP-HOME-CONTINUE | FS-HOME-001 | Legacy — superseded by REQ-HOME-009 |
| REQ-HOME-008 | SCR-HOME-001 / SCR-LIBRARY-001 | CMP-HOME-SEEALL | FS-HOME-001 | Active — NEW |
| REQ-HOME-009 | SCR-HOME-001 / SCR-EDITOR-001 | CMP-HOME-CATEGORY-SECTION | FS-DISCOVERY-RESOLVE-001 | Active — NEW |
| REQ-CAT-002 | SCR-CATEGORY-001 | CMP-CAT-GRID | FS-CAT-001 | Legacy — not routed |
| REQ-PREVIEW-002 | SCR-PREVIEW-001 | CMP-PREVIEW-START | FS-PREVIEW-002 | Legacy — superseded by FS-DISCOVERY-RESOLVE-001 |
| REQ-EDITOR-001 | SCR-EDITOR-001 | CMP-EDITOR-CANVAS | Editor section | Active |
| REQ-EDITOR-002 | SCR-EDITOR-001 | CMP-EDITOR-PALETTE | FS-EDITOR-COLOR-001 | Active |
| REQ-EDITOR-003 | SCR-EDITOR-001 | CMP-EDITOR-CANVAS / TOOL-RAIL | FS-EDITOR-FILL-001 | Active |
| REQ-EDITOR-004 | SCR-EDITOR-001 | CMP-EDITOR-TOOL-RAIL | FS-EDITOR-BRUSH-001 | Active |
| REQ-EDITOR-006 | SCR-EDITOR-001 | CMP-EDITOR-TOPBAR | FS-EDITOR-HISTORY-001 | Active |
| REQ-EDITOR-007 | SCR-EDITOR-001 | CMP-EDITOR-TOPBAR | FS-EDITOR-HISTORY-002 | Active |
| REQ-EDITOR-011 | SCR-EDITOR-001 | Save indicator | FS-SAVE-* | Active |
| REQ-EDITOR-014 | SCR-EDITOR-001 | Done | FS-COMPLETE-001 | Active |
| REQ-EDITOR-017 | SCR-COMPLETE-001 / SCR-EDITOR-001 | CMP-COMPLETE-RECOMMENDED | FS-COMPLETE-002 | Active — NEW |
| REQ-EDITOR-018 | SCR-COMPLETE-001 / SCR-EDITOR-001 | CMP-COMPLETE-HEADER | FS-COMPLETE-003 | Active — NEW (2026-08-15 correction) |
| REQ-WORK-002 | SCR-WORKS-001 | Work grid/segments | FS-WORK-001 | Legacy — superseded by FS-PROFILE-001 |
| REQ-MON-002 | SCR-PAYWALL-001 | Paywall CTA | FS-MON-001 | Active |
| REQ-LIB-001 | SCR-LIBRARY-001 | CMP-LIBRARY-GRID | FS-LIB-001 | Active — NEW |
| REQ-LIB-002 | SCR-LIBRARY-001 | CMP-LIBRARY-FILTERS | FS-LIB-002 | Active — NEW |
| REQ-PROFILE-001 | SCR-PROFILE-001 | CMP-PROFILE-SEGMENTED / GRID | FS-PROFILE-001 | Active — NEW |
| REQ-PROFILE-002 | SCR-PROFILE-001 | CMP-PROFILE-EMPTY-STATE | FS-PROFILE-001 | Active — NEW |
| REQ-PROFILE-007 | SCR-PROFILE-001 | CMP-PROFILE-GRID | FS-PROFILE-002 | Active — NEW |

---

# 24. Open Decisions Preserved

**Status: Updated — 2026-08-14.** Items resolved by this re-baseline are struck through; remaining items are still unresolved and must not be silently finalized.

- Platform
- Brush in final MVP
- ~~Daily in MVP~~ — **Resolved: Legacy, not part of approved Home structure (DD-012).**
- ~~Preview retention~~ — **Resolved: Legacy, not routed from approved MVP core flow (DD-013).**
- Monetization provider/model
- Premium scope
- Final brand tokens
- Audience classification
- **New:** Formal retirement timeline (if any) for legacy `SCR-CATEGORY-001` / `SCR-PREVIEW-001` / `SCR-WORKS-001` — currently preserved indefinitely, no retirement decision made.

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
