# UI Specification — Coloring App (Hi‑Fi)

**Document ID:** UI-COLOR-001  
**Version:** 1.0  
**Status:** Review Draft  
**Step:** 6 — Hi‑Fi HTML UI Prototype + UI Specification  

**Related Documents**
- `product-brief.md`
- `competitor-analysis.md`
- `mvp-scope.md`
- `information-architecture-user-flow.md`
- `requirements.md`

---

# 1. Purpose

Step 6 này thay thế bản prototype low‑fidelity trước đó.

Mục tiêu là tạo một **Hi‑Fi HTML UI Prototype** đủ gần giao diện production để dùng làm:

- Design source of truth.
- UI review với sếp.
- Developer handoff.
- Input cho Functional Spec.
- Input cho Test Case / Automation.
- Reference để implement native UI.

Prototype phải thể hiện **bố cục, hierarchy, component, spacing, tool placement, state và interaction** gần app thật; không chỉ mô phỏng bằng card sơ bộ.

---

# 2. Design Goal

Sản phẩm phải mang cảm giác:

**Friendly + Relaxing + Clean + Modern + Creative**

Không:
- quá trẻ con;
- quá chuyên nghiệp kiểu Photoshop;
- quá nhiều decoration;
- paywall lấn át trải nghiệm tô màu;
- toolbar chiếm quá nhiều canvas.

---

# 3. Hi‑Fi Prototype Scope

Prototype gồm:

- `SCR-HOME-001` — Home
- `SCR-CATEGORY-001` — Category
- `SCR-PREVIEW-001` — Drawing Preview
- `SCR-EDITOR-001` — Coloring Editor
- `SCR-COMPLETE-001` — Completion
- `SCR-WORKS-001` — My Works
- `SCR-PAYWALL-001` — Paywall
- `SCR-SETTINGS-001` — Settings

Editor được ưu tiên cao nhất về độ hoàn thiện.

---

# 4. Traceability Rules

Mỗi screen và component phải giữ stable IDs.

Example:

```html
<section
  data-screen-id="SCR-EDITOR-001"
  data-requirement="REQ-EDITOR-001"
>
```

```html
<button
  data-component-id="CMP-EDITOR-UNDO"
  data-requirement="REQ-EDITOR-006"
  data-testid="undo"
>
```

Các attribute bắt buộc khi phù hợp:
- `data-screen-id`
- `data-component-id`
- `data-requirement`
- `data-testid`

---

# 5. SCR-HOME-001 — Home

## Purpose
Content discovery.

## Layout
1. Top app header.
2. Continue Coloring.
3. Featured.
4. Categories.
5. Daily Pick.
6. Bottom navigation.

## Components
- `CMP-HOME-HEADER`
- `CMP-HOME-CONTINUE`
- `CMP-HOME-FEATURED`
- `CMP-HOME-CATEGORIES`
- `CMP-HOME-DAILY`
- `CMP-GLOBAL-BOTTOM-NAV`

## Requirements
- REQ-HOME-001
- REQ-HOME-002
- REQ-HOME-003
- REQ-HOME-004
- REQ-HOME-005
- REQ-HOME-006

---

# 6. SCR-CATEGORY-001 — Category

## Layout
1. Back/title header.
2. Filter chips.
3. 2-column artwork grid.
4. Locked/In-progress/Completed state.

## Components
- `CMP-CAT-HEADER`
- `CMP-CAT-FILTERS`
- `CMP-CAT-GRID`
- `CMP-CAT-DRAWING-CARD`

## Requirements
- REQ-CAT-001 → REQ-CAT-006

---

# 7. SCR-PREVIEW-001 — Drawing Preview

## Layout
1. Back / favorite.
2. Large line-art artwork.
3. Category/tag.
4. Title + short description.
5. Primary CTA.
6. Secondary CTA.

## CTA Resolution
- New → Start Coloring.
- In Progress → Continue Coloring.
- Locked → Unlock.
- Completed → View / Color Again.

## Requirements
- REQ-PREVIEW-001 → REQ-PREVIEW-005

---

# 8. SCR-EDITOR-001 — Coloring Editor

## Design Intent

Editor follows the ergonomic pattern visible in the provided reference:

- slim top toolbar;
- large neutral canvas;
- floating vertical tool rail on the right;
- color/opacity control area at the bottom;
- palette row;
- quick action row;
- minimal chrome;
- canvas remains dominant.

The reference is used for **layout/interaction inspiration**, not pixel-for-pixel copying.

## Layout

```text
Top Status / Toolbar
┌──────────────────────────┐
│ Back | Undo Redo | Tools │
│                    Done  │
├──────────────────────────┤
│                          │
│          Canvas          │
│                    Tool  │
│                    Rail  │
│                          │
├──────────────────────────┤
│ Slider / Color Controls  │
│ Palette                  │
│ Bottom Quick Actions     │
└──────────────────────────┘
```

