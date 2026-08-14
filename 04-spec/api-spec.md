# API Specification — Coloring App (Synced to Step 6 Hi‑Fi)

**Document ID:** API-COLOR-001  
**Version:** 0.2  
**Status:** Review Draft / Conditional  

---

# 1. Sync Result

The Step 6 Hi‑Fi UI introduces **no new required backend API**.

The MVP remains local-first.

---

# 2. Core Architecture

```text
Hi‑Fi UI
↓
Local Repositories / App Services

ContentRepository
ProgressRepository
EntitlementRepository (conditional)
```

Core coloring does not require a custom backend.

---

# 3. Internal Content Contract

```text
getCategories()
getDrawings(categoryId?)
getDrawing(drawingId)
getFeaturedDrawings()
getDailyDrawing()  // conditional
```

Home/Category UI consumes these logical contracts.

---

# 4. Progress Contract

```text
getProgress(drawingId)
saveProgress(progress)
getInProgress()
getCompleted()
```

Editor autosave uses ProgressRepository.

---

# 5. Monetization Contract

Conditional.

Hi‑Fi Paywall does not change logical operations:

```text
loadProducts()
purchase(productId)
restorePurchases()
getEntitlement()
```

Exact price/trial text must come from configured/store product data, not from prototype placeholders.

---

# 6. Optional Content API

Still optional:

```text
GET /content/manifest
GET /content/categories.json
GET /content/drawings.json
```

Only needed for remote content updates.

---

# 7. Daily Pick

The Hi‑Fi Home shows Daily as an assumption.

If Product confirms remote Daily:
- use remote config/manifest or daily endpoint.

If not confirmed:
- Daily section may be omitted.

No API should be built only because the prototype currently shows it.

---

# 8. New UI → API Impact Table

| Hi‑Fi UI Element | Backend Needed? |
|---|---|
| Editor Tool Rail | No |
| Color Palette | No |
| Slider | No |
| Zoom/Fit | No |
| Continue Coloring | No, local progress |
| My Works | No, local progress |
| Premium CTA | Store/provider integration only |
| Daily Pick | Optional remote |
| Filters All/New/Free | No if local content metadata |

---

# 9. Backend Decision

**Dedicated backend required for MVP:** No, based on current scope.

Could be added later for:
- remote content
- cloud sync
- accounts
- community
- personalized recommendations

---

# 10. Sync Conclusion

No new HTTP endpoint is required because of the Hi‑Fi redesign.

This file replaces the previous Step 7 API spec for downstream AI context.
