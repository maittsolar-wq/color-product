# Test Cases — Coloring App (Synced to Hi‑Fi UI)

**Document ID:** TC-COLOR-001  
**Version:** 0.2  
**Status:** Review Draft

---

# 1. Rule

Existing TC IDs remain stable when underlying behavior has not changed.

New TC IDs are added only for concrete Hi‑Fi behaviors that map to existing requirements/functional contracts.

---

# 2. Smoke

## TC-SMOKE-001 — Launch App
**Priority:** P0  
**Automation:** Yes  
**Requirement:** REQ-ENTRY-001

Expected:
- app launches;
- no crash;
- valid route reached.

## TC-SMOKE-002 — Open Category
**Priority:** P0  
**Automation:** Yes  
**Requirement:** REQ-HOME-003

Expected:
- Category opens;
- grid visible.

## TC-SMOKE-003 — Open Drawing & Editor
**Priority:** P0  
**Automation:** Yes  
**Requirements:** REQ-CAT-004, REQ-PREVIEW-002

Expected:
- Preview opens;
- Start opens Editor;
- `coloring-canvas` visible.

## TC-SMOKE-004 — Fill Region
**Priority:** P0  
**Automation:** Partial  
**Requirement:** REQ-EDITOR-003

Expected:
- selected region gets selected color;
- neighbor unchanged.

## TC-SMOKE-005 — Exit & Resume
**Priority:** P0  
**Automation:** Yes/Partial  
**Requirements:** REQ-EDITOR-011, REQ-EDITOR-012

Expected:
- progress restored.

---

# 3. Home

## TC-HOME-001 — Categories Display
**Priority:** P1  
**Automation:** Yes

Expected:
- category section visible.

## TC-HOME-002 — Category Opens Correct Content
**Priority:** P1  
**Automation:** Yes

## TC-HOME-003 — Continue Coloring Visible
**Priority:** P1  
**Automation:** Yes

## TC-HOME-004 — Continue Coloring Hidden
**Priority:** P2  
**Automation:** Yes

## TC-HOME-005 — Partial Content Failure
**Priority:** P1  
**Automation:** Needs fixture

Expected:
- failed Featured does not block Categories.

---

# 4. Category

## TC-CAT-001 — Drawing Grid Loads
**Priority:** P1  
**Automation:** Yes

## TC-CAT-002 — Premium Drawing State
**Priority:** P1  
**Automation:** Yes

## TC-CAT-003 — Completed Drawing State
**Priority:** P2  
**Automation:** Yes

## TC-CAT-004 — Empty Category
**Priority:** P2  
**Automation:** Fixture

## TC-CAT-005 — Load Error Retry
**Priority:** P1  
**Automation:** Fixture

### Note
Hi‑Fi filter chips `All/New/Free` are not mandatory test cases until Product approves filter behavior.

---

# 5. Preview

## TC-PREVIEW-001 — New Drawing Shows Start Coloring
**Priority:** P1  
**Automation:** Yes  
**Test ID:** `start-coloring`

## TC-PREVIEW-002 — In Progress Shows Continue
**Priority:** P1  
**Automation:** Yes

## TC-PREVIEW-003 — Locked Opens Paywall
**Priority:** P1  
**Automation:** Yes

## TC-PREVIEW-004 — Completed State
**Priority:** P2  
**Automation:** Yes

---

# 6. Editor — Tool Rail

## TC-EDITOR-001 — Select Color
**Priority:** P0  
**Automation:** Yes  
**Requirement:** REQ-EDITOR-002

Steps:
1. Open Editor.
2. Tap palette swatch.

Expected:
- swatch becomes selected;
- activeColor changes;
- artwork not modified yet.

---

## TC-EDITOR-002 — Fill One Region
**Priority:** P0  
**Automation:** Partial  
**Requirement:** REQ-EDITOR-003

Precondition:
- Fill selected.

Expected:
- only target region changes.

---

## TC-EDITOR-003 — Tap Outline
**Priority:** P1  
**Automation:** Partial

Expected:
- no unintended fill.

---

## TC-EDITOR-004 — Fill Small Region
**Priority:** P1  
**Automation:** Manual/Partial

---

## TC-EDITOR-005 — Repeated Tap Same Region
**Priority:** P2  
**Automation:** Yes

---