## Components

### `CMP-EDITOR-TOPBAR`
Contains:
- Back.
- Undo.
- Redo.
- Secondary tool icons.
- Done.

Related:
- REQ-EDITOR-006
- REQ-EDITOR-007
- REQ-EDITOR-014

### `CMP-EDITOR-CANVAS`
- Large centered artwork.
- Supports default/zoomed viewport.
- White artboard on light neutral workspace.

Related:
- REQ-EDITOR-001
- REQ-EDITOR-003
- REQ-EDITOR-008
- REQ-EDITOR-009

### `CMP-EDITOR-TOOL-RAIL`
Vertical floating tools:
- Brush.
- Fill.
- Erase.
- Add/More.

Related:
- REQ-EDITOR-003
- REQ-EDITOR-004
- REQ-EDITOR-005

### `CMP-EDITOR-SLIDER`
Context control for brush size/opacity/tool intensity.

### `CMP-EDITOR-PALETTE`
Color swatches.

Related:
- REQ-EDITOR-002
- REQ-EDITOR-015

### `CMP-EDITOR-QUICK-ACTIONS`
- Eyedropper / options.
- Previous.
- Playful palette/style.
- Next.
- Fit/expand.

## Editor States
- Default.
- Zoom In.
- Zoom Out.
- Saving.
- Saved.
- Error.
- Tool selected.
- Color selected.

## UX Rules
1. No interstitial in active editor.
2. Tool rail must not cover critical artwork.
3. Palette must remain thumb-reachable.
4. Pan must not accidentally trigger Fill.
5. Back forces autosave.
6. Undo/Redo enabled state must be visible.
7. Done remains easily accessible.

---

# 9. SCR-COMPLETE-001 — Completion

## Layout
- Completion title.
- Final artwork.
- Save Image.
- Share.
- My Works.
- Back Home.

## Requirements
- REQ-EDITOR-014
- REQ-WORK-006
- REQ-WORK-007
- REQ-WORK-008

---

# 10. SCR-WORKS-001 — My Works

## Layout
- Header.
- In Progress / Completed segmented control.
- Artwork grid.
- Bottom navigation.

## Requirements
- REQ-WORK-001 → REQ-WORK-005

---

# 11. SCR-PAYWALL-001 — Paywall

## Layout
- Close.
- Premium visual.
- Value proposition.
- Benefits.
- Offer.
- CTA.
- Restore.
- Legal.

## UX Rule
Must be premium-looking but not aggressive.

## Requirements
- REQ-MON-001 → REQ-MON-006

---

# 12. SCR-SETTINGS-001 — Settings

## Sections
- Premium.
- Sound / Haptic.
- Privacy.
- Terms.
- Rate App.
- Version.

---

# 13. Responsive Rules

## Mobile Phone
- 2-column content grid.
- Editor optimized for portrait.
- Bottom controls thumb reachable.

## Large Phone
- Preserve proportions.
- Increase artboard moderately.

## Tablet
- 3–4 column discovery grid.
- Larger canvas.
- Tool rail can remain floating.

---

# 14. Accessibility Baseline

- Touch targets approx. 44x44pt equivalent.
- Important actions have accessible names.
- State not communicated by color only.
- Text contrast sufficient.
- Tool icons have labels/tooltips or accessible names.

---

# 15. Design Review Checklist

Before approving Step 6:

- [ ] Home hierarchy approved.
- [ ] Category density approved.
- [ ] Preview retained or removed.
- [ ] Editor toolbar approved.
- [ ] Tool rail approved.
- [ ] Palette and slider approved.
- [ ] Completion flow approved.
- [ ] My Works structure approved.
- [ ] Paywall direction approved.
- [ ] Overall cross-age visual approved.

---

# 16. Step 6 Definition of Complete

Step 6 is complete when:

- Hi‑Fi HTML prototype is reviewable.
- Core screens visually coherent.
- Editor is production-like.
- All major interactive components have IDs.
- Visual system is documented.
- Design assumptions are documented.
- Sếp/Product approves V1 or requests revisions.

---

# AI EXECUTION INSTRUCTIONS — STEP 6 HANDOFF

## Step Identity
**Step 6 = Hi‑Fi HTML UI Prototype + UI Specification**

## Primary Artifacts
- `ui-spec.md`
- `design-system.md`
- `design-decisions.md`

## Supporting Artifact
- `prototype/`

## Next Step
**Step 7 = Functional / Data / API Specification Sync**

After Step 6 is approved, AI must:
1. Read the approved Hi‑Fi prototype.
2. Compare Step 7 artifacts against actual UI.
3. Perform impact analysis.
4. Update only impacted functional/data/API areas.
5. Preserve stable IDs.
