# Regression Scope — Coloring App (Synced to Hi‑Fi)

**Document ID:** REG-COLOR-001  
**Version:** 0.2  
**Status:** Awaiting Build

---

# 1. Buckets

## REG-CORE
- Launch
- Home
- Category
- Preview
- Editor entry
- Completion

## REG-UI-EDITOR
- Topbar
- Tool Rail
- Palette
- Slider
- Quick actions
- Canvas layout

## REG-EDITOR
- Fill
- Brush
- Erase
- Undo
- Redo
- Zoom
- Pan
- Reset

## REG-PERSIST
- Autosave
- Back
- Background
- Relaunch
- Restore
- My Works

## REG-MON
- Locked content
- Paywall
- Purchase
- Restore
- Ads
- Rewarded

## REG-CONTENT
- Category IDs
- Drawing IDs
- Assets
- Premium flag

## REG-DESIGN-CONTRACT
- Screen IDs
- Component mapping
- CTA hierarchy
- selected/disabled states
- Hi‑Fi layout contract

---

# 2. Fix-Based Regression Rules

## Editor functional fix
Run:
- REG-EDITOR
- REG-UI-EDITOR
- REG-PERSIST
- Smoke

## Persistence fix
Run:
- REG-PERSIST
- Editor core
- My Works
- Smoke

## UI-only Editor fix
Run:
- impacted TC
- REG-UI-EDITOR
- REG-DESIGN-CONTRACT
- Smoke if navigation affected

## Navigation fix
Run:
- REG-CORE
- impacted screen tests

## Monetization fix
Run:
- REG-MON
- free/locked navigation
- Smoke

## Content fix
Run:
- REG-CONTENT
- representative discovery/open tests

---

# 3. Release Regression

Recommended before store release:
- Smoke
- REG-CORE
- REG-EDITOR
- REG-PERSIST
- REG-CONTENT
- REG-MON if enabled
- critical REG-UI-EDITOR
