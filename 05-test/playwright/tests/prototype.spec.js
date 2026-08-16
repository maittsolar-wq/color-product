const { test, expect } = require('@playwright/test');

async function openHome(page) {
  await page.goto('/');
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
  // Real lesson content (data/lessons.json + data/categories.json) is
  // fetched asynchronously by loadContent() in app.js — wait for it so
  // Home/Library/Search/Profile all have real cards to interact with.
  await page.waitForFunction(() => typeof LESSONS_BY_ID !== 'undefined' && Object.keys(LESSONS_BY_ID).length > 0);
}

// drawing-card-<id> and nav-* testids are intentionally reused across Home,
// Library, and Profile (all present in the DOM at once, only one visible via
// .screen.active) per selectors-contract.md. Scope to the active screen so
// locators resolve to exactly one element.
function active(page) {
  return page.locator('.screen.active');
}

async function clearProgressAndReturnHome(page) {
  await page.evaluate(() => {
    Object.keys(progressStore).forEach(id => delete progressStore[id]);
  });
  await active(page).locator('[data-testid="nav-home"]').click().catch(() => {});
  // If already on Home (e.g. right after openHome), just re-render explicitly.
  await page.evaluate(() => renderHomeContinue());
}

// Primary real-content test lessons (see 03-design/prototype/data/lessons.json).
// manga_spikyhero is the single-lesson target for Lock/Fill/Erase/Eyedropper/
// Undo/Completion coverage; manga_foxwarrior pairs with it for the
// per-lesson drawing-state isolation test. Both were manually verified to
// work against the real 800×800 artwork before this rewrite.
const LESSON_A = 'manga_spikyhero';
const LESSON_A_TITLE = 'SpikyHero';
const LESSON_B = 'manga_foxwarrior';

test('TC-HOME-004 — Continue card hidden when there is no IN_PROGRESS artwork', async ({ page }) => {
  await openHome(page);
  await clearProgressAndReturnHome(page);

  await expect(page.locator('[data-testid="continue-coloring"]')).toBeHidden();
});

test('TC-HOME-004b — COMPLETED-only artwork does not show the Continue card', async ({ page }) => {
  await openHome(page);
  await page.evaluate(() => {
    Object.keys(progressStore).forEach(id => delete progressStore[id]);
    progressStore['nature_forestpath'] = 'COMPLETED';
    renderHomeContinue();
  });

  await expect(page.locator('[data-testid="continue-coloring"]')).toBeHidden();
});

test('TC-HOME-003 — Continue card shows the single IN_PROGRESS artwork', async ({ page }) => {
  await openHome(page);
  // Default seeded state (app.js progressStore) already has exactly one
  // IN_PROGRESS record: animal_babydeer ("BabyDeer").
  const card = page.locator('[data-testid="continue-coloring"]');
  await expect(card).toBeVisible();
  await expect(card.locator('.continue-title')).toHaveText('BabyDeer');
  await expect(card).toHaveAttribute('data-artwork-id', 'animal_babydeer');
});

test('TC-HOME-003b — Continue card shows the most recently updated of multiple IN_PROGRESS artworks', async ({ page }) => {
  await openHome(page);
  // Seeded default: animal_babydeer is IN_PROGRESS. Open a second artwork
  // without completing it, then return Home — the more recently touched
  // one (manga_spikyhero) must win.
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);

  await page.locator('.editor-topbar .editor-circle').click(); // Back -> Home
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);

  const card = page.locator('[data-testid="continue-coloring"]');
  await expect(card).toBeVisible();
  await expect(card).toHaveAttribute('data-artwork-id', LESSON_A);
  await expect(card.locator('.continue-title')).toHaveText(LESSON_A_TITLE);

  const bothInProgress = await page.evaluate(() => ({
    baby: progressStore['animal_babydeer'],
    manga: progressStore['manga_spikyhero'],
  }));
  expect(bothInProgress).toEqual({ baby: 'IN_PROGRESS', manga: 'IN_PROGRESS' });
});

test('TC-HOME-CONTINUE-001 — Continue button opens the correct artwork directly, resuming progress', async ({ page }) => {
  await openHome(page);
  const card = page.locator('[data-testid="continue-coloring"]');
  await card.locator('.continue-btn').click();

  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-CATEGORY-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);

  const id = await page.evaluate(() => currentArtworkId);
  expect(id).toBe('animal_babydeer');
  const status = await page.evaluate(() => progressStore['animal_babydeer']);
  expect(status).toBe('IN_PROGRESS'); // resumed, not reset
});

test('TC-HOME-CONTINUE-002 — Clicking the card itself does the same thing as the button', async ({ page }) => {
  await openHome(page);
  const card = page.locator('[data-testid="continue-coloring"]');
  await card.click(); // click the card, not specifically the button

  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  const id = await page.evaluate(() => currentArtworkId);
  expect(id).toBe('animal_babydeer');
});

test('TC-HOME-CONTINUE-003 — PRO pill remains visible and works with the Continue card present', async ({ page }) => {
  await openHome(page);
  await expect(page.locator('[data-testid="continue-coloring"]')).toBeVisible();

  const pro = page.locator('[data-testid="premium-home"]');
  await expect(pro).toBeVisible();
  await pro.click();
  await expect(page.locator('[data-screen-id="SCR-PAYWALL-001"]')).toHaveClass(/active/);
});

for (const drawingId of ['manga_spikyhero', 'animal_babydeer', 'nature_mountainlake']) {
  test(`TC-HOME-007/008 — Home artwork (${drawingId}) opens Coloring directly (no Preview hop)`, async ({ page }) => {
    await openHome(page);

    await active(page).locator(`[data-testid="drawing-card-${drawingId}"]`).click();
    await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
    await expect(page.locator('[data-screen-id="SCR-CATEGORY-001"]')).not.toHaveClass(/active/);
    await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
    await expect(page.locator('[data-testid="coloring-canvas"]')).toBeVisible();
  });
}

for (const category of ['manga', 'animal', 'nature']) {
  test(`TC-HOME-006 — See all (${category}) opens Library with matching filter active`, async ({ page }) => {
    await openHome(page);

    await page.locator(`[data-testid="home-see-all-${category}"]`).click();
    await expect(page.locator('[data-screen-id="SCR-LIBRARY-001"]')).toHaveClass(/active/);
    await expect(page.locator(`[data-testid="library-filter-${category}"]`)).toHaveClass(/selected/);
    await expect(page.locator('[data-testid="library-grid"]')).toHaveAttribute('data-active-filter', category);
  });
}

test('TC-HOME-ROWCOUNT-001 — Each Home category row contains exactly 5 real lesson cards', async ({ page }) => {
  await openHome(page);
  for (const category of ['manga', 'animal', 'nature']) {
    const row = page.locator(`[data-testid="home-${category}-row"]`);
    await expect(row.locator('.art-card')).toHaveCount(5);
  }
});

test('TC-LIB-001 — Library entered from root bottom nav shows All active', async ({ page }) => {
  await openHome(page);

  await active(page).locator('[data-testid="nav-library"]').click();
  await expect(page.locator('[data-screen-id="SCR-LIBRARY-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-testid="library-filter-all"]')).toHaveClass(/selected/);
  await expect(page.locator('[data-testid="library-grid"]')).toHaveAttribute('data-active-filter', 'all');
});

test('TC-HOME-009 — Bottom nav routes to Library (All) and Profile', async ({ page }) => {
  await openHome(page);

  await active(page).locator('[data-testid="nav-library"]').click();
  await expect(page.locator('[data-screen-id="SCR-LIBRARY-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-testid="library-filter-all"]')).toHaveClass(/selected/);

  await active(page).locator('[data-testid="nav-home"]').click();
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);

  await active(page).locator('[data-testid="nav-profile"]').click();
  await expect(page.locator('[data-screen-id="SCR-PROFILE-001"]')).toHaveClass(/active/);
});

test('TC-LIB-004 — Library bottom nav routes to Home', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();
  await active(page).locator('[data-testid="nav-home"]').click();
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
});

test('TC-LIB-005 — Library bottom nav routes to Profile', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();
  await active(page).locator('[data-testid="nav-profile"]').click();
  await expect(page.locator('[data-screen-id="SCR-PROFILE-001"]')).toHaveClass(/active/);
});

const LIBRARY_CARDS_BY_CATEGORY = {
  all: null,
  animal: 'animal_babydeer',
  food: 'food_berrycupcake',
  manga: 'manga_spikyhero',
  nature: 'nature_mountainlake',
  dumpling: 'dumpling_dimsumbowl',
};

for (const category of ['animal', 'food', 'manga', 'nature', 'dumpling']) {
  test(`TC-LIB-002 — Library filter (${category}) shows only matching artwork`, async ({ page }) => {
    await openHome(page);
    await active(page).locator('[data-testid="nav-library"]').click();

    await page.locator(`[data-testid="library-filter-${category}"]`).click();
    await expect(page.locator(`[data-testid="library-filter-${category}"]`)).toHaveClass(/selected/);
    await expect(page.locator('[data-testid="library-grid"]')).toHaveAttribute('data-active-filter', category);

    for (const [otherCategory, cardId] of Object.entries(LIBRARY_CARDS_BY_CATEGORY)) {
      if (!cardId) continue;
      const card = active(page).locator(`[data-testid="drawing-card-${cardId}"]`);
      if (otherCategory === category) {
        await expect(card).toBeVisible();
      } else {
        await expect(card).toBeHidden();
      }
    }
  });
}

test('TC-LIB-COUNT-001 — Library "All" filter shows exactly 25 cards', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();

  const cards = active(page).locator('[data-testid="library-grid"] .drawing-card');
  await expect(cards).toHaveCount(25);
});

for (const category of ['animal', 'food', 'manga', 'nature', 'dumpling']) {
  test(`TC-LIB-COUNT-002 — Library filter (${category}) shows exactly 5 visible cards`, async ({ page }) => {
    await openHome(page);
    await active(page).locator('[data-testid="nav-library"]').click();
    await page.locator(`[data-testid="library-filter-${category}"]`).click();

    const visibleCards = active(page).locator('[data-testid="library-grid"] .drawing-card:visible');
    await expect(visibleCards).toHaveCount(5);
  });
}

// Drags a horizontal row from its right edge toward its left edge with real
// Pointer Events (not a programmatic scrollLeft assignment), matching how a
// user actually drags/swipes — exercises the app's own drag-scroll handler.
async function dragRowLeft(page, testid) {
  const box = await page.locator(`[data-testid="${testid}"]`).boundingBox();
  await page.mouse.move(box.x + box.width - 20, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.move(box.x + 20, box.y + box.height / 2, { steps: 10 });
  await page.mouse.up();
}

// Repeats real drag/swipe gestures (never a programmatic scrollLeft jump)
// until the row hits its max scroll extent or stops making progress — a
// single continuous synthetic drag reliably advances the row only a modest
// amount per gesture (observed and reproduced independently of this suite),
// the same way a real user would need more than one swipe to get all the
// way across a long row. Real Pointer Events end to end throughout.
async function dragRowLeftUntilMaxScroll(page, testid, maxAttempts = 15) {
  const row = page.locator(`[data-testid="${testid}"]`);
  let previous = -1;
  for (let i = 0; i < maxAttempts; i++) {
    await dragRowLeft(page, testid);
    const info = await row.evaluate(el => ({ scrollLeft: el.scrollLeft, max: el.scrollWidth - el.clientWidth }));
    if (info.scrollLeft >= info.max - 1) break; // reached the end
    if (info.scrollLeft === previous) break; // no further progress possible
    previous = info.scrollLeft;
  }
}

test('TC-HOME-010 — Manga row can be horizontally drag-scrolled to fully reveal the 5th (last) artwork', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 812 }); // narrower than the suite default (430) — this is exactly where the row overflows and the bug was reported
  await openHome(page);
  const row = page.locator('[data-testid="home-manga-row"]');
  await expect(row.locator('.art-card')).toHaveCount(5); // all 5 manga lessons are in the DOM, not just the first N that fit

  const overflow = await row.evaluate(el => el.scrollWidth - el.clientWidth);
  expect(overflow).toBeGreaterThan(0); // confirms the row genuinely overflows in this viewport

  await dragRowLeftUntilMaxScroll(page, 'home-manga-row');
  const scrollLeftAfter = await row.evaluate(el => el.scrollLeft);
  expect(scrollLeftAfter).toBeGreaterThan(0);

  // manga_sweetgirl has sortOrder 5 — the last card in the row.
  const lastCard = row.locator('[data-testid="drawing-card-manga_sweetgirl"]');
  const rowBox = await row.boundingBox();
  const cardBox = await lastCard.boundingBox();
  expect(cardBox.x).toBeGreaterThanOrEqual(rowBox.x - 1);
  expect(cardBox.x + cardBox.width).toBeLessThanOrEqual(rowBox.x + rowBox.width + 1); // fully within the visible row, not clipped

  // A drag must not have been misread as a tap that opens the artwork.
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);

  // A real tap still opens it normally, and opens the EXACT lesson tapped.
  await lastCard.click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  const id = await page.evaluate(() => currentArtworkId);
  expect(id).toBe('manga_sweetgirl');
});

test('TC-LIB-006 — Library filter row can be horizontally drag-scrolled to fully reveal Nature, and filtering still works', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 812 }); // narrower than the suite default (430) — this is exactly where the row overflows and the bug was reported
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();

  const row = page.locator('[data-testid="library-filters"]');
  const overflow = await row.evaluate(el => el.scrollWidth - el.clientWidth);
  expect(overflow).toBeGreaterThan(0);

  await dragRowLeft(page, 'library-filters');
  const scrollLeftAfter = await row.evaluate(el => el.scrollLeft);
  expect(scrollLeftAfter).toBeGreaterThan(0);

  const natureChip = page.locator('[data-testid="library-filter-nature"]');
  const rowBox = await row.boundingBox();
  const chipBox = await natureChip.boundingBox();
  expect(chipBox.x + chipBox.width).toBeLessThanOrEqual(rowBox.x + rowBox.width + 1); // fully visible, not clipped

  // The drag must not have been misread as selecting a filter mid-drag.
  await expect(page.locator('[data-testid="library-filter-all"]')).toHaveClass(/selected/);

  await natureChip.click();
  await expect(natureChip).toHaveClass(/selected/);
  await expect(page.locator('[data-testid="library-grid"]')).toHaveAttribute('data-active-filter', 'nature');
});

test('TC-LIB-002b — Library "All" filter shows every category again', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();

  await page.locator('[data-testid="library-filter-food"]').click();
  await page.locator('[data-testid="library-filter-all"]').click();

  for (const cardId of Object.values(LIBRARY_CARDS_BY_CATEGORY)) {
    if (!cardId) continue;
    await expect(active(page).locator(`[data-testid="drawing-card-${cardId}"]`)).toBeVisible();
  }
});

