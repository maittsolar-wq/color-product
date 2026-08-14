# Test Strategy — Coloring App (Synced to Hi‑Fi UI)

**Document ID:** TS-COLOR-001  
**Version:** 0.2  
**Status:** Review Draft  
**Step:** 8 — Test Strategy & Test Case Sync

**Synced Against**
- Step 6 Hi‑Fi UI
- Synced Step 7 Functional Spec
- Data Model v0.2
- API Spec v0.2

---

# 1. Purpose

This strategy validates the MVP against:

`Product → Requirements → Hi‑Fi UI → Functional Spec → Test`

The Hi‑Fi prototype is now treated as a design contract for:
- component placement;
- interaction hierarchy;
- stable component/test IDs;
- Editor structure.

---

# 2. Test Objectives

## OBJ-001 — Core Coloring Reliability
Validate:
`Launch → Home → Category → Preview → Editor → Color → Save → Resume → Complete`

## OBJ-002 — Editor Component Integrity
Validate:
- Topbar
- Undo / Redo
- Tool Rail
- Palette
- Context Slider
- Canvas
- Zoom/Fit
- Done

## OBJ-003 — Progress Safety
Validate:
- autosave
- back
- background
- relaunch
- restore

## OBJ-004 — Design/Requirement Consistency
Validate native implementation against Hi‑Fi structure without treating design placeholders as new product requirements.

## OBJ-005 — Content / Monetization / Offline
Preserve prior coverage.

---

# 3. Risk Priority

## P0
- Launch crash
- Cannot enter Editor
- Fill broken
- Progress loss
- Wrong restore
- Purchase grants Premium incorrectly
- Active Editor interrupted by interstitial

## P1
- Undo/Redo broken
- Tool selection wrong
- Palette state wrong
- Pan triggers Fill
- Wrong drawing opens
- My Works cannot resume
- Paywall loses context

---

# 4. Test Layers

## Smoke
Production build readiness.

## Functional
Requirement behavior.

## UI Contract
Screen/component hierarchy and selected/disabled state.

## Prototype
Playwright against Hi‑Fi HTML.

## Integration
Persistence / purchase / reward.

## Content QA
Metadata/assets.

## Exploratory
Coloring feel, precision, cross-age usability.

---

# 5. Entry Criteria

Testing starts when:

- build installs;
- supported content exists;
- requirement baseline exists;
- native UI exposes stable IDs where practical;
- Editor selectors exist for critical controls;
- test configuration is documented.

Recommended IDs:

```text
home-screen
continue-coloring
category-screen
drawing-grid
drawing-card-<drawingId>
drawing-preview
start-coloring
coloring-canvas
undo
redo
tool-brush
tool-fill
tool-erase
tool-more
editor-slider
palette-color-<id>
editor-fit
editor-done
my-works
settings
paywall
purchase
restore-purchase
```

---

# 6. Exit Criteria

Release candidate:
- Smoke PASS
- P0 = 0
- Core P1 = 0
- Fill PASS
- Undo/Redo PASS
- Autosave/Restore PASS
- Tool selection PASS
- Core navigation PASS
- Content QA PASS
- Monetization PASS if enabled
- No core crash

---

# 7. Manual vs Automation

## Automate
- navigation
- Preview CTA
- tool selection
- palette selection
- Undo/Redo
- My Works
- Paywall
- settings
- basic autosave/resume
- content validation

## Partial Automation
- canvas region fill
- zoom/pan gesture quality
- slider exact behavior
- background lifecycle
- purchase/reward integration

## Manual
- brush feel
- fill precision
- visual polish
- thumb reachability
- cross-age usability
- artwork readability

---

# 8. Hi‑Fi-Specific Regression Areas

## REG-UI-EDITOR
- Topbar
- Tool Rail
- Slider
- Palette
- Quick actions
- Canvas layout

## REG-DESIGN-CONTRACT
- Screen IDs
- test IDs
- CTA mapping
- state visibility

Existing:
- REG-CORE
- REG-EDITOR
- REG-PERSIST
- REG-MON
- REG-CONTENT

---

# 9. Step 8 Definition of Complete

- Existing TC IDs preserved where behavior unchanged.
- New concrete Editor controls have coverage.
- Design placeholders are not mistaken for requirements.
- Automation candidates use new stable selectors.
- Step 9 can regenerate automation without ambiguity.

---

# AI EXECUTION INSTRUCTIONS — STEP 8 HANDOFF

## Step Identity
**Step 8 = Test Strategy & Test Case Sync to Hi‑Fi UI**

## Primary Artifacts
- `test-strategy.md`
- `test-cases.md`

## Supporting
- `automation-candidates.md`
- `step8-impact-analysis.md`

## Next Step
**Step 9 — Automation Sync**

AI must:
1. preserve TC IDs;
2. update selectors;
3. regenerate Maestro/Playwright mapping;
4. keep placeholder/non-approved controls out of mandatory automation.
