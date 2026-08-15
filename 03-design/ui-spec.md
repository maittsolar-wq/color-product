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

**Status: Updated — 2026-08-14 re-baseline.**

Approved scope:

- `SCR-HOME-001` — Home
- `SCR-LIBRARY-001` — Library *(new)*
- `SCR-PROFILE-001` — Profile *(new)*
- `SCR-EDITOR-001` — Coloring Editor
- `SCR-COMPLETE-001` — Completion
- `SCR-PAYWALL-001` — Paywall
- `SCR-SETTINGS-001` — Settings

Legacy (preserved, not routed from approved MVP core flow):

- `SCR-CATEGORY-001` — Category
- `SCR-PREVIEW-001` — Drawing Preview
- `SCR-WORKS-001` — My Works

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

**Status: Updated — 2026-08-14 re-baseline.**

## Purpose
Content discovery.

## Layout (approved, updated 2026-08-16)
1. Top app header with PRO pill (small, near top-left).
2. Continue Current Artwork card — **reactivated 2026-08-16**, shown only when an `IN_PROGRESS` artwork exists.
3. Repeatable category sections (title left / "See all" purple right / horizontally scrollable artwork cards), e.g. Manga, Animal, Nature.
4. Bottom navigation (Home / Library / Profile).

Home scrolls vertically; each section scrolls horizontally, with the next card partially visible to communicate scrollability.

## Legacy Layout (superseded, preserved for traceability)
1. Top app header.
2. Continue Coloring. *(reactivated 2026-08-16 — see approved layout above, no longer legacy)*
3. Featured.
4. Categories (icon grid).
5. Daily Pick.
6. Bottom navigation (Home / My Works / Settings).

## Components (approved, updated 2026-08-16)
- `CMP-HOME-HEADER`
- `CMP-HOME-PREMIUM` *(PRO pill — already implemented in prototype; formalized here)*
- `CMP-HOME-CONTINUE` *(reactivated 2026-08-16 — Continue Current Artwork card)*
- `CMP-HOME-CATEGORY-SECTION` *(repeatable section: title + see-all + horizontal list)*
- `CMP-HOME-SEEALL`
- `CMP-GLOBAL-BOTTOM-NAV` *(targets Home / Library / Profile)*

## Legacy Components (superseded, preserved — not part of approved Home)
- `CMP-HOME-FEATURED`
- `CMP-HOME-CATEGORIES` *(icon grid)*
- `CMP-HOME-DAILY`

## Requirements
- REQ-HOME-001, REQ-HOME-002, REQ-HOME-004, REQ-HOME-006, REQ-HOME-007 (active — REQ-HOME-006 reactivated 2026-08-16)
- REQ-HOME-008, REQ-HOME-009, REQ-HOME-010 (active)
- REQ-HOME-003, REQ-HOME-005 (legacy — superseded, see `requirements.md`)

## Bookmark/Favorite
Not in MVP. No favorite/bookmark control appears anywhere in the approved Home UI.

---

# 6. SCR-CATEGORY-001 — Category

**Status: LEGACY — not routed from approved Home flow (2026-08-14). Preserved for traceability, not deleted or renamed. Browse/filter concepts below may inform `SCR-LIBRARY-001` (§11), which does not reuse this Screen ID or these Component IDs.**

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
- REQ-CAT-001 → REQ-CAT-006 (legacy)

---

# 7. SCR-PREVIEW-001 — Drawing Preview

**Status: LEGACY — not routed from approved MVP core flow (2026-08-14). Preserved for traceability, not deleted or renamed.** CTA Resolution logic below is reassigned to the artwork-tap resolver on Home/Library/Profile/Completion — see `functional-spec.md` §"Artwork-Tap Resolution".

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
- REQ-PREVIEW-001 → REQ-PREVIEW-005 (legacy)

## Note on decorative bookmark
The "♡" icon in this screen's toolbar (prototype `index.html`, Preview `simple-toolbar`) is decorative only — no handler, no requirement, no component ID. Per approved decision, Favorite/Bookmark is out of MVP; this icon is flagged **non-approved / to be removed** from any new production UI. Since this screen itself is legacy, no prototype change is made in this pass — see `functional-spec.md` for the explicit flag.

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

**Status: Updated — role revised, 2026-08-14 re-baseline.**