test('TC-LIB-003 — Library artwork opens Coloring directly (no Preview/Category hop)', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();

  await active(page).locator('[data-testid="drawing-card-food_croissantbreakfast"]').click();
  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-CATEGORY-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-testid="coloring-canvas"]')).toBeVisible();
});

test('TC-LIB-OPEN-EXACT-001 — Library card click opens the EXACT lesson clicked, not just any lesson', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();

  await active(page).locator('[data-testid="drawing-card-dumpling_dumplingtea"]').click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  const id = await page.evaluate(() => currentArtworkId);
  expect(id).toBe('dumpling_dumplingtea');
});

test('TC-HOME-OPEN-EXACT-001 — Home card click opens the EXACT lesson clicked, not just any lesson', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-manga_happybraids"]').click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  const id = await page.evaluate(() => currentArtworkId);
  expect(id).toBe('manga_happybraids');
});

test('TC-SEARCH-001 — Library Search icon opens Search', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();

  await active(page).locator('[data-testid="library-search"]').click();
  await expect(page.locator('[data-screen-id="SCR-SEARCH-001"]')).toHaveClass(/active/);
});

test('TC-SEARCH-002 — Search default state shows no grid and no empty state', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();
  await active(page).locator('[data-testid="library-search"]').click();

  await expect(active(page).locator('[data-testid="search-input"]')).toHaveValue('');
  await expect(active(page).locator('[data-testid="search-results-grid"]')).toBeHidden();
  await expect(active(page).locator('[data-testid="search-empty-state"]')).toBeHidden();
  await expect(active(page).locator('[data-testid="search-clear"]')).toBeHidden();
});

