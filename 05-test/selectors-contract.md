# Selector Contract — Native App

Use these accessibility/test IDs in the native implementation.

**Status: Updated — 2026-08-14 re-baseline.** New selectors added for Library/Profile; legacy selectors preserved below (not deleted) for screens no longer routed in the approved MVP core flow.

## Global
- `home-screen`
- `library-screen` *(new)*
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
- `editor-done`

## Editor Tool Rail
- `tool-brush`
- `tool-fill`
- `tool-erase`
- `tool-more`

## Editor Bottom Controls
- `editor-slider`
- `palette-color-green`
- `palette-color-pink`
- `palette-color-blue`
- `palette-color-purple`
- `palette-color-black`
- `editor-fit`

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
