# Design Decisions — Coloring App Step 6 Hi‑Fi

**Document ID:** DD-COLOR-001  
**Version:** 1.0  
**Status:** Review Draft  

---

# 1. Confirmed Inputs

- Product is casual coloring entertainment.
- Target includes adults and children/casual users.
- No art knowledge required.
- Artwork-first.
- Editor is core product screen.
- Autosave/restore is critical.

---

# 2. Assumptions Used in Hi‑Fi V1

## DD-001 — Mobile Portrait First
Prototype optimized for phone portrait.

## DD-002 — Bottom Navigation
Home / My Works / Settings.

## DD-003 — Preview Screen Retained
A separate Preview remains in V1.

## DD-004 — Hybrid Editor
Fill is primary; Brush + Erase are available.

## DD-005 — Floating Tool Rail
Editor uses right-side vertical tool rail inspired by the supplied reference.

## DD-006 — Bottom Color Controls
Slider + palette + quick actions placed below canvas.

## DD-007 — Daily on Home
Daily remains a Home section, not a root tab.

## DD-008 — Completion Screen
Dedicated completion screen retained.

## DD-009 — Premium UI
Paywall and Premium states remain in V1 for flow validation.

---

# 3. Decisions Still Needing Product Approval

- Final brand colors.
- Final icon set.
- Whether Preview screen stays.
- Whether Brush is in MVP.
- Whether Daily is MVP.
- Final monetization model.
- Exact premium scope.
- Final audience classification.

---

# 4. Design Source of Truth Rule

After V1 approval:
- HTML prototype + `ui-spec.md` become Design Source of Truth.
- Later functional/test artifacts must be synchronized to them.