test('TC-SEARCH-003 — Query with matching artwork shows results grid (case-insensitive)', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();
  await active(page).locator('[data-testid="library-search"]').click();

  await active(page).locator('[data-testid="search-input"]').fill('SPIKY');
  await expect(active(page).locator('[data-testid="search-results-grid"]')).toBeVisible();
  await expect(active(page).locator('[data-testid="search-empty-state"]')).toBeHidden();
  await expect(active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`)).toBeVisible();
});

test('TC-SEARCH-004 — Query with no match shows empty state, not an empty grid', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();
  await active(page).locator('[data-testid="library-search"]').click();

  await active(page).locator('[data-testid="search-input"]').fill('zzzznotarealtitle');
  await expect(active(page).locator('[data-testid="search-empty-state"]')).toBeVisible();
  await expect(active(page).locator('[data-testid="search-results-grid"]')).toBeHidden();
});

test('TC-SEARCH-005 — Clear X returns Search to default state', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();
  await active(page).locator('[data-testid="library-search"]').click();

  await active(page).locator('[data-testid="search-input"]').fill('spiky');
  await expect(active(page).locator('[data-testid="search-clear"]')).toBeVisible();

  await active(page).locator('[data-testid="search-clear"]').click();
  await expect(active(page).locator('[data-testid="search-input"]')).toHaveValue('');
  await expect(active(page).locator('[data-testid="search-results-grid"]')).toBeHidden();
  await expect(active(page).locator('[data-testid="search-empty-state"]')).toBeHidden();
});

test('TC-SEARCH-006 — Search result opens Coloring directly (resume-or-create)', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();
  await active(page).locator('[data-testid="library-search"]').click();

  // "Fox" matches exactly FoxWarrior, which has no seeded progress — a
  // genuinely fresh creation, unlike animal_babydeer/nature_mountainlake
  // which are pre-seeded in app.js.
  await active(page).locator('[data-testid="search-input"]').fill('Fox');
  await active(page).locator(`[data-testid="drawing-card-${LESSON_B}"]`).click();

  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-CATEGORY-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  const status = await page.evaluate(() => progressStore['manga_foxwarrior']);
  expect(status).toBe('IN_PROGRESS'); // created fresh — no prior progress existed
});

test('TC-SEARCH-007 — Back preserves the previous Library filter', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();
  await active(page).locator('[data-testid="library-filter-manga"]').click();

  await active(page).locator('[data-testid="library-search"]').click();
  await expect(page.locator('[data-screen-id="SCR-SEARCH-001"]')).toHaveClass(/active/);

  await active(page).locator('[data-testid="search-back"]').click();
  await expect(page.locator('[data-screen-id="SCR-LIBRARY-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-testid="library-filter-manga"]')).toHaveClass(/selected/);
  await expect(page.locator('[data-testid="library-grid"]')).toHaveAttribute('data-active-filter', 'manga');
});

test('TC-SEARCH-008 — No-results Explore library opens Library with All active (not the prior filter)', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();
  await active(page).locator('[data-testid="library-filter-manga"]').click();

  await active(page).locator('[data-testid="library-search"]').click();
  await active(page).locator('[data-testid="search-input"]').fill('zzzznotarealtitle');
  await active(page).locator('[data-testid="search-explore-library"]').click();

  await expect(page.locator('[data-screen-id="SCR-LIBRARY-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-testid="library-filter-all"]')).toHaveClass(/selected/);
  await expect(page.locator('[data-testid="library-grid"]')).toHaveAttribute('data-active-filter', 'all');
});

test('TC-SEARCH-009 — Search has no bottom navigation', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();
  await active(page).locator('[data-testid="library-search"]').click();
  await expect(active(page).locator('.bottom-nav')).toHaveCount(0);
});

// Case-insensitive substring matching against lesson.title only (REQ-LIB-009)
// — see data/lessons.json for the real 25-lesson dataset these are computed
// against, not guessed.
async function searchResultIds(page, query) {
  await active(page).locator('[data-testid="nav-library"]').click();
  await active(page).locator('[data-testid="library-search"]').click();
  await active(page).locator('[data-testid="search-input"]').fill(query);
  const cards = active(page).locator('[data-testid="search-results-grid"] .drawing-card');
  return cards.evaluateAll(els => els.map(el => el.dataset.testid.replace('drawing-card-', '')));
}

test('TC-SEARCH-CONTENT-001 — "deer" matches exactly BabyDeer (animal_babydeer)', async ({ page }) => {
  await openHome(page);
  const ids = await searchResultIds(page, 'deer');
  expect(ids.sort()).toEqual(['animal_babydeer']);
});

test('TC-SEARCH-CONTENT-002 — "water" matches WaterfallCliff and TropicalWaterfall only', async ({ page }) => {
  await openHome(page);
  const ids = await searchResultIds(page, 'water');
  expect(ids.sort()).toEqual(['nature_tropicalwaterfall', 'nature_waterfallcliff']);
});

test('TC-SEARCH-CONTENT-003 — "dump" matches the 4 Dumpling titles containing it, excluding DimSumBowl', async ({ page }) => {
  await openHome(page);
  const ids = await searchResultIds(page, 'dump');
  // DimSumBowl's title ("DimSumBowl") does not contain the substring "dump" —
  // only the other 4 Dumpling lessons' titles do.
  expect(ids.sort()).toEqual([
    'dumpling_dumplingbaskets',
    'dumpling_dumplingparty',
    'dumpling_dumplingtea',
    'dumpling_steameddumplings',
  ]);
});

// Profile boots with two seeded progress records (animal_babydeer =
// IN_PROGRESS, nature_mountainlake = COMPLETED) so the default app state is
// "populated." To exercise the empty state, tests clear progressStore via
// the app's own global (its single source of truth for progress) and call
// the existing openProfile()/renderProfile() to re-render — no test-only
// hook or second data store is introduced.
async function clearProgress(page) {
  await page.evaluate(() => {
    Object.keys(progressStore).forEach(id => delete progressStore[id]);
  });
}

test('TC-PROFILE-001 — Empty Profile shows the empty state, not the grid', async ({ page }) => {
  await openHome(page);
  await clearProgress(page);
  await active(page).locator('[data-testid="nav-profile"]').click();

  await expect(page.locator('[data-testid="profile-empty-state"]')).toBeVisible();
  await expect(page.locator('[data-testid="profile-segmented"]')).toBeHidden();
  await expect(page.locator('[data-testid="profile-grid"]')).toBeHidden();
});

test('TC-PROFILE-001b — Explore library from empty Profile opens Library with All active', async ({ page }) => {
  await openHome(page);
  await clearProgress(page);
  await active(page).locator('[data-testid="nav-profile"]').click();

  await page.locator('[data-testid="profile-explore-library"]').click();
  await expect(page.locator('[data-screen-id="SCR-LIBRARY-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-testid="library-filter-all"]')).toHaveClass(/selected/);
});

test('TC-PROFILE-002 — Populated Profile defaults to All (both statuses)', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();

  await expect(page.locator('[data-testid="profile-empty-state"]')).toBeHidden();
  await expect(page.locator('[data-testid="profile-segment-all"]')).toHaveClass(/selected/);
  await expect(active(page).locator('[data-testid="drawing-card-animal_babydeer"]')).toBeVisible();
  await expect(active(page).locator('[data-testid="drawing-card-nature_mountainlake"]')).toBeVisible();
});

test('TC-PROFILE-003 — Completed segment shows only COMPLETED artwork', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();

  await page.locator('[data-testid="profile-segment-completed"]').click();
  await expect(active(page).locator('[data-testid="drawing-card-nature_mountainlake"]')).toBeVisible();
  await expect(active(page).locator('[data-testid="drawing-card-animal_babydeer"]')).toBeHidden();
});

test('TC-PROFILE-004 — In Progress segment shows only IN_PROGRESS artwork', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();

  await page.locator('[data-testid="profile-segment-in-progress"]').click();
  await expect(active(page).locator('[data-testid="drawing-card-animal_babydeer"]')).toBeVisible();
  await expect(active(page).locator('[data-testid="drawing-card-nature_mountainlake"]')).toBeHidden();
});

test('TC-PROFILE-004b — Switching segments does not change artwork status', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();

  await page.locator('[data-testid="profile-segment-in-progress"]').click();
  await page.locator('[data-testid="profile-segment-all"]').click();

  const stillCorrect = await page.evaluate(() => ({
    baby: progressStore['animal_babydeer'],
    mountain: progressStore['nature_mountainlake'],
  }));
  expect(stillCorrect).toEqual({ baby: 'IN_PROGRESS', mountain: 'COMPLETED' });
});

test('TC-PROFILE-005 — Profile artwork opens the Artwork Detail Popup, and Color resumes existing progress (not a fresh session)', async ({ page }) => {
  // Updated 2026-08-16 for the final prototype functional pass: a Profile
  // card tap now opens the Profile Artwork Detail Popup instead of jumping
  // straight to Editor (see the "IV. Profile Artwork Detail Popup" describe
  // block below for full coverage of the popup itself) — Color is the path
  // that reaches Editor from Profile now. Home/Library remain direct, per
  // TC-PROFILE-POPUP-006 below.
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();

  await active(page).locator('[data-testid="drawing-card-nature_mountainlake"]').click();
  await expect(page.locator('[data-testid="profile-artwork-popup"]')).toBeVisible();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).not.toHaveClass(/active/);

  await page.locator('[data-testid="profile-popup-color"]').click();
  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-CATEGORY-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);

  const status = await page.evaluate(() => progressStore['nature_mountainlake']);
  expect(status).toBe('COMPLETED'); // resumed, not reset to a fresh session
});

test('TC-PROFILE-006 — Settings icon opens Settings', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();
  await page.locator('[data-testid="profile-settings-icon"]').click();
  await expect(page.locator('[data-screen-id="SCR-SETTINGS-001"]')).toHaveClass(/active/);
});

test('TC-PROFILE-007 — Profile bottom nav routes to Home and Library', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();

  await active(page).locator('[data-testid="nav-library"]').click();
  await expect(page.locator('[data-screen-id="SCR-LIBRARY-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-testid="library-filter-all"]')).toHaveClass(/selected/);

  await active(page).locator('[data-testid="nav-profile"]').click();
  await active(page).locator('[data-testid="nav-home"]').click();
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
});

test('TC-EDITOR-016/017/018 — Tool rail selection', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

  const brush = page.locator('[data-testid="tool-brush"]');
  const fill = page.locator('[data-testid="tool-fill"]');
  const erase = page.locator('[data-testid="tool-erase"]');

  await brush.click();
  await expect(brush).toHaveClass(/selected/);

  await fill.click();
  await expect(fill).toHaveClass(/selected/);

  await erase.click();
  await expect(erase).toHaveClass(/selected/);
});

test('TC-EDITOR-020 — Palette selection', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

  const pink = page.locator('[data-testid="palette-color-pink"]');
  await pink.click();
  await expect(pink).toHaveClass(/selected/);
});

// --- Editor region-engine test helpers -------------------------------------
// Real lesson artwork is a real 800×800 PNG (see data/lessons.json) — there
// is no fixed shape/geometry to hardcode pixel constants for anymore (unlike
// the old fake 360×360 elephant SVG). Tests instead derive real paintable/
// fillable/barrier points empirically at RUN TIME by scanning the in-page
// barrierMask — the exact same Uint8Array the app's own flood-fill region
// engine uses (see loadLessonArtwork()/floodFillMaskFrom() in app.js) — the
// same technique used to manually verify this app before writing these
// tests. This keeps the suite resolution-independent and correct regardless
// of which lesson is open or how its artwork is drawn.

async function waitForBarrierMask(page) {
  await page.waitForFunction(() => typeof barrierMaskReady === 'boolean' && barrierMaskReady === true, { timeout: 10000 });
}

// Converts an artwork-space (0..ARTWORK_SIZE, the artwork's own native
// 800×800 coordinate system) point into real screen coordinates via
// #brushCanvas's current bounding box, and drives real Pointer Events —
// never a synthetic DOM mutation — so the actual shared region-mask engine
// runs end to end. Resolution-independent: works regardless of viewport size.
async function artPoint(page, x, y) {
  const box = await page.locator('#brushCanvas').boundingBox();
  return { sx: box.x + (x / 800) * box.width, sy: box.y + (y / 800) * box.height };
}

async function tapInArtwork(page, x, y) {
  const p = await artPoint(page, x, y);
  await page.mouse.click(p.sx, p.sy);
}

// Drags a real Pointer Events stroke between two artwork-space points (never
// a synthetic DOM mutation) so the prototype's actual
// pointerdown/pointermove/pointerup engine runs end to end.
async function dragOnArtboard(page, from, to) {
  const start = await artPoint(page, from.x, from.y);
  const end = await artPoint(page, to.x, to.y);
  await page.mouse.move(start.sx, start.sy);
  await page.mouse.down();
  await page.mouse.move((start.sx + end.sx) / 2, (start.sy + end.sy) / 2, { steps: 5 });
  await page.mouse.move(end.sx, end.sy, { steps: 5 });
  await page.mouse.up();
}

// Scans a bounding box of the CURRENT lesson's barrierMask (must be called
// after waitForBarrierMask) in row-major order for the first pixel matching
// the requested kind — non-barrier/paintable by default, or a barrier/line
// pixel when invert is true (used by "tapping a line is a no-op" cases).
async function findArtPoint(page, { xMin = 0, xMax = 800, yMin = 0, yMax = 800, step = 2, invert = false } = {}) {
  return page.evaluate(({ xMin, xMax, yMin, yMax, step, invert }) => {
    for (let y = yMin; y < yMax; y += step) {
      for (let x = xMin; x < xMax; x += step) {
        const isBarrier = !!barrierMask[y * ARTWORK_SIZE + x];
        if (invert ? isBarrier : !isBarrier) return { x, y };
      }
    }
    return null;
  }, { xMin, xMax, yMin, yMax, step, invert });
}

// Finds a point within `radius` of (fromX, fromY) that is in the SAME
// connected region — via an in-page 4-directional BFS flood fill over the
// same barrierMask the app's own region engine uses (mirrors
// floodFillMaskFrom() in app.js, but read-only/test-local, never touches app
// state) — i.e. a real, valid second endpoint for a Brush/Erase drag stroke
// that is guaranteed to stay inside one region, without assuming any fixed
// shape/geometry.
async function findFarthestPointInSameRegion(page, fromX, fromY, radius = 150) {
  return page.evaluate(({ fromX, fromY, radius }) => {
    const w = ARTWORK_SIZE, h = ARTWORK_SIZE;
    const visited = new Uint8Array(w * h);
    const stack = [[fromX, fromY]];
    visited[fromY * w + fromX] = 1;
    while (stack.length) {
      const [cx, cy] = stack.pop();
      for (const [nx, ny] of [[cx + 1, cy], [cx - 1, cy], [cx, cy + 1], [cx, cy - 1]]) {
        if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
        const idx = ny * w + nx;
        if (visited[idx] || barrierMask[idx]) continue;
        visited[idx] = 1;
        stack.push([nx, ny]);
      }
    }
    const xMin = Math.max(0, fromX - radius), xMax = Math.min(w, fromX + radius);
    const yMin = Math.max(0, fromY - radius), yMax = Math.min(h, fromY + radius);
    let best = null, bestDist = -1;
    for (let y = yMin; y < yMax; y += 3) {
      for (let x = xMin; x < xMax; x += 3) {
        const idx = y * w + x;
        if (!visited[idx]) continue;
        const d = (x - fromX) ** 2 + (y - fromY) ** 2;
        if (d > bestDist) { bestDist = d; best = { x, y }; }
      }
    }
    return best || { x: fromX, y: fromY };
  }, { fromX, fromY, radius });
}

// One calibration per open lesson: `interior` is a real point inside the
// subject's linework, `interiorFar` is a second point in that SAME region
// far enough away for a real drag stroke, `background` is the connected
// white background near a corner (also a valid paintable region per the
// app's own region engine — see TC-EDITOR-LOCK-006), and `barrier` is a
// line/ink pixel (for "no-op on a line" cases). Must be called after
// waitForBarrierMask(page). Verified empirically against manga_spikyhero and
// manga_foxwarrior before this suite was written.
//
// `background` is nudged a little way INTO its connected region from the
// literal geometric corner pixel scanned first (findFarthestPointInSameRegion
// over a small 60px radius) rather than used raw. Reason (found while writing
// the "final prototype functional pass" coverage below): #artboard has a
// real, pre-existing 6px CSS border-radius, and the artwork now renders at a
// true 100% of #artboard (the approved full-background-fill fix, previously
// 92% with an inset margin). That means the literal corner pixel of the
// artwork now coincides with #artboard's own rounded-off corner, which
// elementFromPoint()/real clicks cannot land on — confirmed directly via
// document.elementsFromPoint() at that exact coordinate, which resolves to
// the parent .editor-workspace, never the canvas. This affects real user
// clicks at that exact single-pixel corner identically, not just this test
// suite; it's an inherent, ~6px-radius side effect of a rounded container
// clipping its own exact geometric corner, not a defect in the flood-fill
// fix itself (flood fill still reaches the TRUE 800×800 edges perfectly once
// started from anywhere else in the same connected region — see
// TC-EDITOR-FILLBG-EDGE-001). Nudging a modest, still genuinely "near a
// corner" amount into the region sidesteps the dead zone without changing
// what `background` represents for any existing consumer of this helper.
async function calibrateLesson(page) {
  const interior = await findArtPoint(page, { xMin: 200, xMax: 600, yMin: 200, yMax: 600, step: 2 });
  const interiorFar = await findFarthestPointInSameRegion(page, interior.x, interior.y, 150);
  const backgroundCorner = await findArtPoint(page, { xMin: 0, xMax: 80, yMin: 0, yMax: 80, step: 1 });
  const background = await findFarthestPointInSameRegion(page, backgroundCorner.x, backgroundCorner.y, 60);
  const barrier = await findArtPoint(page, { xMin: 200, xMax: 600, yMin: 200, yMax: 600, step: 2, invert: true });
  return { interior, interiorFar, background, barrier };
}

// Reads one pixel's RGBA from a canvas layer (fillCanvas/brushCanvas) at a
// given artwork-space (0..800) coordinate.
async function readCanvasPixel(page, testid, x, y) {
  return page.evaluate(({ testid, x, y }) => {
    const canvas = document.querySelector(`[data-testid="${testid}"]`);
    const d = canvas.getContext('2d').getImageData(Math.round(x), Math.round(y), 1, 1).data;
    return { r: d[0], g: d[1], b: d[2], a: d[3] };
  }, { testid, x, y });
}

async function canvasDataURL(page, elementId) {
  return page.evaluate((id) => document.getElementById(id).toDataURL(), elementId);
}

test('TC-EDITOR-ARTWORK-001 — Real 800×800 line art renders with opaque ink pixels', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);

  const hasInk = await page.evaluate(() => {
    const ctx = document.getElementById('lineArtCanvas').getContext('2d');
    const data = ctx.getImageData(0, 0, ARTWORK_SIZE, ARTWORK_SIZE).data;
    for (let i = 3; i < data.length; i += 4 * 37) { // sample every 37th pixel for speed
      if (data[i] > 0) return true; // alpha > 0 == real ink drawn
    }
    return false;
  });
  expect(hasInk).toBe(true);
});

test('TC-EDITOR-022 — Palette selection does not immediately modify artwork', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior } = await calibrateLesson(page);

  const before = await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y);

  await page.locator('[data-testid="palette-color-pink"]').click();
  const after = await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y);
  expect(after).toEqual(before); // still untouched — nothing filled yet
  await expect(page.locator('[data-testid="editor-active-color"]')).toHaveAttribute('data-active-color', '#FF6D80');
});

async function pickHueAtRightEdge(page) {
  const ring = await page.locator('#hueRingWrap').boundingBox();
  await page.mouse.click(ring.x + ring.width / 2 + ring.width * 0.4, ring.y + ring.height / 2);
}

test('TC-EDITOR-COLORPICKER-001 — Playful opens the Color Picker as a sheet over the Editor, not a new screen', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

  await expect(page.locator('[data-testid="color-picker-overlay"]')).toBeHidden();
  await page.locator('.playful').click();

  await expect(page.locator('[data-testid="color-picker-overlay"]')).toBeVisible();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/); // still the same screen
  await expect(page.locator('[data-testid="editor-tool-state"]')).toBeVisible(); // Editor behind it is still present
});

test('TC-EDITOR-COLORPICKER-002 — Picking a hue updates the draft/preview live but not activeColor', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  const before = await page.evaluate(() => activeColor);

  await page.locator('.playful').click();
  await pickHueAtRightEdge(page);

  const draft = await page.evaluate(() => pickerState.draftColor);
  const stillActive = await page.evaluate(() => activeColor);
  expect(draft).not.toBe(before);
  expect(stillActive).toBe(before); // Editor's activeColor is untouched while the sheet is open
});

test('TC-EDITOR-COLORPICKER-003 — Back discards the draft and preserves the original color', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  const original = await page.evaluate(() => activeColor);

  await page.locator('.playful').click();
  await pickHueAtRightEdge(page);
  await page.locator('[data-testid="color-picker-back"]').click();

  await expect(page.locator('[data-testid="color-picker-overlay"]')).toBeHidden();
  const after = await page.evaluate(() => activeColor);
  expect(after).toBe(original);
});

test('TC-EDITOR-COLORPICKER-004/005 — Save commits the draft to activeColor and new strokes use it', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior } = await calibrateLesson(page);
  const original = await page.evaluate(() => activeColor);

  await page.locator('.playful').click();
  await pickHueAtRightEdge(page);
  const draft = await page.evaluate(() => pickerState.draftColor);
  await page.locator('[data-testid="color-picker-save"]').click();

  await expect(page.locator('[data-testid="color-picker-overlay"]')).toBeHidden();
  const committed = await page.evaluate(() => activeColor);
  expect(committed).toBe(draft);
  expect(committed).not.toBe(original);

  const p = await artPoint(page, interior.x, interior.y);
  await page.mouse.move(p.sx, p.sy);
  await page.mouse.down();
  await page.mouse.up();
  const strokeColor = await page.evaluate(() => strokesList[strokesList.length - 1].color);
  expect(strokeColor.toUpperCase()).toBe(committed);
});

test('TC-EDITOR-COLORPICKER-006 — Draft-only color changes do not create Undo history', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

  await page.locator('.playful').click();
  await pickHueAtRightEdge(page);
  await pickHueAtRightEdge(page);
  await page.locator('[data-testid="color-picker-save"]').click();

  const undoCount = await page.evaluate(() => undoStack.length);
  expect(undoCount).toBe(0); // choosing/saving a color alone never touches artwork history
  await expect(page.locator('[data-testid="undo"]')).toBeDisabled();
});

test('TC-EDITOR-COLORPICKER-007 — Save always replaces + focuses the right-most custom slot, even if it matches a preset', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

  await page.locator('[data-testid="palette-color-pink"]').click();
  await expect(page.locator('[data-testid="palette-color-pink"]')).toHaveClass(/selected/);

  await page.locator('.playful').click();
  await pickHueAtRightEdge(page);
  const draft = await page.evaluate(() => pickerState.draftColor);
  await page.locator('[data-testid="color-picker-save"]').click();

  const customBtn = page.locator('[data-testid="palette-color-custom"]');
  await expect(customBtn).toHaveAttribute('data-color', draft);
  await expect(customBtn).toHaveClass(/selected/);
  await expect(page.locator('[data-testid="palette-color-pink"]')).not.toHaveClass(/selected/); // no unrelated preset falsely highlighted

  const selectedCount = await page.evaluate(() => document.querySelectorAll('.palette .color.selected').length);
  expect(selectedCount).toBe(1); // exactly one focused swatch at a time
});

test('TC-EDITOR-COLORPICKER-008 — Save scrolls the custom slot into view, not just marks it selected off-screen', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

  const paletteOverflow = await page.locator('.palette').evaluate(el => el.scrollWidth - el.clientWidth);
  expect(paletteOverflow).toBeGreaterThan(0); // confirms the palette genuinely scrolls in this viewport

  await page.locator('.playful').click();
  await pickHueAtRightEdge(page);
  await page.locator('[data-testid="color-picker-save"]').click();
  await page.waitForTimeout(400); // smooth scrollIntoView

  const inView = await page.evaluate(() => {
    const row = document.querySelector('.palette');
    const custom = document.querySelector('[data-testid="palette-color-custom"]');
    const rowRect = row.getBoundingClientRect();
    const customRect = custom.getBoundingClientRect();
    return customRect.left >= rowRect.left - 1 && customRect.right <= rowRect.right + 1;
  });
  expect(inView).toBe(true);
});

test('TC-EDITOR-PLAYFUL-BACK-001 — Back discards the draft without touching the custom slot or activeColor', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

  await page.locator('.playful').click();
  await pickHueAtRightEdge(page);
  await page.locator('[data-testid="color-picker-save"]').click();
  const savedHex = await page.evaluate(() => activeColor);
  const customColorAfterSave = await page.locator('[data-testid="palette-color-custom"]').getAttribute('data-color');

  await page.locator('.playful').click();
  await page.mouse.click((await page.locator('#hueRingWrap').boundingBox()).x + 5, (await page.locator('#hueRingWrap').boundingBox()).y + 5); // a different hue
  await page.locator('[data-testid="color-picker-back"]').click();

  expect(await page.evaluate(() => activeColor)).toBe(savedHex);
  await expect(page.locator('[data-testid="palette-color-custom"]')).toHaveAttribute('data-color', customColorAfterSave);
  await expect(page.locator('[data-testid="palette-color-custom"]')).toHaveClass(/selected/);
});

test('TC-EDITOR-PLAYFUL-NAV-001 — Previous/Next step through the full palette (presets + custom slot) with wraparound', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

  await page.locator('[data-testid="palette-color-blue"]').click();
  await page.locator('[data-testid="editor-color-prev"]').click();
  await expect(page.locator('[data-testid="palette-color-pink"]')).toHaveClass(/selected/);
  expect(await page.evaluate(() => activeColor)).toBe('#FF6D80');

  await page.locator('[data-testid="editor-color-next"]').click();
  await page.locator('[data-testid="editor-color-next"]').click();
  await expect(page.locator('[data-testid="palette-color-purple"]')).toHaveClass(/selected/);
  expect(await page.evaluate(() => activeColor)).toBe('#C34AD8');

  // Wrap at the start: green is the first swatch — Previous should wrap to the
  // LAST swatch, which is now always the custom slot (it's no longer hidden).
  await page.locator('[data-testid="palette-color-green"]').click();
  await page.locator('[data-testid="editor-color-prev"]').click();
  await expect(page.locator('[data-testid="palette-color-custom"]')).toHaveClass(/selected/);
});

test('TC-EDITOR-EYEDROPPER-001 — Drag-to-sample shows a live magnifier and updates as it moves', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior, background } = await calibrateLesson(page);

  await page.locator('[data-testid="tool-fill"]').click();
  await page.locator('[data-testid="palette-color-purple"]').click();
  await tapInArtwork(page, interior.x, interior.y); // fill the interior region purple
  await page.locator('[data-testid="palette-color-green"]').click(); // move activeColor away

  await page.locator('[data-testid="editor-eyedropper"]').click();
  const filledPt = await artPoint(page, interior.x, interior.y);
  await page.mouse.move(filledPt.sx, filledPt.sy);
  await page.mouse.down();
  await expect(page.locator('[data-testid="eyedropper-magnifier"]')).toBeVisible();
  const colorOnFilled = await page.locator('[data-testid="eyedropper-magnifier"]').evaluate(el => el.style.background);

  const unfilledPt = await artPoint(page, background.x, background.y); // white/unfilled background area
  await page.mouse.move(unfilledPt.sx, unfilledPt.sy, { steps: 4 });
  const colorOnUnfilled = await page.locator('[data-testid="eyedropper-magnifier"]').evaluate(el => el.style.background);
  expect(colorOnUnfilled).not.toBe(colorOnFilled); // live-updates while dragging

  await page.mouse.up();
});

test('TC-EDITOR-EYEDROPPER-002 — Release commits the sample to the right-most custom slot and restores the previous tool', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior } = await calibrateLesson(page);

  await page.locator('[data-testid="tool-fill"]').click();
  await page.locator('[data-testid="palette-color-purple"]').click();
  await tapInArtwork(page, interior.x, interior.y);
  await page.locator('[data-testid="palette-color-green"]').click();

  await page.locator('[data-testid="editor-eyedropper"]').click();
  const filledPt = await artPoint(page, interior.x, interior.y);
  await page.mouse.move(filledPt.sx, filledPt.sy);
  await page.mouse.down();
  await page.mouse.up();

  expect(await page.evaluate(() => activeColor)).toBe('#C34AD8');
  const customBtn = page.locator('[data-testid="palette-color-custom"]');
  await expect(customBtn).toHaveAttribute('data-color', '#C34AD8');
  await expect(customBtn).toHaveClass(/selected/);
  await expect(page.locator('[data-testid="eyedropper-magnifier"]')).toBeHidden();
  await expect(page.locator('[data-testid="tool-fill"]')).toHaveClass(/selected/); // previous tool restored
});

test('TC-EDITOR-EYEDROPPER-004 — Eyedropper button turns purple (theme-selected) while armed, and restores when done', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior } = await calibrateLesson(page);

  const eyedropper = page.locator('[data-testid="editor-eyedropper"]');
  const defaultColor = await eyedropper.evaluate(el => getComputedStyle(el).color);

  await eyedropper.click(); // arm
  await expect(eyedropper).toHaveClass(/armed/);
  const armedColor = await eyedropper.evaluate(el => getComputedStyle(el).color);
  expect(armedColor).not.toBe(defaultColor);
  expect(armedColor).toBe('rgb(124, 77, 255)'); // the same theme purple used by other selected Editor tools

  const p = await artPoint(page, interior.x, interior.y);
  await page.mouse.move(p.sx, p.sy);
  await page.mouse.down();
  await page.mouse.up(); // completes sampling

  await expect(eyedropper).not.toHaveClass(/armed/);
  const restoredColor = await eyedropper.evaluate(el => getComputedStyle(el).color);
  expect(restoredColor).toBe(defaultColor);
});

test('TC-EDITOR-EYEDROPPER-003 — Cancelling (pointercancel) keeps the previous color and does not touch the custom slot', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior } = await calibrateLesson(page);

  await page.locator('[data-testid="palette-color-pink"]').click();
  const before = await page.evaluate(() => activeColor);
  const customBefore = await page.locator('[data-testid="palette-color-custom"]').getAttribute('data-color');

  await page.locator('[data-testid="editor-eyedropper"]').click();
  const p = await artPoint(page, interior.x, interior.y);
  await page.mouse.move(p.sx, p.sy);
  await page.mouse.down();
  await page.evaluate(() => document.getElementById('brushCanvas').dispatchEvent(new PointerEvent('pointercancel', { bubbles: true })));

  expect(await page.evaluate(() => activeColor)).toBe(before);
  await expect(page.locator('[data-testid="palette-color-custom"]')).toHaveAttribute('data-color', customBefore);
  await expect(page.locator('[data-testid="eyedropper-magnifier"]')).toBeHidden();
  await expect(page.locator('[data-testid="tool-brush"]')).toHaveClass(/selected/); // restored (Brush was active before arming)
  await page.mouse.up();
});

test('TC-EDITOR-SETTINGS-001 — Top gear opens the Editor Settings sheet, not SCR-SETTINGS-001', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

  await expect(page.locator('[data-testid="editor-settings-overlay"]')).toBeHidden();
  await page.locator('[data-testid="editor-settings-gear"]').click();

  await expect(page.locator('[data-testid="editor-settings-overlay"]')).toBeVisible();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-SETTINGS-001"]')).not.toHaveClass(/active/);
});

test('TC-EDITOR-SETTINGS-002 — Toggles work and Close preserves Editor state (artwork, tool, color, lock, history)', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await page.locator('[data-testid="tool-fill"]').click();
  await page.locator('[data-testid="palette-color-pink"]').click();
  await page.locator('[data-testid="editor-lock-toggle"]').click();

  await page.locator('[data-testid="editor-settings-gear"]').click();
  await page.locator('[data-testid="editor-settings-mirror-toggle"]').click();
  await page.locator('[data-testid="editor-settings-color-history-toggle"]').click();
  await expect(page.locator('[data-testid="editor-settings-mirror-toggle"]')).toHaveAttribute('aria-checked', 'true');
  await expect(page.locator('[data-testid="editor-settings-color-history-toggle"]')).toHaveAttribute('aria-checked', 'true');

  await page.locator('[data-testid="editor-settings-close"]').click();
  await expect(page.locator('[data-testid="editor-settings-overlay"]')).toBeHidden();

  const state = await page.evaluate(() => ({ activeTool, activeColor, coloringLocked }));
  expect(state.activeTool).toBe('fill');
  expect(state.activeColor).toBe('#FF6D80');
  expect(state.coloringLocked).toBe(false);
});

test('TC-EDITOR-SETTINGS-003 — Sounds toggle stays in sync between Editor Settings and Profile Settings', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await page.locator('[data-testid="editor-settings-gear"]').click();
  await page.locator('[data-testid="editor-settings-sound-toggle"]').click(); // off
  await page.locator('[data-testid="editor-settings-close"]').click();

  await active(page).locator('[aria-label="Back"]').click();
  await active(page).locator('[data-testid="nav-profile"]').click();
  await page.locator('[data-testid="profile-settings-icon"]').click();

  await expect(page.locator('[data-testid="settings-sound-toggle"]')).toHaveAttribute('aria-checked', 'false');
});

test('TC-EDITOR-REMOVED-001 — settingbrush and Add/More controls are gone, not just hidden', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

  await expect(page.locator('.workspace-settings')).toHaveCount(0);
  await expect(page.locator('[data-testid="tool-more"]')).toHaveCount(0);
});

test('TC-EDITOR-BRUSH-001 — Brush tool does not accidentally trigger Fill', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior } = await calibrateLesson(page);

  // Brush is selected by default on entry.
  await expect(page.locator('[data-testid="tool-brush"]')).toHaveClass(/selected/);

  const before = await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y);
  await tapInArtwork(page, interior.x, interior.y); // a tap with Brush active must never run Fill's flood-fill
  const after = await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y);
  expect(after).toEqual(before); // fillCanvas is untouched — only brushCanvas may have gained a dot
});

test('TC-EDITOR-BRUSH-002 — Brush drag with the selected color produces a visible stroke', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior, interiorFar } = await calibrateLesson(page);

  await page.locator('[data-testid="palette-color-pink"]').click();
  await expect(page.locator('[data-testid="tool-brush"]')).toHaveClass(/selected/);

  await dragOnArtboard(page, interior, interiorFar);

  const strokes = await page.evaluate(() => strokesList.length);
  expect(strokes).toBe(1);
  const color = await page.evaluate(() => strokesList[0].color);
  expect(color.toUpperCase()).toBe('#FF6D80');
});

test('TC-EDITOR-BRUSH-003 — Changing color does not recolor strokes already drawn', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior, interiorFar } = await calibrateLesson(page);

  await page.locator('[data-testid="palette-color-pink"]').click();
  await dragOnArtboard(page, interior, interiorFar);

  await page.locator('[data-testid="palette-color-blue"]').click();
  await dragOnArtboard(page, interiorFar, interior);

  const colors = await page.evaluate(() => strokesList.map(s => s.color.toUpperCase()));
  expect(colors).toEqual(['#FF6D80', '#4A82FF']); // first stroke stays pink, only the new one is blue
});

test('TC-EDITOR-SLIDER-001 — Brush size slider changes new stroke width', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior, interiorFar } = await calibrateLesson(page);

  await dragOnArtboard(page, interior, interiorFar);
  const widthBefore = await page.evaluate(() => strokesList[0].width);

  await page.locator('[data-testid="editor-slider"]').evaluate(el => {
    el.value = 90;
    el.dispatchEvent(new Event('input', { bubbles: true }));
  });
  await dragOnArtboard(page, interiorFar, interior);
  const widthAfter = await page.evaluate(() => strokesList[1].width);

  expect(widthAfter).toBeGreaterThan(widthBefore);
});

test('TC-EDITOR-ERASE-002 — Erase removes a user stroke via true transparent removal, not white paint', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior, interiorFar } = await calibrateLesson(page);

  const lineArtBefore = await canvasDataURL(page, 'lineArtCanvas');

  await page.locator('[data-testid="palette-color-purple"]').click();
  await dragOnArtboard(page, interior, interiorFar);
  expect((await page.evaluate(() => strokesList[0].color)).toUpperCase()).toBe('#C34AD8');

  const paintedPixel = await readCanvasPixel(page, 'editor-brush-layer', interior.x, interior.y);
  expect(paintedPixel.a).toBeGreaterThan(0); // the purple stroke is opaque here

  await page.locator('[data-testid="tool-erase"]').click();
  await dragOnArtboard(page, interior, interiorFar); // erase over the same path

  const tools = await page.evaluate(() => strokesList.map(s => s.tool));
  expect(tools).toEqual(['brush', 'erase']);

  const erasedPixel = await readCanvasPixel(page, 'editor-brush-layer', interior.x, interior.y);
  expect(erasedPixel.a).toBe(0); // truly transparent (destination-out) — never repainted white

  const lineArtAfter = await canvasDataURL(page, 'lineArtCanvas');
  expect(lineArtAfter).toBe(lineArtBefore); // the immutable line-art layer is byte-for-byte unchanged — untouched underneath
});

test('TC-EDITOR-UNDO-001 — Undo/Redo reflect real history, never a faked enabled state', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior } = await calibrateLesson(page);

  const undoBtn = page.locator('[data-testid="undo"]');
  const redoBtn = page.locator('[data-testid="redo"]');

  // Nothing to undo/redo yet on a fresh Editor entry.
  await expect(undoBtn).toBeDisabled();
  await expect(redoBtn).toBeDisabled();

  await page.locator('[data-testid="tool-fill"]').click();
  const original = await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y);
  await tapInArtwork(page, interior.x, interior.y);
  const filled = await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y);
  expect(filled).not.toEqual(original);

  await expect(undoBtn).toBeEnabled();
  await expect(redoBtn).toBeDisabled();

  await undoBtn.click();
  expect(await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y)).toEqual(original);
  await expect(undoBtn).toBeDisabled();
  await expect(redoBtn).toBeEnabled();

  await redoBtn.click();
  expect(await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y)).toEqual(filled);
  await expect(undoBtn).toBeEnabled();
  await expect(redoBtn).toBeDisabled();
});

test('TC-EDITOR-UNDO-002 — Undo removes the latest Brush stroke; Redo restores it', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior, interiorFar } = await calibrateLesson(page);

  await dragOnArtboard(page, interior, interiorFar);
  expect(await page.evaluate(() => strokesList.length)).toBe(1);
  await expect(page.locator('[data-testid="undo"]')).toBeEnabled();

  await page.locator('[data-testid="undo"]').click();
  expect(await page.evaluate(() => strokesList.length)).toBe(0);
  await expect(page.locator('[data-testid="redo"]')).toBeEnabled();

  await page.locator('[data-testid="redo"]').click();
  expect(await page.evaluate(() => strokesList.length)).toBe(1);
});

test('TC-EDITOR-LOCK-002 — Each locked stroke detects its own region independently; both remain visible', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior, background } = await calibrateLesson(page);
  await expect(page.locator('[data-testid="editor-lock-toggle"]')).toHaveAttribute('aria-pressed', 'true'); // LOCKED by default

  await tapInArtwork(page, interior.x, interior.y);
  await tapInArtwork(page, background.x, background.y);

  const info = await page.evaluate(() => ({
    count: strokesList.length,
    bothMasked: strokesList.length === 2 && strokesList.every(s => !!s.maskCanvas),
    distinctMasks: strokesList.length === 2 && strokesList[0].maskCanvas !== strokesList[1].maskCanvas,
  }));
  expect(info.count).toBe(2); // both strokes still present
  expect(info.bothMasked).toBe(true);
  expect(info.distinctMasks).toBe(true); // independent masks — the session was never "locked to the first region"
});

test('TC-EDITOR-LOCK-003 — Unlock removes containment for new strokes without touching prior locked strokes', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior } = await calibrateLesson(page);

  await tapInArtwork(page, interior.x, interior.y); // locked stroke
  expect(await page.evaluate(() => !!strokesList[0].maskCanvas)).toBe(true);

  await page.locator('[data-testid="editor-lock-toggle"]').click(); // UNLOCK
  await tapInArtwork(page, interior.x, interior.y); // free stroke, same start point

  const info = await page.evaluate(() => ({
    count: strokesList.length,
    firstStillMasked: !!strokesList[0].maskCanvas,
    secondMasked: !!strokesList[1].maskCanvas,
  }));
  expect(info.count).toBe(2);
  expect(info.firstStillMasked).toBe(true); // untouched by the later Unlock
  expect(info.secondMasked).toBe(false); // free stroke — no mask at all
});

test('TC-EDITOR-LOCK-004 — Switching back to Lock clips the next stroke to a NEW region, not the first one', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior, background } = await calibrateLesson(page);

  await tapInArtwork(page, interior.x, interior.y); // locked stroke #1

  await page.locator('[data-testid="editor-lock-toggle"]').click(); // unlock
  await tapInArtwork(page, interior.x, interior.y); // free stroke

  await page.locator('[data-testid="editor-lock-toggle"]').click(); // lock again
  await tapInArtwork(page, background.x, background.y); // locked stroke #3, a different region

  const info = await page.evaluate(() => ({
    count: strokesList.length,
    thirdMasked: !!strokesList[2] && !!strokesList[2].maskCanvas,
    firstAndThirdDistinct: strokesList.length === 3 && strokesList[0].maskCanvas !== strokesList[2].maskCanvas,
  }));
  expect(info.count).toBe(3);
  expect(info.thirdMasked).toBe(true);
  expect(info.firstAndThirdDistinct).toBe(true); // a fresh region detection, not a reused/first-region mask
});

test('TC-EDITOR-LOCK-006 — Locked Brush can paint the white background surrounding the subject, bounded by it', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { background } = await calibrateLesson(page);
  await expect(page.locator('[data-testid="editor-lock-toggle"]')).toHaveAttribute('aria-pressed', 'true');

  await tapInArtwork(page, background.x, background.y); // starts in the background near a corner
  const info = await page.evaluate(() => ({
    count: strokesList.length,
    masked: strokesList.length === 1 && !!strokesList[0].maskCanvas,
  }));
  expect(info.count).toBe(1); // it was NOT rejected as "no valid region" — this is the fix under test
  expect(info.masked).toBe(true); // still contained to the background's own connected region
});

test('TC-EDITOR-LOCK-005 — Erase is never affected by Lock/Unlock', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior } = await calibrateLesson(page);
  await expect(page.locator('[data-testid="editor-lock-toggle"]')).toHaveAttribute('aria-pressed', 'true');

  await page.locator('[data-testid="tool-erase"]').click();
  await tapInArtwork(page, interior.x, interior.y);

  const masked = await page.evaluate(() => !!strokesList[0].maskCanvas);
  expect(masked).toBe(false);
});

test('TC-EDITOR-FILL-BG-001 — Fill works on the connected background region near a corner/edge, not just internal regions', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { background } = await calibrateLesson(page);

  await page.locator('[data-testid="tool-fill"]').click();
  const before = await readCanvasPixel(page, 'editor-fill-canvas', background.x, background.y);
  await tapInArtwork(page, background.x, background.y);
  const after = await readCanvasPixel(page, 'editor-fill-canvas', background.x, background.y);

  expect(after.a).toBeGreaterThan(0); // filled — no longer transparent
  expect(after).not.toEqual(before);
});

test('TC-EDITOR-FILL-BARRIER-001 — Tapping directly on a line pixel with Fill is a no-op', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { barrier } = await calibrateLesson(page);

  await page.locator('[data-testid="tool-fill"]').click();
  const before = await readCanvasPixel(page, 'editor-fill-canvas', barrier.x, barrier.y);
  await tapInArtwork(page, barrier.x, barrier.y);
  const after = await readCanvasPixel(page, 'editor-fill-canvas', barrier.x, barrier.y);

  expect(after).toEqual(before); // a barrier pixel is never a valid flood-fill start point
});

test('TC-EDITOR-PROGRESS-001 — Back then reopen preserves the drawn Brush stroke', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior, interiorFar } = await calibrateLesson(page);
  await dragOnArtboard(page, interior, interiorFar);
  expect(await page.evaluate(() => strokesList.length)).toBe(1);

  await active(page).locator('[aria-label="Back"]').click();
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);

  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  expect(await page.evaluate(() => strokesList.length)).toBe(1); // same in-memory stroke, not recreated or lost
});

test('TC-EDITOR-PROGRESS-002 — Completion header Back preserves the Brush stroke and COMPLETED status', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior, interiorFar } = await calibrateLesson(page);
  await dragOnArtboard(page, interior, interiorFar);

  await active(page).locator('[data-testid="editor-done"]').click();
  await expect(page.locator('[data-screen-id="SCR-COMPLETE-001"]')).toHaveClass(/active/);

  await active(page).locator('[data-testid="completion-back"]').click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  expect(await page.evaluate(() => strokesList.length)).toBe(1);

  const status = await page.evaluate(() => progressStore['manga_spikyhero']);
  expect(status).toBe('COMPLETED'); // header Back never reverts completed status
});

test('TC-EDITOR-BACK-001 — Back returns to Home when Editor was entered from Home', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);

  await page.locator('.editor-topbar .editor-circle').click();
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
});

test('TC-EDITOR-BACK-002 — Back returns to Library when Editor was entered from Library', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();
  await active(page).locator('[data-testid="drawing-card-food_happydonuts"]').click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);

  await page.locator('.editor-topbar .editor-circle').click();
  await expect(page.locator('[data-screen-id="SCR-LIBRARY-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
});

test('TC-EDITOR-BACK-003 — Back returns to Profile when Editor was entered from Profile (via the popup\'s Color button), and preserves colored state', async ({ page }) => {
  // Updated 2026-08-16 for the final prototype functional pass: a Profile
  // card tap opens the Artwork Detail Popup, not Editor directly — Color is
  // the path from Profile into Editor now (see the "IV. Profile Artwork
  // Detail Popup" describe block below for full popup-specific coverage).
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();
  await active(page).locator('[data-testid="drawing-card-animal_babydeer"]').click();
  await expect(page.locator('[data-testid="profile-artwork-popup"]')).toBeVisible();
  await page.locator('[data-testid="profile-popup-color"]').click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);

  await waitForBarrierMask(page);
  const { interior } = await calibrateLesson(page);
  await page.locator('[data-testid="tool-fill"]').click();
  await tapInArtwork(page, interior.x, interior.y);
  const filledColor = await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y);

  await page.locator('.editor-topbar .editor-circle').click();
  await expect(page.locator('[data-screen-id="SCR-PROFILE-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);

  // Reopening the same artwork (via the popup's Color again) must show the
  // state exactly as left, not reset.
  await active(page).locator('[data-testid="drawing-card-animal_babydeer"]').click();
  await page.locator('[data-testid="profile-popup-color"]').click();
  expect(await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y)).toEqual(filledColor);

  const status = await page.evaluate(() => progressStore['animal_babydeer']);
  expect(status).toBe('IN_PROGRESS'); // resumed, not reset — status untouched by Back
});

test('TC-EDITOR-025 — Editor has no bottom navigation', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await expect(active(page).locator('.bottom-nav')).toHaveCount(0);
});

test('TC-SMOKE-004 — Prototype fill changes one region', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior, background } = await calibrateLesson(page);

  await page.locator('[data-testid="tool-fill"]').click();

  const neighborBefore = await readCanvasPixel(page, 'editor-fill-canvas', background.x, background.y);
  await tapInArtwork(page, interior.x, interior.y);

  const target = await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y);
  const neighborAfter = await readCanvasPixel(page, 'editor-fill-canvas', background.x, background.y);
  expect(target.a).toBeGreaterThan(0); // filled — no longer transparent
  expect(neighborAfter).toEqual(neighborBefore); // adjacent (background) region untouched
});

test('TC-EDITOR-023/FOCUS-001 — Maximize enters Focus mode; minimize exits it', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

  const artboard = page.locator('#artboard');
  const fitBtn = page.locator('[data-testid="editor-fit"]');
  await expect(artboard).not.toHaveClass(/zoomed/);
  await expect(fitBtn).toHaveAttribute('aria-pressed', 'false');

  await fitBtn.click();
  await expect(artboard).toHaveClass(/zoomed/);
  await expect(fitBtn).toHaveAttribute('aria-pressed', 'true');

  await fitBtn.click();
  await expect(artboard).not.toHaveClass(/zoomed/);
  await expect(fitBtn).toHaveAttribute('aria-pressed', 'false');
});

test('TC-EDITOR-FOCUS-002 — Focus mode hides the tool rail, slider, palette, and Playful', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await page.locator('[data-testid="editor-fit"]').click();

  await expect(page.locator('.tool-rail')).toBeHidden();
  await expect(page.locator('.slider-wrap')).toBeHidden();
  await expect(page.locator('.palette')).toBeHidden();
  await expect(page.locator('.playful')).toBeHidden();
});

test('TC-EDITOR-FOCUS-003 — Top toolbar stays visible and functional in Focus mode', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await page.locator('[data-testid="editor-fit"]').click();

  await expect(page.locator('.editor-topbar')).toBeVisible();
  await expect(page.locator('[data-testid="undo"]')).toBeVisible();
  await expect(page.locator('[data-testid="redo"]')).toBeVisible();
  await expect(page.locator('[data-testid="editor-lock-toggle"]')).toBeVisible();
  await expect(page.locator('[data-testid="editor-done"]')).toBeVisible();

  // Lock toggle still works normally while in Focus mode — same handler.
  const lockBtn = page.locator('[data-testid="editor-lock-toggle"]');
  await lockBtn.click();
  await expect(lockBtn).toHaveAttribute('aria-pressed', 'false');
});

test('TC-EDITOR-FOCUS-004 — Compact indicators reflect the actual active tool/color, not a forced Brush', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

  await page.locator('[data-testid="tool-fill"]').click();
  await page.locator('[data-testid="palette-color-pink"]').click();
  await page.locator('[data-testid="editor-fit"]').click();

  await expect(page.locator('[data-testid="editor-focus-controls"]')).toBeVisible();
  await expect(page.locator('[data-testid="focus-active-tool-icon"]')).toHaveClass(/tool-icon-fill/);
  const colorVar = await page.locator('[data-testid="focus-active-color"]').evaluate(el => el.style.getPropertyValue('--c'));
  expect(colorVar).toBe('#FF6D80');
});

test('TC-EDITOR-FOCUS-005 — Artwork becomes larger in Focus mode', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

  const before = await page.locator('#artboard').boundingBox();
  await page.locator('[data-testid="editor-fit"]').click();
  await page.waitForTimeout(250); // CSS width transition
  const after = await page.locator('#artboard').boundingBox();

  expect(after.width).toBeGreaterThan(before.width);
});

test('TC-EDITOR-FOCUS-007 — Active-tool, active-color, and minimize controls share one baseline; Saved text is hidden', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await page.locator('[data-testid="editor-fit"]').click();
  await page.waitForTimeout(300);

  await expect(page.locator('[data-testid="editor-save-state"]')).toBeHidden();

  const centers = await page.evaluate(() => {
    const centerY = sel => {
      const r = document.querySelector(sel).getBoundingClientRect();
      return r.top + r.height / 2;
    };
    return {
      tool: centerY('[data-testid="focus-active-tool"]'),
      color: centerY('[data-testid="focus-active-color"]'),
      minimize: centerY('[data-testid="editor-fit"]'),
    };
  });
  expect(centers.tool).toBe(centers.color);
  expect(centers.tool).toBe(centers.minimize); // all three on exactly the same vertical line

  await expect(page.locator('[data-testid="focus-active-tool"]')).toBeVisible();
  await expect(page.locator('[data-testid="focus-active-color"]')).toBeVisible();
});

test('TC-EDITOR-FOCUS-008 — Bottom controls stay aligned and visible even outside the mobile breakpoint (desktop shell width)', async ({ page }) => {
  // Regression guard: an earlier fix used position:fixed for the left group,
  // which only happened to line up with the minimize button because the
  // phone-frame fills the real viewport under the ≤720px mobile media query
  // (the width every other test in this suite runs at). At a wider viewport
  // the desktop multi-device shell chrome appears and the phone-frame no
  // longer fills the viewport, so position:fixed would send the left group
  // to the real window's edge — outside the visible mockup entirely.
  await page.setViewportSize({ width: 1280, height: 900 });
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await page.locator('[data-testid="editor-fit"]').click();
  await page.waitForTimeout(300);

  await expect(page.locator('[data-testid="focus-active-tool"]')).toBeVisible();
  await expect(page.locator('[data-testid="focus-active-color"]')).toBeVisible();
  await expect(page.locator('[data-testid="editor-fit"]')).toBeVisible();

  const centers = await page.evaluate(() => {
    const centerY = sel => {
      const r = document.querySelector(sel).getBoundingClientRect();
      return r.top + r.height / 2;
    };
    return {
      tool: centerY('[data-testid="focus-active-tool"]'),
      color: centerY('[data-testid="focus-active-color"]'),
      minimize: centerY('[data-testid="editor-fit"]'),
    };
  });
  expect(centers.tool).toBe(centers.color);
  expect(centers.tool).toBe(centers.minimize);

  // Also confirm the left group is actually inside the phone-frame's own
  // bounds, not off in the surrounding shell chrome.
  const withinFrame = await page.evaluate(() => {
    const frame = document.querySelector('.phone-frame').getBoundingClientRect();
    const tool = document.querySelector('[data-testid="focus-active-tool"]').getBoundingClientRect();
    return tool.left >= frame.left && tool.right <= frame.right && tool.top >= frame.top && tool.bottom <= frame.bottom;
  });
  expect(withinFrame).toBe(true);
});

test('TC-EDITOR-FOCUS-006 — Drawing works in Focus mode and survives exit; tool/color/lock/history are unchanged', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior, interiorFar } = await calibrateLesson(page);
  await page.locator('[data-testid="palette-color-purple"]').click();
  await page.locator('[data-testid="editor-lock-toggle"]').click(); // now UNLOCKED — confirms the state, not just the default

  await page.locator('[data-testid="editor-fit"]').click(); // enter Focus mode (Brush is still active by default)
  await dragOnArtboard(page, interior, interiorFar); // the drawing engine listens on #brushCanvas regardless of the hidden rail/palette
  expect((await page.evaluate(() => strokesList[0].color)).toUpperCase()).toBe('#C34AD8');
  const undoEnabledInFocus = await page.locator('[data-testid="undo"]').isEnabled();

  await page.locator('[data-testid="editor-fit"]').click(); // exit Focus mode
  await expect(page.locator('.tool-rail')).toBeVisible();
  await expect(page.locator('.slider-wrap')).toBeVisible();
  await expect(page.locator('.palette')).toBeVisible();
  expect(await page.evaluate(() => strokesList.length)).toBe(1); // the stroke drawn in Focus mode is still there

  const finalState = await page.evaluate(() => ({ activeTool, activeColor, coloringLocked }));
  expect(undoEnabledInFocus).toBe(true);
  expect(finalState.activeTool).toBe('brush');
  expect(finalState.activeColor).toBe('#C34AD8');
  expect(finalState.coloringLocked).toBe(false);
});

test('TC-EDITOR-024 — Done opens Completion and marks progress COMPLETED', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

  await page.locator('[data-testid="editor-done"]').click();
  await expect(page.locator('[data-screen-id="SCR-COMPLETE-001"]')).toHaveClass(/active/);

  const status = await page.evaluate(() => progressStore['manga_spikyhero']);
  expect(status).toBe('COMPLETED');
});

test('TC-EDITOR-ISOLATION-001 — Opening a DIFFERENT lesson never bleeds drawing state, and reopening the original restores it exactly', async ({ page }) => {
  await openHome(page);

  // Paint/fill lesson A (manga_spikyhero).
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const { interior: aInterior } = await calibrateLesson(page);
  await page.locator('[data-testid="tool-fill"]').click();
  await page.locator('[data-testid="palette-color-purple"]').click();
  await tapInArtwork(page, aInterior.x, aInterior.y);
  const paintedA = await readCanvasPixel(page, 'editor-fill-canvas', aInterior.x, aInterior.y);
  expect(paintedA.a).toBeGreaterThan(0);

  // Back to Home, then open a DIFFERENT lesson B (manga_foxwarrior).
  await active(page).locator('[aria-label="Back"]').click();
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_B}"]`).click();
  await waitForBarrierMask(page);

  // B's fill/brush canvases must be entirely blank — no bleed-over from A.
  const bAlphaSum = await page.evaluate(() => {
    const fillData = document.getElementById('fillCanvas').getContext('2d').getImageData(0, 0, ARTWORK_SIZE, ARTWORK_SIZE).data;
    const brushData = document.getElementById('brushCanvas').getContext('2d').getImageData(0, 0, ARTWORK_SIZE, ARTWORK_SIZE).data;
    let sum = 0;
    for (let i = 3; i < fillData.length; i += 4) sum += fillData[i];
    for (let i = 3; i < brushData.length; i += 4) sum += brushData[i];
    return sum;
  });
  expect(bAlphaSum).toBe(0);

  // Reopen lesson A — its drawing must be restored exactly.
  await active(page).locator('[aria-label="Back"]').click();
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await waitForBarrierMask(page);
  const restoredA = await readCanvasPixel(page, 'editor-fill-canvas', aInterior.x, aInterior.y);
  expect(restoredA).toEqual(paintedA);
});

