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

## DD-002 — Bottom Navigation *(SUPERSEDED 2026-08-14 — see DD-010)*
Home / My Works / Settings.

**Superseded by:** Approved bottom navigation is now Home / Library / Profile. Settings is reached via Profile → Settings icon, not a root tab.

## DD-003 — Preview Screen Retained *(SUPERSEDED 2026-08-14 — see DD-013)*
A separate Preview remains in V1.

**Superseded by:** Explicit product decision — artwork tap opens Coloring directly (resume-or-create rule). `SCR-PREVIEW-001` is preserved as Legacy, not routed from the approved MVP core flow.

## DD-004 — Hybrid Editor
Fill is primary; Brush + Erase are available.

## DD-005 — Floating Tool Rail
Editor uses right-side vertical tool rail inspired by the supplied reference.

## DD-006 — Bottom Color Controls
Slider + palette + quick actions placed below canvas.

## DD-007 — Daily on Home *(SUPERSEDED 2026-08-14 — see DD-012)*
Daily remains a Home section, not a root tab.

**Superseded by:** Approved Home structure contains only repeatable category sections. Daily Pick is preserved as a legacy content block (requirement/component IDs retained), not part of the approved Home structure.

## DD-008 — Completion Screen
Dedicated completion screen retained.

**Status:** Reconfirmed 2026-08-14 — `SCR-COMPLETE-001` retained; content revised, see DD-014.

## DD-009 — Premium UI
Paywall and Premium states remain in V1 for flow validation.

## DD-010 — Library & Profile Replace Category-Tab / My-Works-Tab / Settings-Tab *(new — 2026-08-14)*
`SCR-LIBRARY-001` and `SCR-PROFILE-001` are new, distinct screens forming the approved bottom navigation alongside Home. They are not renames of `SCR-CATEGORY-001`, `SCR-WORKS-001`, or `SCR-SETTINGS-001` — those screens are preserved as Legacy/Superseded, not deleted.

## DD-011 — Library Is Discovery, Profile Is Personal *(new — 2026-08-14)*
Library = browse all artwork, filterable by category (discovery-oriented, akin to the legacy Category concept but a new screen). Profile = personal artwork (All/Completed/In Progress) + Settings entry (retention-oriented, akin to the legacy My Works concept but a new screen). This resolves the ambiguity flagged in the prior re-baseline report between these two readings of "Library."

## DD-012 — Home Is Category Sections Only *(new — 2026-08-14)*
Approved Home contains only repeatable category sections (title + See all + horizontal artwork list). No separate Featured, Daily Pick, icon-based Categories grid, or dedicated Continue Coloring block. Legacy blocks are preserved (IDs retained), not deleted.

## DD-013 — Direct-to-Coloring, No Preview Hop *(new — 2026-08-14)*
Artwork tap from Home, Library, Profile, or Completion's "Recommended for you" opens `SCR-EDITOR-001` directly, applying a resume-or-create rule. `SCR-PREVIEW-001` is preserved as Legacy.

## DD-014 — Completion Content Revised *(new — 2026-08-14)*
Completion contains: Share (native device share sheet), Save/Download (rendered image to device), Back to Home, Recommended for you (artwork cards → direct-to-Coloring). "View in My Works" and undifferentiated "Color another drawing" are superseded.

## DD-015 — No Favorite/Bookmark in MVP *(new — 2026-08-14)*
Favorite/Bookmark is explicitly out of MVP scope. No Favorite state, requirement, screen, or persistence is created. The decorative "♡" icon on the legacy `SCR-PREVIEW-001` toolbar (prototype `index.html`) is flagged **non-approved / to be removed** from any new production UI — it was never backed by a requirement or component ID.

---

# 3. Decisions Still Needing Product Approval

- Final brand colors.
- Final icon set.
- ~~Whether Preview screen stays~~ — **Resolved 2026-08-14: Legacy, not routed (DD-013).**
- Whether Brush is in MVP.
- ~~Whether Daily is MVP~~ — **Resolved 2026-08-14: Legacy, not part of approved Home structure (DD-012).**
- Final monetization model.
- Exact premium scope.
- Final audience classification.
- Fate of legacy `SCR-CATEGORY-001` / `SCR-PREVIEW-001` / `SCR-WORKS-001`: formally retire, or retain for a future non-MVP purpose? (Currently: preserved/Legacy, no retirement decision made.)

---

# 4. Design Source of Truth Rule

After V1 approval:
- HTML prototype + `ui-spec.md` become Design Source of Truth.
- Later functional/test artifacts must be synchronized to them.

**2026-08-14 update:** This re-baseline updates `ui-spec.md` and this document as the current Design Source of Truth for Home/Library/Profile/Completion. Prototype HTML/CSS/JS (`03-design/prototype/`) has **not** yet been updated to match — see `SOURCE-OF-TRUTH.md` for current sync status. Do not treat the prototype as reflecting this baseline until it is explicitly updated.