## TC-EDITOR-016 — Select Brush Tool
**Priority:** P1  
**Automation:** Yes  
**Requirement:** REQ-EDITOR-004  
**Component:** CMP-EDITOR-TOOL-RAIL

Steps:
1. Open Editor.
2. Tap Brush.

Expected:
- Brush becomes selected;
- other tool selected states clear;
- activeTool = BRUSH.

---

## TC-EDITOR-017 — Select Fill Tool
**Priority:** P0  
**Automation:** Yes  
**Requirement:** REQ-EDITOR-003

Expected:
- Fill becomes selected;
- subsequent valid tap performs Fill.

---

## TC-EDITOR-018 — Select Erase Tool
**Priority:** P1  
**Automation:** Yes  
**Requirement:** REQ-EDITOR-005

Expected:
- Erase selected;
- erase behavior applies only to supported erasable content.

---

## TC-EDITOR-019 — More/Add Does Not Trigger Undocumented MVP Action
**Priority:** P2  
**Automation:** Manual

Expected:
- if the control remains visible before feature approval, it must not create hidden undocumented core behavior.

---

# 7. Editor — Palette / Slider

## TC-EDITOR-020 — Palette Selected State
**Priority:** P1  
**Automation:** Yes

Steps:
1. Select Green.
2. Select Pink.

Expected:
- only Pink remains selected;
- active color = Pink.

---

## TC-EDITOR-021 — Slider with Brush
**Priority:** P1  
**Automation:** Partial  
**Requirement:** REQ-EDITOR-016

Precondition:
- Brush feature enabled.

Expected:
- slider changes brush size/tool parameter.

---

## TC-EDITOR-022 — Slider Does Not Modify Artwork Directly
**Priority:** P2  
**Automation:** Yes

Expected:
- changing slider alone does not edit canvas.

---

# 8. Editor — Undo / Redo

## TC-EDITOR-006 — Undo Fill
**Priority:** P0  
**Automation:** Yes/Partial

## TC-EDITOR-007 — Redo Fill
**Priority:** P0  
**Automation:** Yes/Partial

## TC-EDITOR-008 — Undo at Initial State
**Priority:** P1  
**Automation:** Yes

## TC-EDITOR-009 — New Action Clears Redo
**Priority:** P1  
**Automation:** Yes

---

# 9. Editor — Zoom / Pan / Fit

## TC-EDITOR-010 — Zoom
**Priority:** P1  
**Automation:** Partial  
**Requirement:** REQ-EDITOR-008

## TC-EDITOR-011 — Pan While Zoomed
**Priority:** P1  
**Automation:** Partial

## TC-EDITOR-012 — Pan Does Not Trigger Fill
**Priority:** P0  
**Automation:** Partial

## TC-EDITOR-023 — Fit/Zoom Quick Action
**Priority:** P1  
**Automation:** Yes/Partial  
**Functional Contract:** FS-EDITOR-VIEW-001

Expected:
- quick action changes viewport;
- artwork coloring state remains unchanged.

---

# 10. Editor — Save / Done

## TC-SAVE-001 — Autosave After Fill
**Priority:** P0  
**Automation:** Yes/Partial

## TC-SAVE-002 — Back Forces Save
**Priority:** P0  
**Automation:** Yes/Partial

## TC-SAVE-003 — Background Forces Save
**Priority:** P0  
**Automation:** Partial

## TC-SAVE-004 — Multiple Regions Restore
**Priority:** P0  
**Automation:** Partial

## TC-SAVE-005 — Save Failure
**Priority:** P0  
**Automation:** Fixture

## TC-SAVE-006 — Corrupted Progress
**Priority:** P1  
**Automation:** Fixture

## TC-EDITOR-024 — Done Forces Final Save
**Priority:** P0  
**Automation:** Yes/Partial  
**Requirement:** REQ-EDITOR-014

Steps:
1. Modify artwork.
2. Immediately tap Done.

Expected:
- latest state saved;
- progress status becomes COMPLETED;
- Completion opens.

---

# 11. Reset

## TC-EDITOR-013 — Reset Requires Confirmation
## TC-EDITOR-014 — Cancel Reset
## TC-EDITOR-015 — Confirm Reset

Existing behavior unchanged.

---

# 12. My Works