test('TC-COMPLETE-001 — Completion has no bottom navigation', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await page.locator('[data-testid="editor-done"]').click();

  await expect(active(page).locator('.bottom-nav')).toHaveCount(0);
});

test('TC-COMPLETE-002 — Back to home routes to Home directly (no Preview/Category/Library/Profile)', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await page.locator('[data-testid="editor-done"]').click();

  await page.locator('[data-testid="completion-back-home"]').click();
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-CATEGORY-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-LIBRARY-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-PROFILE-001"]')).not.toHaveClass(/active/);
});

test('TC-COMPLETE-003/TC-COMPLETE-007 — Header Back reopens the SAME completed artwork, preserving state and status', async ({ page }) => {
  await openHome(page);

  // 1. Open artwork in Editor
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);

  // Color a region so there's real state to verify is preserved.
  await waitForBarrierMask(page);
  const { interior } = await calibrateLesson(page);
  await page.locator('[data-testid="tool-fill"]').click();
  await tapInArtwork(page, interior.x, interior.y);
  const filledColor = await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y);
  expect(filledColor.a).toBeGreaterThan(0);

  // 2. Complete it
  await page.locator('[data-testid="editor-done"]').click();

  // 3. Completion becomes active
  await expect(page.locator('[data-screen-id="SCR-COMPLETE-001"]')).toHaveClass(/active/);

  // 4/5. Click Completion top-left Back -> SCR-EDITOR-001 becomes active
  await page.locator('[data-testid="completion-back"]').click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-CATEGORY-001"]')).not.toHaveClass(/active/);

  // 6. Same artworkId is active
  const reopenedId = await page.evaluate(() => currentArtworkId);
  expect(reopenedId).toBe('manga_spikyhero');

  // 7. Existing artwork state/progress is preserved (not a fresh blank session)
  expect(await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y)).toEqual(filledColor);

  // 8. Progress status remains COMPLETED (not reverted to IN_PROGRESS)
  let status = await page.evaluate(() => progressStore['manga_spikyhero']);
  expect(status).toBe('COMPLETED');

  // 9. Done again returns to Completion, status still COMPLETED
  await page.locator('[data-testid="editor-done"]').click();
  await expect(page.locator('[data-screen-id="SCR-COMPLETE-001"]')).toHaveClass(/active/);
  status = await page.evaluate(() => progressStore['manga_spikyhero']);
  expect(status).toBe('COMPLETED');

  // 10. Back to home is unaffected by this change — still goes to Home
  await page.locator('[data-testid="completion-back-home"]').click();
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
});

