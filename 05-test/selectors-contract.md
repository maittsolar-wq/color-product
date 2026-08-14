# Selector Contract — Native App

Use these accessibility/test IDs in the native implementation.

## Global
- `home-screen`
- `category-screen`
- `drawing-preview`
- `coloring-canvas`
- `my-works-screen`
- `settings-screen`
- `paywall`

## Home
- `premium-home`
- `continue-coloring`
- `my-works`
- `settings`

## Category
- `drawing-grid`
- `drawing-card-<drawingId>`

Example:
- `drawing-card-draw_animals_001`

## Preview
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

## Works
- `in-progress-section`
- `completed-section`

## Monetization
- `paywall-close`
- `purchase`
- `restore-purchase`
- `premium-active`

Rule:
Selectors must remain stable across visual copy/style changes whenever behavior is unchanged.