## TC-WORK-001 — In Progress Listed
## TC-WORK-002 — Completed Listed
## TC-WORK-003 — Resume from My Works
## TC-WORK-004 — Empty My Works

No requirement behavior change.

---

# 13. Completion

## TC-COMPLETE-001 — Complete Drawing
**Priority:** P1  
**Automation:** Yes

Expected:
- Completion screen opens.

## TC-COMPLETE-002 — Save Final Image
**Priority:** P1  
**Automation:** Partial

## TC-COMPLETE-003 — Permission Denied
**Priority:** P2  
**Automation:** Partial

## TC-COMPLETE-004 — Share
**Priority:** P2  
**Automation:** Partial

---

# 14. Paywall / Monetization

## TC-MON-001 — Free User Locked Drawing
## TC-MON-002 — Paywall Close Preserves Context
## TC-MON-003 — Purchase Success
## TC-MON-004 — Purchase Failure
## TC-MON-005 — Restore Success
## TC-MON-006 — Premium Removes Ads
## TC-MON-007 — No Interstitial During Editor
## TC-MON-008 — Reward Unlock Success
## TC-MON-009 — Reward Cancel/Fail

### Hi‑Fi note
Prototype trial/price text is placeholder.
Do not test exact price text until store product configuration is confirmed.

---

# 15. Settings

## TC-SET-001 — Open Settings
## TC-SET-002 — Restore Purchase
## TC-SET-003 — Privacy
## TC-SET-004 — Terms

Sound/Haptic:
- test only if included in MVP build.

---

# 16. Offline

## TC-OFFLINE-001 — Open Local Drawing Offline
## TC-OFFLINE-002 — Save Progress Offline
## TC-OFFLINE-003 — Relaunch Offline & Resume
## TC-OFFLINE-004 — Remote Section Fails Gracefully

No change.

---

# 17. Content QA

## TC-CONTENT-001 — Unique Category IDs
## TC-CONTENT-002 — Unique Drawing IDs
## TC-CONTENT-003 — Valid Category Reference
## TC-CONTENT-004 — Thumbnail Exists
## TC-CONTENT-005 — Coloring Asset Exists
## TC-CONTENT-006 — Missing Asset Does Not Crash
## TC-CONTENT-007 — Premium Flag Correct

No schema change required.

---

# 18. Hi‑Fi Visual / UX Contract Tests

## TC-UI-001 — Editor Canvas Remains Primary Visual Area
**Priority:** P1  
**Automation:** Visual/Manual

Expected:
- tool chrome does not dominate or obscure primary artboard.

## TC-UI-002 — Tool Rail Does Not Cover Critical Artwork
**Priority:** P1  
**Automation:** Manual/Visual

## TC-UI-003 — Palette Reachability
**Priority:** P1  
**Automation:** Manual

## TC-UI-004 — Selected State Is Visible
**Priority:** P1  
**Automation:** Visual

Covers:
- selected tool
- selected color
- disabled history control

## TC-UI-005 — Cross-Age Clarity
**Priority:** P1  
**Automation:** Manual

---

# 19. Traceability Additions

| TC | Requirement / Contract | Screen | Component |
|---|---|---|---|
| TC-EDITOR-016 | REQ-EDITOR-004 | SCR-EDITOR-001 | CMP-EDITOR-TOOL-RAIL |
| TC-EDITOR-017 | REQ-EDITOR-003 | SCR-EDITOR-001 | CMP-EDITOR-TOOL-RAIL |
| TC-EDITOR-018 | REQ-EDITOR-005 | SCR-EDITOR-001 | CMP-EDITOR-TOOL-RAIL |
| TC-EDITOR-020 | REQ-EDITOR-002 | SCR-EDITOR-001 | CMP-EDITOR-PALETTE |
| TC-EDITOR-021 | REQ-EDITOR-016 | SCR-EDITOR-001 | CMP-EDITOR-SLIDER |
| TC-EDITOR-023 | FS-EDITOR-VIEW-001 | SCR-EDITOR-001 | CMP-EDITOR-QUICK-ACTIONS |
| TC-EDITOR-024 | REQ-EDITOR-014 | SCR-EDITOR-001 | CMP-EDITOR-TOPBAR |

---

# 20. Step 8 Sync Completion

This file supersedes the previous Step 8 test-cases artifact for downstream automation.