test('TC-COMPLETE-004 — Share shows a visible prototype confirmation', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await page.locator('[data-testid="editor-done"]').click();

  const status = page.locator('[data-testid="completion-share-status"]');
  await expect(status).toBeHidden();
  await page.locator('[data-testid="completion-share"]').click();
  await expect(status).toBeVisible();
});

test('TC-COMPLETE-005 — Save shows a visible prototype confirmation', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await page.locator('[data-testid="editor-done"]').click();

  const status = page.locator('[data-testid="completion-save-status"]');
  await expect(status).toBeHidden();
  await page.locator('[data-testid="completion-save"]').click();
  await expect(status).toBeVisible();
});

test('TC-COMPLETE-006 — Recommended artwork opens Coloring directly (resume-or-create)', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await page.locator('[data-testid="editor-done"]').click();

  const recommended = active(page).locator('[data-testid="completion-recommended"] .drawing-card').first();
  const recommendedId = await recommended.getAttribute('data-testid');
  await recommended.click();

  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-CATEGORY-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  expect(recommendedId).toMatch(/^drawing-card-/);
});

test('TC-COMPLETE-REALCONTENT-001 — Completion shows the real completed lesson\'s title and a live composited artwork', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await page.locator('[data-testid="editor-done"]').click();
  await expect(page.locator('[data-screen-id="SCR-COMPLETE-001"]')).toHaveClass(/active/);

  const img = active(page).locator('[data-testid="completion-artwork"] img');
  await expect(img).toHaveAttribute('alt', LESSON_A_TITLE);
  // renderArtboardToDataURL() composites fillCanvas+brushCanvas+lineArtCanvas
  // into a live data: URL — never the flat static thumbnail.
  await expect(img).toHaveAttribute('src', /^data:image\//);
});

