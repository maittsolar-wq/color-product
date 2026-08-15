# Selector Contract — Native App

Use these accessibility/test IDs in the native implementation.

**Status: Updated — 2026-08-14 re-baseline.** New selectors added for Library/Profile; legacy selectors preserved below (not deleted) for screens no longer routed in the approved MVP core flow.

**2026-08-16 addendum:** Editor functional correction — `editor-lock-toggle`/`editor-settings-gear` registered on Editor Topbar; Color Picker and Editor Settings sheet selectors registered (both are overlays on `SCR-EDITOR-001`, not new screens); `palette-color-custom`/`editor-color-prev`/`editor-color-next`/`editor-eyedropper` registered on Editor Bottom Controls. `tool-more` and `workspace-settings` are **removed** (not deprecated) — the controls no longer exist in `SCR-EDITOR-001`.

## Global
- `home-screen`
- `library-screen` *(new)*
- `search-screen` *(new — 2026-08-16)*
- `profile-screen` *(new)*
- `coloring-canvas`
- `settings-screen`
- `paywall`

Legacy (preserved, screen not routed from approved flow):
- `category-screen`
- `drawing-preview`
- `my-works-screen`

## Home
- `premium-home`
- `continue-coloring` *(reactivated 2026-08-16 — Continue Current Artwork card, shown only when an IN_PROGRESS artwork exists)*
- `home-category-section-<categoryId>`
- `home-see-all-<categoryId>`
- `drawing-card-<drawingId>` *(shared pattern, see Drawing Card below)*

Legacy (preserved, not part of approved Home):
- `my-works`
- `settings`

## Bottom Navigation *(new — 2026-08-14)*
- `nav-home`
- `nav-library`
- `nav-profile`

## Drawing Card *(shared pattern — used on Home, Library, Profile)*
- `drawing-card-<drawingId>`

Example:
- `drawing-card-draw_animals_001`

## Library *(new — 2026-08-14)*
- `library-filter-all`
- `library-filter-<categoryId>` (e.g. `library-filter-manga`, `library-filter-animal`, `library-filter-nature`)
- `library-grid`
- `library-search` *(documented 2026-08-16 — existed in prototype markup since the initial Library implementation as an inert icon; now wired to `SCR-SEARCH-001` and formally registered here)*

## Search *(new — 2026-08-16, child of Library)*
- `search-screen`
- `search-back`
- `search-input`
- `search-clear`
- `search-results-grid`
- `search-empty-state`
- `search-explore-library`

Result artwork cards reuse the shared `drawing-card-<drawingId>` pattern (see Drawing Card above) — no separate Search-only card selector.

## Profile *(new — 2026-08-14)*
- `profile-empty-state`
- `profile-explore-library`
- `profile-segment-all`
- `profile-segment-in-progress`
- `profile-segment-completed`
- `profile-grid`
- `profile-settings-icon`

## Category *(legacy — SCR-CATEGORY-001 not routed)*
- `drawing-grid`
- `drawing-card-<drawingId>`

Example:
- `drawing-card-draw_animals_001`

## Preview *(legacy — SCR-PREVIEW-001 not routed)*
- `start-coloring`
- `continue-coloring`

## Editor Topbar
- `undo`
- `redo`
- `editor-lock-toggle` *(new — 2026-08-16; stateful Lock/Unlock control, see Editor Lock/Brush below)*
- `editor-settings-gear` *(new — 2026-08-16; opens the Editor Settings sheet, distinct from `settings`/`settings-screen`)*
- `editor-done`

## Editor Tool Rail
- `tool-brush`
- `tool-fill`
- `tool-erase`

`tool-more` (Add/More) — **removed 2026-08-16.** The control itself was removed from `SCR-EDITOR-001`; not deprecated/hidden, deleted. This selector is no longer part of the active contract.

## Editor Lock/Brush *(clarified — 2026-08-16)*
Lock/Unlock applies per Brush stroke, not to a persistent session-wide region. See `functional-spec.md` FS-EDITOR-BRUSH-002 (if present) or the Editor correction report for the detection/clip approach. No new selectors beyond `editor-lock-toggle` above — stroke clip-paths are implementation detail, not testids.

## Editor Bottom Controls
- `editor-slider`
- `palette-color-green`
- `palette-color-pink`
- `palette-color-blue`
- `palette-color-purple`
- `palette-color-black`
- `palette-color-custom` *(new — 2026-08-16; dedicated swatch for a custom/non-preset activeColor, shown only when active)*
- `editor-color-prev` *(new — 2026-08-16; Playful's Previous-color control)*
- `editor-color-next` *(new — 2026-08-16; Playful's Next-color control)*
- `editor-eyedropper` *(new — 2026-08-16; the single Eyedropper control — arms sample-on-next-tap)*
- `editor-fit`

`workspace-settings` (floating canvas-display button) — **removed 2026-08-16.** Deleted, not hidden.

## Editor Color Picker *(new — 2026-08-16)*
- `color-picker-overlay`
- `color-picker-back`
- `color-picker-save`
- `color-picker-hue-ring`
- `color-picker-hue-handle`
- `color-picker-preview`

## Editor Settings *(new — 2026-08-16; distinct sheet from `settings`/`settings-screen` — SCR-SETTINGS-001 is never opened from here)*
- `editor-settings-overlay`
- `editor-settings-close`
- `editor-settings-sound-toggle`
- `editor-settings-color-history-toggle`
- `editor-settings-mirror-toggle`
- `editor-settings-how-to-color`

## Progress / Test Hooks (optional)
- `editor-save-state`
- `editor-active-color`
- `editor-tool-state`
- `editor-zoom-state`
- `region-state-<regionId>-<colorKey>`

## Works *(legacy — SCR-WORKS-001 not routed; superseded by Profile selectors above)*
- `in-progress-section`
- `completed-section`

## Completion *(new — 2026-08-14)*
- `completion-recommended`
- `completion-share`
- `completion-save`
- `completion-back-home`

## Monetization
- `paywall-close`
- `purchase`
- `restore-purchase`
- `premium-active`

Rule:
Selectors must remain stable across visual copy/style changes whenever behavior is unchanged. Legacy selectors are preserved (not deleted or reassigned) even when their screen is no longer routed from the approved MVP core flow.