## Layout (approved)
- Completion title.
- Final artwork.
- Share → native device share sheet.
- Save/Download → save rendered colored artwork image to device.
- Back to Home.
- Recommended for you → artwork cards (tap opens `SCR-EDITOR-001` directly, resume-or-create).

## Legacy Layout items (superseded, preserved)
- View in My Works button
- Undifferentiated "Color another drawing" action

## Components
- `CMP-COMPLETE-RECOMMENDED` *(new — "Recommended for you" artwork card row)*

## Requirements
- REQ-EDITOR-014
- REQ-EDITOR-017 *(new)*
- REQ-WORK-006
- REQ-WORK-007
- REQ-WORK-008

---

# 10. SCR-WORKS-001 — My Works

**Status: LEGACY — superseded by `SCR-PROFILE-001` (§12) (2026-08-14). Preserved for traceability, not deleted or renamed. `SCR-PROFILE-001` is a new, distinct screen — this Screen ID and its components are not reused.**

## Layout
- Header.
- In Progress / Completed segmented control.
- Artwork grid.
- Bottom navigation.

## Requirements
- REQ-WORK-001 → REQ-WORK-005 (REQ-WORK-002/003/004 legacy — see `requirements.md`)

---

# 11. SCR-LIBRARY-001 — Library *(new — 2026-08-14)*

## Purpose
Browse/explore all available artwork, filterable by category.

## Layout
1. Header.
2. Category filter control (All / Manga / Animal / Nature / Food / …).
3. Artwork grid (approximately square thumbnails, rounded cards, subtle border).

## Components
- `CMP-LIBRARY-HEADER`
- `CMP-LIBRARY-FILTERS`
- `CMP-LIBRARY-GRID`
- `CMP-LIBRARY-DRAWING-CARD`

## Requirements
- REQ-LIB-001 → REQ-LIB-006

## Notes
- Entry filter state: pre-applied category when opened via Home "See all"; "All" when opened via Bottom Nav.
- Artwork tap → `SCR-EDITOR-001` directly (resume-or-create), no Preview hop.
- Concepts may draw on legacy `CMP-CAT-*` (§6) but do not reuse those Component IDs.

---

# 12. SCR-PROFILE-001 — Profile *(new — 2026-08-14)*

## Purpose
User-centric personal artwork + Settings entry point.

## Layout
1. Header.
2. Empty state (no personal artwork) with "Explore Library" CTA — shown when no artwork exists.
3. Segmented control: All / Completed / In Progress.
4. Personal artwork grid.
5. Settings icon.

## Components
- `CMP-PROFILE-HEADER`
- `CMP-PROFILE-EMPTY-STATE`
- `CMP-PROFILE-EXPLORE-CTA`
- `CMP-PROFILE-SEGMENTED`
- `CMP-PROFILE-GRID`
- `CMP-PROFILE-SETTINGS-ICON`

## Requirements
- REQ-PROFILE-001 → REQ-PROFILE-007
- BR-PROFILE-001 (artwork state rule)

## Notes
- Not `SCR-SETTINGS-001` — Settings icon routes to the separate Settings screen (§14).
- Artwork tap → `SCR-EDITOR-001` directly (always resume — Profile artwork always has progress).

---

# 13. SCR-PAYWALL-001 — Paywall

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

# 14. SCR-SETTINGS-001 — Settings

## Sections
- Premium.
- Sound / Haptic.
- Privacy.
- Terms.
- Rate App.
- Version.

---

# 15. Responsive Rules

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

# 16. Accessibility Baseline

- Touch targets approx. 44x44pt equivalent.
- Important actions have accessible names.
- State not communicated by color only.
- Text contrast sufficient.
- Tool icons have labels/tooltips or accessible names.

---

# 17. Design Review Checklist

Before approving Step 6:

- [x] Home hierarchy approved — category-sections structure (2026-08-14).
- [x] Preview status decided — legacy, not routed (2026-08-14).
- [ ] Editor toolbar approved.
- [ ] Tool rail approved.
- [ ] Palette and slider approved.
- [x] Completion flow approved — Share/Save/Back Home/Recommended for you (2026-08-14).
- [x] My Works → Profile direction approved (2026-08-14).
- [x] Library structure approved (2026-08-14).
- [ ] Paywall direction approved.
- [ ] Overall cross-age visual approved.

---

# 18. Step 6 Definition of Complete

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