test('TC-COMPLETE-007 — Recommended for you shows 4 real lessons excluding the just-completed artwork', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await page.locator('[data-testid="editor-done"]').click();

  const cards = active(page).locator('[data-testid="completion-recommended"] .drawing-card');
  await expect(cards).toHaveCount(4);
  await expect(active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`)).toHaveCount(0);

  // The 25-lesson dataset (data/lessons.json) is in a fixed order and the
  // recommendation pool is simply "everything except the completed lesson,
  // first 4" — so the exact set is deterministic here.
  const ids = await cards.evaluateAll(els => els.map(el => el.dataset.testid.replace('drawing-card-', '')));
  expect(ids).toEqual(['manga_foxwarrior', 'manga_happybraids', 'manga_coolblindfold', 'manga_sweetgirl']);
});

test('TC-COMPLETE-008 — Completed artwork appears under Profile All and Completed, not In Progress', async ({ page }) => {
  await openHome(page);
  await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
  await page.locator('[data-testid="editor-done"]').click();
  await page.locator('[data-testid="completion-back-home"]').click();

  await active(page).locator('[data-testid="nav-profile"]').click();

  await expect(page.locator('[data-testid="profile-segment-all"]')).toHaveClass(/selected/);
  await expect(active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`)).toBeVisible();

  await page.locator('[data-testid="profile-segment-completed"]').click();
  await expect(active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`)).toBeVisible();

  await page.locator('[data-testid="profile-segment-in-progress"]').click();
  await expect(active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`)).toBeHidden();
});

test('TC-MON-002 — Paywall close returns to Home', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="premium-home"]').click();
  await expect(page.locator('[data-screen-id="SCR-PAYWALL-001"]')).toHaveClass(/active/);

  await page.locator('.paywall-close').click();
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
});

test('TC-SET-001 — Settings opens (via Profile)', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();
  await page.locator('[data-testid="profile-settings-icon"]').click();
  await expect(page.locator('[data-screen-id="SCR-SETTINGS-001"]')).toHaveClass(/active/);
});

test('TC-SET-006 — Settings has no bottom navigation', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();
  await page.locator('[data-testid="profile-settings-icon"]').click();

  await expect(active(page).locator('.bottom-nav')).toHaveCount(0);
});

test('TC-SET-007 — Close X returns to Profile', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();
  await page.locator('[data-testid="profile-settings-icon"]').click();

  await page.locator('[data-testid="settings-close"]').click();
  await expect(page.locator('[data-screen-id="SCR-PROFILE-001"]')).toHaveClass(/active/);
});

test('TC-SET-008 — Sound toggle changes state', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();
  await page.locator('[data-testid="profile-settings-icon"]').click();

  const toggle = page.locator('[data-testid="settings-sound-toggle"]');
  await expect(toggle).toHaveAttribute('aria-checked', 'true');

  await toggle.click();
  await expect(toggle).toHaveAttribute('aria-checked', 'false');

  await toggle.click();
  await expect(toggle).toHaveAttribute('aria-checked', 'true');
});

test('TC-SET-009 — General, Support, and Legal rows are present', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();
  await page.locator('[data-testid="profile-settings-icon"]').click();

  for (const testid of [
    'settings-sound-toggle',
    'settings-row-language',
    'settings-row-how-to-color',
    'settings-row-contact-us',
    'settings-row-rate-us',
    'settings-row-terms',
    'settings-row-privacy',
  ]) {
    await expect(page.locator(`[data-testid="${testid}"]`)).toBeVisible();
  }
  await expect(page.locator('[data-testid="settings-version"]')).toHaveText('Version v1.2.1');
});

test('TC-SET-010 — Profile segment/state is preserved after closing Settings', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();
  await page.locator('[data-testid="profile-segment-completed"]').click();
  await expect(page.locator('[data-testid="profile-segment-completed"]')).toHaveClass(/selected/);

  await page.locator('[data-testid="profile-settings-icon"]').click();
  await page.locator('[data-testid="settings-close"]').click();

  await expect(page.locator('[data-screen-id="SCR-PROFILE-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-testid="profile-segment-completed"]')).toHaveClass(/selected/);
  await expect(active(page).locator('[data-testid="drawing-card-nature_mountainlake"]')).toBeVisible();
  await expect(active(page).locator('[data-testid="drawing-card-animal_babydeer"]')).toBeHidden();
});

// ===========================================================================
// FINAL PROTOTYPE FUNCTIONAL PASS (2026-08-16) — covers the 4 approved
// behaviors added on top of the real-25-lesson-content integration above:
//   I.   Full background fill reaches the true 800×800 image edges (a pure
//        CSS fix — #artboardViewport now fills 100% of #artboard instead of
//        92%; the flood-fill engine itself was already correct).
//   II.  Editor zoom/pan (editorViewState.{scale,translateX,translateY}),
//        wheel zoom, pinch/two-finger gesture routing, pan clamping, and
//        Normal<->Expanded preservation.
//   III. Dynamic progress thumbnails (lessonPreviewCache, one shared cache
//        read by Home/Library/Profile via lessonPreviewSrc()).
//   IV.  The Profile Artwork Detail Popup (Restart/Color), Profile-only —
//        Home/Library/Search/Completion taps remain direct-to-Editor.
// All helpers/calibration patterns above (openHome, active, waitForBarrierMask,
// calibrateLesson, artPoint, tapInArtwork, dragOnArtboard, readCanvasPixel,
// findArtPoint) are reused as-is — no parallel style introduced.
// ===========================================================================

// Reads editorViewState (module-level `let` in app.js, visible to
// page.evaluate the same way strokesList/activeColor/etc. already are
// throughout this file) as a plain, comparable object.
async function getViewState(page) {
  return page.evaluate(() => ({ ...editorViewState }));
}

// Directly assigns editorViewState and re-applies the CSS transform — the
// same technique the original manual verification for this pass used, and
// exactly what the task's own report describes ("editorViewState direct
// assignment + applyEditorTransform()").
async function setViewState(page, state) {
  await page.evaluate((s) => {
    editorViewState.scale = s.scale;
    editorViewState.translateX = s.translateX;
    editorViewState.translateY = s.translateY;
    applyEditorTransform();
  }, state);
}

function assertClose(actual, expected, tolerance = 2) {
  expect(Math.abs(actual - expected)).toBeLessThan(tolerance);
}

// Dispatches a real PointerEvent directly on #brushCanvas (the element the
// app's own onViewportPointerDown/Move/Up/Cancel listeners are attached to —
// see index.html/app.js) with an explicit pointerId, so a second concurrent
// "finger" can be simulated even though Playwright's default chromium.launch()
// has no real multi-touch input. This exercises the EXACT SAME JS listeners a
// real two-finger touch gesture would — the same technique used to manually
// verify pinch-zoom/two-finger-pan for this pass.
async function dispatchPointerOnBrush(page, type, pointerId, clientX, clientY, pointerType = 'touch') {
  await page.evaluate(({ type, pointerId, clientX, clientY, pointerType }) => {
    const el = document.getElementById('brushCanvas');
    const ev = new PointerEvent(type, { bubbles: true, cancelable: true, pointerId, pointerType, clientX, clientY, isPrimary: pointerId === 1 });
    el.dispatchEvent(ev);
  }, { type, pointerId, clientX, clientY, pointerType });
}

// Opens a lesson fresh from Home, Fill-colors one calibrated interior point
// (a real commit — goes through markSaving()/updateLessonPreview()), then
// returns Home via the Editor's own Back button. Returns the calibrated point
// and the resulting pixel so callers can verify the coloring survives.
async function colorFreshLesson(page, lessonId) {
  await active(page).locator(`[data-testid="drawing-card-${lessonId}"]`).click();
  await waitForBarrierMask(page);
  const { interior } = await calibrateLesson(page);
  await page.locator('[data-testid="tool-fill"]').click();
  await tapInArtwork(page, interior.x, interior.y);
  const filledColor = await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y);
  await active(page).locator('[aria-label="Back"]').click();
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
  return { interior, filledColor };
}

test.describe('I. Full background fill reaches the true image edges', () => {
  test('TC-EDITOR-FILLBG-EDGE-001 — Fill on the connected background reaches all 4 true 800×800 corners, and #fillCanvas has no CSS inset from #artboard', async ({ page }) => {
    await openHome(page);
    await active(page).locator('[data-testid="nav-library"]').click();
    await active(page).locator('[data-testid="drawing-card-dumpling_dimsumbowl"]').click();
    await waitForBarrierMask(page);

    // The root-cause fix under test: #fillCanvas's box must now exactly
    // coincide with #artboard's own box — no leftover 8% CSS margin from the
    // old 92%-sized #artboardViewport.
    const [artboardBox, fillBox] = await Promise.all([
      page.locator('#artboard').boundingBox(),
      page.locator('#fillCanvas').boundingBox(),
    ]);
    assertClose(fillBox.x, artboardBox.x);
    assertClose(fillBox.y, artboardBox.y);
    assertClose(fillBox.width, artboardBox.width);
    assertClose(fillBox.height, artboardBox.height);

    const { background } = await calibrateLesson(page);
    await page.locator('[data-testid="tool-fill"]').click();
    await page.locator('[data-testid="palette-color-pink"]').click(); // #FF6D80
    await tapInArtwork(page, background.x, background.y);

    for (const [x, y] of [[0, 0], [799, 799], [799, 0], [0, 799]]) {
      const pixel = await readCanvasPixel(page, 'editor-fill-canvas', x, y);
      expect(pixel).toEqual({ r: 255, g: 109, b: 128, a: 255 }); // reaches the TRUE image edge, not just "close"
    }
  });
});

