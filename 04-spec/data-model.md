# Data Model — Coloring App (Synced to Step 6 Hi‑Fi)

**Document ID:** DATA-COLOR-001  
**Version:** 0.2  
**Status:** Review Draft  

---

# 1. Sync Result

Step 6 Hi‑Fi does **not require a core persistence schema change**.

The previous core entities remain valid:

- Category
- Drawing
- Progress
- BrushStroke
- Entitlement
- RewardUnlock
- AppSettings

---

# 2. Persistent vs Session State

The Hi‑Fi Editor introduces explicit UI controls. Their state is classified as follows.

## Persisted — Required

### Progress
- drawingId
- regionColors
- brushStrokes
- status
- timestamps
- contentVersion
- schemaVersion

These are required to restore user artwork.

## Session-Only — MVP

The following do not need persistence:

```text
activeTool
activeColor
toolParameterValue
zoomScale
panOffset
selectedQuickAction
```

They may reset when Editor is reopened.

---

# 3. Optional Future Preference Persistence

If UX later requires remembering editor preferences, AppSettings may optionally include:

```json
{
  "lastTool": "FILL",
  "lastColor": "#168B2D",
  "lastBrushSize": 18
}
```

This is **not an MVP requirement**.

---

# 4. Category

```json
{
  "id": "cat_animals",
  "name": "Animals",
  "thumbnail": "categories/animals.webp",
  "displayOrder": 1,
  "isActive": true,
  "isPremium": false
}
```

---

# 5. Drawing

```json
{
  "id": "draw_animals_001",
  "title": "Little Elephant",
  "categoryId": "cat_animals",
  "thumbnail": "drawings/animals/001_thumb.webp",
  "coloringAsset": "drawings/animals/001.svg",
  "displayOrder": 1,
  "isActive": true,
  "isPremium": false,
  "rewardUnlockEligible": false,
  "contentVersion": 1,
  "featured": true
}
```

---

# 6. Progress

```json
{
  "id": "progress_draw_animals_001",
  "drawingId": "draw_animals_001",
  "status": "IN_PROGRESS",
  "regionColors": {
    "region_001": "#168B2D",
    "region_002": "#FF6D80"
  },
  "brushStrokes": [],
  "createdAt": "2026-08-14T10:00:00+07:00",
  "updatedAt": "2026-08-14T10:10:00+07:00",
  "contentVersion": 1,
  "schemaVersion": 1
}
```

---

# 7. BrushStroke

No change.

Required fields:
- id
- tool
- color
- size
- points

---

# 8. UI State Model — Runtime Only

Recommended in-memory structure:

```json
{
  "activeTool": "FILL",
  "activeColor": "#168B2D",
  "toolParameterValue": 18,
  "zoomScale": 1.0,
  "panX": 0,
  "panY": 0,
  "saveState": "SAVED"
}
```

This is not stored as Progress unless later required.

---

# 9. Content Integrity Rules

Unchanged:
- unique IDs
- valid category references
- assets exist
- version compatibility
- no automatic progress deletion on missing asset

---

# 10. Sync Conclusion

**Schema migration required:** No.

**New required field:** No.

**Optional future settings:** editor preference fields.

This file replaces the previous Step 7 data model for downstream AI context.

---

# 11. Re-Baseline Impact Assessment (2026-08-14)

**Trigger:** Approval of Library (`SCR-LIBRARY-001`), Profile (`SCR-PROFILE-001`), revised Home structure, direct-to-Coloring navigation, and revised Completion flow.

**Result: No schema change required.**

- `Drawing.categoryId` already supports Library's category filter — no new field needed.
- `Progress` (`id`, `drawingId`, `status`, `regionColors`, `brushStrokes`, `createdAt`, `updatedAt`) already supports:
  - the resume-or-create resolution rule (`FS-DISCOVERY-RESOLVE-001` in `functional-spec.md`) used by Home, Library, Profile, and Completion's "Recommended for you";
  - Profile's All / In Progress / Completed segmentation, driven entirely by `Progress.status` per `BR-PROFILE-001` — `IN_PROGRESS` and `COMPLETED` are the only two states involved, both already modeled.
- No Favorite/Bookmark entity, field, or persistence was added, per the approved decision that Favorite/Bookmark is out of MVP.
- Library and Profile are UI-layer groupings/filters over existing `Drawing` and `Progress` entities — neither introduces a new persisted entity.

**Conclusion:** `data-model.md` content is unchanged from v0.2. This section is an assessment record only, added per the update order's "only if required" instruction.