test.describe('II. Editor zoom / pan', () => {
  test('TC-EDITOR-ZOOM-001 — Setting editorViewState.scale enlarges #brushCanvas on-screen accordingly', async ({ page }) => {
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
    await waitForBarrierMask(page);

    const before = await page.locator('#brushCanvas').boundingBox();
    await setViewState(page, { scale: 2, translateX: 0, translateY: 0 });
    const after = await page.locator('#brushCanvas').boundingBox();

    expect(after.width).toBeGreaterThan(before.width * 1.8);
    expect(after.height).toBeGreaterThan(before.height * 1.8);
    expect(await getViewState(page)).toEqual({ scale: 2, translateX: 0, translateY: 0 });
  });

  test('TC-EDITOR-ZOOM-002 — A plain wheel gesture over the artboard zooms in, no Ctrl required', async ({ page }) => {
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
    await waitForBarrierMask(page);
    expect((await getViewState(page)).scale).toBe(1);

    const box = await page.locator('#artboard').boundingBox();
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    await page.mouse.wheel(0, -400);

    const after = await getViewState(page);
    expect(after.scale).toBeGreaterThan(1.8); // factor = exp(-deltaY*0.0018); ~2.05 observed for this exact call
    expect(after.scale).toBeLessThanOrEqual(4); // never exceeds EDITOR_ZOOM_MAX
  });

  test('TC-EDITOR-ZOOM-003 — Pan is clamped so content edges never leave a gap inside #artboard, and scale 1 always forces translate back to (0,0)', async ({ page }) => {
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
    await waitForBarrierMask(page);

    await setViewState(page, { scale: 2, translateX: 0, translateY: 0 });
    const rect = await page.locator('#artboard').boundingBox();

    // Extreme negative pan clamps to width*(1-scale)/height*(1-scale) — never
    // unboundedly large/"lost".
    await page.evaluate(() => panEditorBy(-999999, -999999));
    let state = await getViewState(page);
    assertClose(state.translateX, rect.width * (1 - 2));
    assertClose(state.translateY, rect.height * (1 - 2));

    // Extreme positive pan clamps back to 0 — content can never be dragged
    // past its centered/origin position either.
    await page.evaluate(() => panEditorBy(999999, 999999));
    state = await getViewState(page);
    assertClose(state.translateX, 0);
    assertClose(state.translateY, 0);

    // At scale 1, translate is always forced back to exactly (0,0).
    await setViewState(page, { scale: 1, translateX: 50, translateY: 50 });
    expect(await getViewState(page)).toEqual({ scale: 1, translateX: 0, translateY: 0 });
  });

  test('TC-EDITOR-ZOOM-004 — Fill/Eyedropper/Brush land on the correct source pixel while zoomed (canvas rect is transform-aware, no test-side coordinate math)', async ({ page }) => {
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
    await waitForBarrierMask(page);
    const { interior, interiorFar } = await calibrateLesson(page);

    await setViewState(page, { scale: 2, translateX: 0, translateY: 0 });

    await page.locator('[data-testid="tool-fill"]').click();
    await page.locator('[data-testid="palette-color-purple"]').click(); // #C34AD8
    await tapInArtwork(page, interior.x, interior.y); // artPoint() reads the canvas's CURRENT (post-transform) rect

    const filled = await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y);
    expect(filled).toEqual({ r: 195, g: 74, b: 216, a: 255 });

    // Eyedropper samples the exact same zoomed-in point back correctly.
    await page.locator('[data-testid="palette-color-green"]').click(); // move activeColor away first
    await page.locator('[data-testid="editor-eyedropper"]').click();
    const p = await artPoint(page, interior.x, interior.y);
    await page.mouse.move(p.sx, p.sy);
    await page.mouse.down();
    await page.mouse.up();
    expect(await page.evaluate(() => activeColor)).toBe('#C34AD8');

    // Brush also lands correctly while zoomed.
    await page.locator('[data-testid="tool-brush"]').click();
    await page.locator('[data-testid="palette-color-blue"]').click();
    await dragOnArtboard(page, interior, interiorFar);
    const strokeColor = (await page.evaluate(() => strokesList[strokesList.length - 1].color)).toUpperCase();
    expect(strokeColor).toBe('#4A82FF');
    const brushPixel = await readCanvasPixel(page, 'editor-brush-layer', interior.x, interior.y);
    expect(brushPixel.a).toBeGreaterThan(0);
  });

  test('TC-EDITOR-ZOOM-005 — A second simultaneous pointer cancels an in-progress stroke and drives pinch-zoom; a fresh single pointer afterward paints normally again', async ({ page }) => {
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
    await waitForBarrierMask(page);
    const { interior, interiorFar } = await calibrateLesson(page);

    const p1 = await artPoint(page, interior.x, interior.y);
    const p2 = await artPoint(page, interiorFar.x, interiorFar.y);

    await dispatchPointerOnBrush(page, 'pointerdown', 1, p1.sx, p1.sy);
    expect(await page.evaluate(() => strokesList.length)).toBe(1); // a single pointer still paints normally (Lock is on by default)

    await dispatchPointerOnBrush(page, 'pointerdown', 2, p2.sx, p2.sy);
    expect(await page.evaluate(() => strokesList.length)).toBe(0); // the in-progress stroke was cancelled, never committed

    const scaleBefore = (await getViewState(page)).scale;
    // Move pointer 1 further away from pointer 2 to increase pinch distance (zoom in).
    const movedX = p1.sx + (p1.sx - p2.sx) * 2;
    const movedY = p1.sy + (p1.sy - p2.sy) * 2;
    await dispatchPointerOnBrush(page, 'pointermove', 1, movedX, movedY);
    // The actual pinch/pan math is batched into one requestAnimationFrame per
    // frame (scheduleGestureUpdate()/runGestureUpdate() in app.js — reads
    // BOTH fingers' latest positions together instead of one stale one at a
    // time), so wait for that frame to actually run before reading state.
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    const scaleAfter = (await getViewState(page)).scale;
    expect(scaleAfter).toBeGreaterThan(scaleBefore);

    await dispatchPointerOnBrush(page, 'pointerup', 1, movedX, movedY);
    await dispatchPointerOnBrush(page, 'pointerup', 2, p2.sx, p2.sy);
    expect(await page.evaluate(() => activePointers.size)).toBe(0);

    // A fresh single pointer after both lift resumes normal painting.
    await dispatchPointerOnBrush(page, 'pointerdown', 3, p1.sx, p1.sy);
    expect(await page.evaluate(() => strokesList.length)).toBe(1);
    await dispatchPointerOnBrush(page, 'pointerup', 3, p1.sx, p1.sy);
  });

  test('TC-EDITOR-ZOOM-005b — A pure two-finger drag (distance between fingers unchanged) pans by exactly the movement delta, with no scale drift', async ({ page }) => {
    // Regression coverage for a real bug found and fixed during this pass:
    // the gesture handler used to recompute pinch distance/midpoint
    // synchronously inside EACH finger's own pointermove, which could read
    // the OTHER finger's momentarily stale position and cause the scale to
    // drift during what should have been a pure two-finger drag/pan. The fix
    // batches both fingers' latest positions into one requestAnimationFrame
    // per frame (runGestureUpdate()) before recomputing.
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
    await waitForBarrierMask(page);

    await setViewState(page, { scale: 2, translateX: 0, translateY: 0 }); // plenty of clamp headroom for a -60/-60 pan

    const artboardBox = await page.locator('#artboard').boundingBox();
    const cx = artboardBox.x + artboardBox.width / 2;
    const cy = artboardBox.y + artboardBox.height / 2;
    const p1 = { x: cx - 50, y: cy };
    const p2 = { x: cx + 50, y: cy }; // 100px apart

    await dispatchPointerOnBrush(page, 'pointerdown', 1, p1.x, p1.y);
    await dispatchPointerOnBrush(page, 'pointerdown', 2, p2.x, p2.y);
    const before = await getViewState(page);

    // Both fingers shift by the SAME delta — the distance between them (and
    // therefore the pinch scale factor) never changes, so this must be read
    // as a pure pan, never a zoom.
    const dx = -60, dy = -60;
    await dispatchPointerOnBrush(page, 'pointermove', 1, p1.x + dx, p1.y + dy);
    await dispatchPointerOnBrush(page, 'pointermove', 2, p2.x + dx, p2.y + dy);
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));

    const after = await getViewState(page);
    assertClose(after.translateX, before.translateX + dx, 1);
    assertClose(after.translateY, before.translateY + dy, 1);
    assertClose(after.scale, before.scale, 0.02); // no drift from the fixed staleness bug

    await dispatchPointerOnBrush(page, 'pointerup', 1, p1.x + dx, p1.y + dy);
    await dispatchPointerOnBrush(page, 'pointerup', 2, p2.x + dx, p2.y + dy);
  });

  test('TC-EDITOR-ZOOM-006 — Normal <-> Expanded preserves editorViewState exactly, and coloring is unaffected by the toggle', async ({ page }) => {
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
    await waitForBarrierMask(page);
    const { interior, interiorFar } = await calibrateLesson(page);
    await dragOnArtboard(page, interior, interiorFar); // a real stroke to prove coloring survives the toggle
    expect(await page.evaluate(() => strokesList.length)).toBe(1);

    await setViewState(page, { scale: 2.5, translateX: 0, translateY: 0 });
    const before = await getViewState(page);

    await page.locator('[data-testid="editor-fit"]').click(); // enter Expanded
    await expect(page.locator('#artboard')).toHaveClass(/zoomed/);
    expect(await getViewState(page)).toEqual(before);

    await page.locator('[data-testid="editor-fit"]').click(); // exit
    await expect(page.locator('#artboard')).not.toHaveClass(/zoomed/);
    expect(await getViewState(page)).toEqual(before);

    expect(await page.evaluate(() => strokesList.length)).toBe(1); // the stroke drawn before zooming is still there
  });

  test('TC-EDITOR-ZOOM-007 — Opening (or reopening) ANY lesson resets the view to scale 1 / translate (0,0)', async ({ page }) => {
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
    await waitForBarrierMask(page);
    await setViewState(page, { scale: 3, translateX: -20, translateY: -20 });
    expect((await getViewState(page)).scale).toBe(3);

    await active(page).locator('[aria-label="Back"]').click();
    await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_B}"]`).click(); // a DIFFERENT lesson
    await waitForBarrierMask(page);
    expect(await getViewState(page)).toEqual({ scale: 1, translateX: 0, translateY: 0 });

    // Reopening the SAME lesson (A) also resets, regardless of A's own previous zoom.
    await active(page).locator('[aria-label="Back"]').click();
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
    await waitForBarrierMask(page);
    expect(await getViewState(page)).toEqual({ scale: 1, translateX: 0, translateY: 0 });
  });
});

test.describe('III. Dynamic progress thumbnails', () => {
  test('TC-EDITOR-PREVIEW-001 — Coloring a fresh lesson updates Home/Library/Profile to the SAME live data URL, and reopening shows the same coloring', async ({ page }) => {
    await openHome(page);
    await active(page).locator('[data-testid="drawing-card-manga_happybraids"]').click();
    await waitForBarrierMask(page);
    const { interior } = await calibrateLesson(page);
    await page.locator('[data-testid="tool-fill"]').click();
    await page.locator('[data-testid="palette-color-purple"]').click();
    await tapInArtwork(page, interior.x, interior.y);
    const filledColor = await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y);
    expect(filledColor.a).toBeGreaterThan(0);

    await active(page).locator('[aria-label="Back"]').click();
    await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);

    const homeSrc = await active(page).locator('[data-testid="drawing-card-manga_happybraids"] img').getAttribute('src');
    expect(homeSrc).toMatch(/^data:image\/png/);
    const cachedSrc = await page.evaluate(() => lessonPreviewCache['manga_happybraids']);
    expect(homeSrc).toBe(cachedSrc); // one shared cache, not a separately-tracked fake state

    await active(page).locator('[data-testid="nav-library"]').click();
    const libSrc = await active(page).locator('[data-testid="drawing-card-manga_happybraids"] img').getAttribute('src');
    expect(libSrc).toBe(homeSrc);

    await active(page).locator('[data-testid="nav-profile"]').click();
    const profileSrc = await active(page).locator('[data-testid="drawing-card-manga_happybraids"] img').getAttribute('src');
    expect(profileSrc).toBe(homeSrc);

    // Reopen the SAME lesson directly from Home and confirm the actual
    // coloring (not just the thumbnail) is really preserved.
    await active(page).locator('[data-testid="nav-home"]').click();
    await active(page).locator('[data-testid="drawing-card-manga_happybraids"]').click();
    await waitForBarrierMask(page);
    expect(await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y)).toEqual(filledColor);
  });
});

test.describe('IV. Profile Artwork Detail Popup', () => {
  test('TC-PROFILE-POPUP-001 — Tapping a Profile card opens the popup over Profile; artwork matches the dynamic preview; Editor is not entered', async ({ page }) => {
    await openHome(page);
    await colorFreshLesson(page, 'manga_happybraids');
    await active(page).locator('[data-testid="nav-profile"]').click();

    await expect(page.locator('[data-testid="profile-artwork-popup"]')).toBeHidden();
    await active(page).locator('[data-testid="drawing-card-manga_happybraids"]').click();

    await expect(page.locator('[data-testid="profile-artwork-popup"]')).toBeVisible();
    await expect(page.locator('[data-screen-id="SCR-PROFILE-001"]')).toHaveClass(/active/); // Profile stays active underneath, dimmed
    await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).not.toHaveClass(/active/);

    const popupSrc = await page.locator('[data-testid="profile-popup-artwork"]').getAttribute('src');
    const cachedSrc = await page.evaluate(() => lessonPreviewCache['manga_happybraids']);
    expect(popupSrc).toBe(cachedSrc);
    await expect(page.locator('[data-testid="profile-popup-title"]')).toHaveText('HappyBraids');
  });

  test('TC-PROFILE-POPUP-002 — X close hides the popup, stays on Profile, and leaves progress/drawing state completely untouched', async ({ page }) => {
    await openHome(page);
    const { interior, filledColor } = await colorFreshLesson(page, 'manga_happybraids');
    await active(page).locator('[data-testid="nav-profile"]').click();
    await active(page).locator('[data-testid="drawing-card-manga_happybraids"]').click();
    await expect(page.locator('[data-testid="profile-artwork-popup"]')).toBeVisible();

    const before = await page.evaluate(() => ({
      status: progressStore['manga_happybraids'],
      hasDrawing: !!lessonDrawingState['manga_happybraids'],
    }));

    await page.locator('[data-testid="profile-popup-close"]').click();
    await expect(page.locator('[data-testid="profile-artwork-popup"]')).toBeHidden();
    await expect(page.locator('[data-screen-id="SCR-PROFILE-001"]')).toHaveClass(/active/);

    const after = await page.evaluate(() => ({
      status: progressStore['manga_happybraids'],
      hasDrawing: !!lessonDrawingState['manga_happybraids'],
    }));
    expect(after).toEqual(before);

    // Reopening (via Color) confirms the actual pixel data was never touched either.
    await active(page).locator('[data-testid="drawing-card-manga_happybraids"]').click();
    await page.locator('[data-testid="profile-popup-color"]').click();
    await waitForBarrierMask(page);
    expect(await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y)).toEqual(filledColor);
  });

  test('TC-PROFILE-POPUP-003 — Color closes the popup and resumes the EXACT saved progress, not a reset', async ({ page }) => {
    await openHome(page);
    const { interior, filledColor } = await colorFreshLesson(page, 'manga_happybraids');
    expect(await page.evaluate(() => progressStore['manga_happybraids'])).toBe('IN_PROGRESS');

    await active(page).locator('[data-testid="nav-profile"]').click();
    await active(page).locator('[data-testid="drawing-card-manga_happybraids"]').click();
    await page.locator('[data-testid="profile-popup-color"]').click();

    await expect(page.locator('[data-testid="profile-artwork-popup"]')).toBeHidden();
    await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
    await waitForBarrierMask(page);
    expect(await page.evaluate(() => currentArtworkId)).toBe('manga_happybraids');
    expect(await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y)).toEqual(filledColor);
    expect(await page.evaluate(() => progressStore['manga_happybraids'])).toBe('IN_PROGRESS'); // untouched, not reset
  });

  test('TC-PROFILE-POPUP-004 — Restart deletes the target lesson\'s saved state/progress and opens a clean Editor; a DIFFERENT lesson is provably untouched', async ({ page }) => {
    await openHome(page);
    const { interior } = await colorFreshLesson(page, 'manga_happybraids');

    // A different, untouched lesson, to prove Restart is scoped to one lesson ID only.
    const otherBefore = await page.evaluate(() => ({
      status: progressStore['animal_babydeer'],
      hasDrawing: !!lessonDrawingState['animal_babydeer'],
    }));

    await active(page).locator('[data-testid="nav-profile"]').click();
    await active(page).locator('[data-testid="drawing-card-manga_happybraids"]').click();
    await page.locator('[data-testid="profile-popup-restart"]').click();

    await expect(page.locator('[data-testid="profile-artwork-popup"]')).toBeHidden();
    await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
    await waitForBarrierMask(page);
    expect(await page.evaluate(() => currentArtworkId)).toBe('manga_happybraids');

    const restoredPixel = await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y);
    expect(restoredPixel).toEqual({ r: 0, g: 0, b: 0, a: 0 }); // true clean state, not a painted-white patch
    expect(await page.evaluate(() => progressStore['manga_happybraids'])).toBe('IN_PROGRESS'); // fresh re-seeded record

    const otherAfter = await page.evaluate(() => ({
      status: progressStore['animal_babydeer'],
      hasDrawing: !!lessonDrawingState['animal_babydeer'],
    }));
    expect(otherAfter).toEqual(otherBefore);
  });

  test('TC-PROFILE-POPUP-005 — Restart on a COMPLETED lesson reverts it to IN_PROGRESS, clears its canvas, and moves it out of the Completed segment', async ({ page }) => {
    await openHome(page);
    // nature_mountainlake is seeded COMPLETED with no real coloring yet — add
    // a real colored pixel first so there's something concrete to verify is wiped.
    await active(page).locator('[data-testid="drawing-card-nature_mountainlake"]').click();
    await waitForBarrierMask(page);
    const { interior } = await calibrateLesson(page);
    await page.locator('[data-testid="tool-fill"]').click();
    await tapInArtwork(page, interior.x, interior.y);
    expect((await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y)).a).toBeGreaterThan(0);
    await active(page).locator('[aria-label="Back"]').click();
    expect(await page.evaluate(() => progressStore['nature_mountainlake'])).toBe('COMPLETED');

    await active(page).locator('[data-testid="nav-profile"]').click();
    await active(page).locator('[data-testid="drawing-card-nature_mountainlake"]').click();
    await page.locator('[data-testid="profile-popup-restart"]').click();

    await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
    await waitForBarrierMask(page);
    expect(await readCanvasPixel(page, 'editor-fill-canvas', interior.x, interior.y)).toEqual({ r: 0, g: 0, b: 0, a: 0 });
    expect(await page.evaluate(() => progressStore['nature_mountainlake'])).toBe('IN_PROGRESS');

    await active(page).locator('[aria-label="Back"]').click();
    await expect(page.locator('[data-screen-id="SCR-PROFILE-001"]')).toHaveClass(/active/);
    await page.locator('[data-testid="profile-segment-completed"]').click();
    await expect(active(page).locator('[data-testid="drawing-card-nature_mountainlake"]')).toBeHidden();
    await page.locator('[data-testid="profile-segment-in-progress"]').click();
    await expect(active(page).locator('[data-testid="drawing-card-nature_mountainlake"]')).toBeVisible();
  });

  test('TC-PROFILE-POPUP-006 — Home and Library taps on a lesson WITH existing progress stay direct — no popup, straight to Editor', async ({ page }) => {
    await openHome(page);
    // animal_babydeer has default seeded IN_PROGRESS — the SAME lesson that
    // DOES show the popup when tapped from Profile (see TC-PROFILE-POPUP-001
    // for the equivalent Profile-card case on a similarly progressed lesson).
    await active(page).locator('[data-testid="drawing-card-animal_babydeer"]').click();
    await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
    await expect(page.locator('[data-testid="profile-artwork-popup"]')).toBeHidden();

    await active(page).locator('[aria-label="Back"]').click();
    await active(page).locator('[data-testid="nav-library"]').click();
    await active(page).locator('[data-testid="drawing-card-animal_babydeer"]').click();
    await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
    await expect(page.locator('[data-testid="profile-artwork-popup"]')).toBeHidden();
  });
});

// HSV picker geometry helpers. The S/V square is inset:26% inside
// #hueRingWrap with NO border-radius (intentional — see the sv-square-wrap
// comment in styles.css: a rounded corner there clips the exact geometric
// corner out of the hit-test area, confirmed via elementsFromPoint(), and
// the picker explicitly requires literal-corner taps to reach true
// white/black). fracX/fracY of exactly 0/1 land inside SV_EDGE_SNAP's ~3%
// forgiveness band in app.js, so real edge/corner taps still resolve to
// exact 0 or 1 — matching how a real fingertip can never land on the
// mathematically exact boundary pixel either.
async function svPoint(page, fracX, fracY) {
  const box = await page.locator('#svSquareWrap').boundingBox();
  return { x: box.x + box.width * fracX, y: box.y + box.height * fracY };
}

// 0deg = up (12 o'clock), increasing clockwise — matches the app's own
// conic-gradient/positionHueHandle() convention.
async function huePoint(page, deg) {
  const box = await page.locator('#hueRingWrap').boundingBox();
  const cx = box.x + box.width / 2, cy = box.y + box.height / 2;
  const r = box.width / 2 * 0.905;
  const rad = deg * Math.PI / 180;
  return { x: cx + r * Math.sin(rad), y: cy - r * Math.cos(rad) };
}

async function tapAt(page, point) {
  await page.mouse.move(point.x, point.y);
  await page.mouse.down();
  await page.mouse.up();
}

test.describe('V. HSV Color Picker', () => {
  test('TC-EDITOR-HSV-001 — S/V square top-left corner selects true white; Save commits it and the custom swatch is clearly visible/selected', async ({ page }) => {
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

    await page.locator('.playful').click();
    await tapAt(page, await svPoint(page, 0, 0));
    await expect.poll(() => page.evaluate(() => pickerState.draftColor)).toBe('#FFFFFF');

    await page.locator('[data-testid="color-picker-save"]').click();
    await expect(page.locator('[data-testid="color-picker-overlay"]')).toBeHidden();
    expect(await page.evaluate(() => activeColor)).toBe('#FFFFFF');

    const custom = page.locator('[data-testid="palette-color-custom"]');
    await expect(custom).toHaveAttribute('data-color', '#FFFFFF');
    await expect(custom).toHaveClass(/selected/);
    // The selection ring must use the purple accent, not the swatch's own
    // (white) color — otherwise a selected white swatch's ring is invisible
    // against the picker's white background.
    const ringColor = await custom.locator('.swatch').evaluate(el => getComputedStyle(el).boxShadow);
    expect(ringColor).not.toMatch(/rgb\(255, 255, 255\).*rgb\(255, 255, 255\)/); // not white-on-white
  });

  test('TC-EDITOR-HSV-002 — S/V square bottom edge selects true black regardless of Hue, and the swatch remains visually clear when selected', async ({ page }) => {
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

    await page.locator('.playful').click();
    await tapAt(page, await huePoint(page, 200)); // an arbitrary hue — must not matter once Value hits 0
    // 0.99, not the literal 1.0: a real pointer can never land on the exact
    // mathematical box.height boundary (getBoundingClientRect()'s bottom
    // edge is exclusive), and SV_EDGE_SNAP in app.js is what turns "near the
    // bottom edge" into an exact Value=0 — see the sv-square-wrap/
    // svFromPointer comments.
    await tapAt(page, await svPoint(page, 0.5, 0.99));
    await expect.poll(() => page.evaluate(() => pickerState.draftColor)).toBe('#000000');

    await page.locator('[data-testid="color-picker-save"]').click();
    expect(await page.evaluate(() => activeColor)).toBe('#000000');
    const custom = page.locator('[data-testid="palette-color-custom"]');
    await expect(custom).toHaveAttribute('data-color', '#000000');
    await expect(custom).toHaveClass(/selected/);
  });

  test('TC-EDITOR-HSV-003 — Saturation=0 at mid-Value produces a neutral gray (R=G=B), independent of Hue', async ({ page }) => {
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

    await page.locator('.playful').click();
    await tapAt(page, await huePoint(page, 45));
    await tapAt(page, await svPoint(page, 0, 0.5));
    const draft = await page.evaluate(() => pickerState.draftColor);
    const r = parseInt(draft.slice(1, 3), 16), g = parseInt(draft.slice(3, 5), 16), b = parseInt(draft.slice(5, 7), 16);
    expect(r).toBe(g);
    expect(g).toBe(b);
    expect(await page.evaluate(() => pickerState.saturation)).toBe(0);
  });

  test('TC-EDITOR-HSV-004 — Choosing a Hue + high Saturation/Value paints and fills with the exact chosen color', async ({ page }) => {
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
    await waitForBarrierMask(page);
    const { interior } = await calibrateLesson(page);

    await page.locator('.playful').click();
    await tapAt(page, await huePoint(page, 120)); // green
    await tapAt(page, await svPoint(page, 0.85, 0.15));
    const chosen = await page.evaluate(() => pickerState.draftColor);
    await page.locator('[data-testid="color-picker-save"]').click();
    expect(await page.evaluate(() => activeColor)).toBe(chosen);

    const p = await artPoint(page, interior.x, interior.y);
    await page.mouse.move(p.sx, p.sy);
    await page.mouse.down();
    await page.mouse.up();
    const brushed = await readCanvasPixel(page, 'editor-brush-layer', interior.x, interior.y);
    expect(`#${[brushed.r, brushed.g, brushed.b].map(n => n.toString(16).padStart(2, '0')).join('').toUpperCase()}`).toBe(chosen);

    await page.locator('[data-testid="tool-fill"]').click();
    const { background } = await calibrateLesson(page);
    await tapInArtwork(page, background.x, background.y);
    const filled = await readCanvasPixel(page, 'editor-fill-canvas', background.x, background.y);
    expect(`#${[filled.r, filled.g, filled.b].map(n => n.toString(16).padStart(2, '0')).join('').toUpperCase()}`).toBe(chosen);
  });

  test('TC-EDITOR-HSV-005 — Back discards S/V + Hue changes; activeColor and the custom slot are untouched', async ({ page }) => {
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
    const original = await page.evaluate(() => activeColor);

    await page.locator('.playful').click();
    await tapAt(page, await huePoint(page, 300));
    await tapAt(page, await svPoint(page, 0.9, 0.9));
    await page.locator('[data-testid="color-picker-back"]').click();

    await expect(page.locator('[data-testid="color-picker-overlay"]')).toBeHidden();
    expect(await page.evaluate(() => activeColor)).toBe(original);
  });

  test('TC-EDITOR-HSV-006 — Reopening Playful positions both handles at the CURRENT activeColor (HSV round-trip)', async ({ page }) => {
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();

    await page.locator('.playful').click();
    await tapAt(page, await huePoint(page, 210));
    await tapAt(page, await svPoint(page, 0.6, 0.35));
    const chosen = await page.evaluate(() => pickerState.draftColor);
    await page.locator('[data-testid="color-picker-save"]').click();

    await page.locator('.playful').click();
    const reconstructed = await page.evaluate(() => hsvToHex(pickerState.hue, pickerState.saturation, pickerState.value));
    expect(reconstructed).toBe(chosen);
    await page.locator('[data-testid="color-picker-back"]').click();
  });

  test('TC-EDITOR-HSV-007 — Eyedropper sampling black, then reopening Playful, positions the S/V handle at true black (Saturation=0, Value=0)', async ({ page }) => {
    await openHome(page);
    await active(page).locator(`[data-testid="drawing-card-${LESSON_A}"]`).click();
    await waitForBarrierMask(page);
    const { background } = await calibrateLesson(page);

    await page.evaluate(() => { activeColor = '#000000'; });
    await page.locator('[data-testid="tool-fill"]').click();
    await tapInArtwork(page, background.x, background.y);

    await page.locator('[aria-label="Eyedropper"]').click();
    const p = await artPoint(page, background.x, background.y);
    await page.mouse.move(p.sx, p.sy);
    await page.mouse.down();
    await page.mouse.up();
    expect(await page.evaluate(() => activeColor)).toBe('#000000');

    await page.locator('.playful').click();
    const hsv = await page.evaluate(() => ({ s: pickerState.saturation, v: pickerState.value }));
    expect(hsv.s).toBe(0);
    expect(hsv.v).toBe(0);
    const svHandleTop = await page.locator('#svHandle').evaluate(el => parseFloat(el.style.top));
    const svSquareHeight = await page.locator('#svSquareWrap').evaluate(el => el.getBoundingClientRect().height);
    assertClose(svHandleTop, svSquareHeight, 3); // handle sits at the very bottom (Value=0)
  });
});
