const { test, expect } = require('@playwright/test');

async function openHome(page) {
  await page.goto('/');
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
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

test('TC-HOME-004 — Continue card hidden when there is no IN_PROGRESS artwork', async ({ page }) => {
  await openHome(page);
  await clearProgressAndReturnHome(page);

  await expect(page.locator('[data-testid="continue-coloring"]')).toBeHidden();
});

test('TC-HOME-004b — COMPLETED-only artwork does not show the Continue card', async ({ page }) => {
  await openHome(page);
  await page.evaluate(() => {
    Object.keys(progressStore).forEach(id => delete progressStore[id]);
    progressStore['draw_nature_001'] = 'COMPLETED';
    renderHomeContinue();
  });

  await expect(page.locator('[data-testid="continue-coloring"]')).toBeHidden();
});

test('TC-HOME-003 — Continue card shows the single IN_PROGRESS artwork', async ({ page }) => {
  await openHome(page);
  // Default seeded state already has exactly one IN_PROGRESS record.
  const card = page.locator('[data-testid="continue-coloring"]');
  await expect(card).toBeVisible();
  await expect(card.locator('.continue-title')).toHaveText('Little Elephant');
  await expect(card).toHaveAttribute('data-artwork-id', 'draw_animals_001');
});

test('TC-HOME-003b — Continue card shows the most recently updated of multiple IN_PROGRESS artworks', async ({ page }) => {
  await openHome(page);
  // Seeded default: draw_animals_001 is IN_PROGRESS. Open a second artwork
  // without completing it, then return Home — the more recently touched
  // one (draw_manga_001) must win.
  await active(page).locator('[data-testid="drawing-card-draw_manga_001"]').click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);

  await page.locator('.editor-topbar .editor-circle').click(); // Back -> Home
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);

  const card = page.locator('[data-testid="continue-coloring"]');
  await expect(card).toBeVisible();
  await expect(card).toHaveAttribute('data-artwork-id', 'draw_manga_001');
  await expect(card.locator('.continue-title')).toHaveText('Moon Samurai');

  const bothInProgress = await page.evaluate(() => ({
    animals: progressStore['draw_animals_001'],
    manga: progressStore['draw_manga_001'],
  }));
  expect(bothInProgress).toEqual({ animals: 'IN_PROGRESS', manga: 'IN_PROGRESS' });
});

test('TC-HOME-CONTINUE-001 — Continue button opens the correct artwork directly, resuming progress', async ({ page }) => {
  await openHome(page);
  const card = page.locator('[data-testid="continue-coloring"]');
  await card.locator('.continue-btn').click();

  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-CATEGORY-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);

  const id = await page.evaluate(() => currentArtworkId);
  expect(id).toBe('draw_animals_001');
  const status = await page.evaluate(() => progressStore['draw_animals_001']);
  expect(status).toBe('IN_PROGRESS'); // resumed, not reset
});

test('TC-HOME-CONTINUE-002 — Clicking the card itself does the same thing as the button', async ({ page }) => {
  await openHome(page);
  const card = page.locator('[data-testid="continue-coloring"]');
  await card.click(); // click the card, not specifically the button

  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  const id = await page.evaluate(() => currentArtworkId);
  expect(id).toBe('draw_animals_001');
});

test('TC-HOME-CONTINUE-003 — PRO pill remains visible and works with the Continue card present', async ({ page }) => {
  await openHome(page);
  await expect(page.locator('[data-testid="continue-coloring"]')).toBeVisible();

  const pro = page.locator('[data-testid="premium-home"]');
  await expect(pro).toBeVisible();
  await pro.click();
  await expect(page.locator('[data-screen-id="SCR-PAYWALL-001"]')).toHaveClass(/active/);
});

for (const drawingId of ['draw_manga_001', 'draw_animals_001', 'draw_nature_001']) {
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
  animal: 'draw_animals_001',
  food: 'draw_food_001',
  manga: 'draw_manga_001',
  nature: 'draw_nature_001',
};

for (const category of ['animal', 'food', 'manga', 'nature']) {
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

test('TC-HOME-010 — Manga row can be horizontally drag-scrolled to fully reveal the third artwork', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 812 }); // narrower than the suite default (430) — this is exactly where the row overflows and the bug was reported
  await openHome(page);
  const row = page.locator('[data-testid="home-manga-row"]');
  const overflow = await row.evaluate(el => el.scrollWidth - el.clientWidth);
  expect(overflow).toBeGreaterThan(0); // confirms the row genuinely overflows in this viewport

  await dragRowLeft(page, 'home-manga-row');
  const scrollLeftAfter = await row.evaluate(el => el.scrollLeft);
  expect(scrollLeftAfter).toBeGreaterThan(0);

  const thirdCard = row.locator('[data-testid="drawing-card-draw_manga_003"]');
  const rowBox = await row.boundingBox();
  const cardBox = await thirdCard.boundingBox();
  expect(cardBox.x).toBeGreaterThanOrEqual(rowBox.x - 1);
  expect(cardBox.x + cardBox.width).toBeLessThanOrEqual(rowBox.x + rowBox.width + 1); // fully within the visible row, not clipped

  // A drag must not have been misread as a tap that opens the artwork.
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);

  // A real tap still opens it normally.
  await thirdCard.click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
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

  await active(page).locator('[data-testid="drawing-card-draw_food_002"]').click();
  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-CATEGORY-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-testid="coloring-canvas"]')).toBeVisible();
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

  await active(page).locator('[data-testid="search-input"]').fill('ELEPHANT');
  await expect(active(page).locator('[data-testid="search-results-grid"]')).toBeVisible();
  await expect(active(page).locator('[data-testid="search-empty-state"]')).toBeHidden();
  await expect(active(page).locator('[data-testid="drawing-card-draw_animals_001"]')).toBeVisible();
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

  await active(page).locator('[data-testid="search-input"]').fill('elephant');
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

  await active(page).locator('[data-testid="search-input"]').fill('Deer');
  await active(page).locator('[data-testid="drawing-card-draw_animals_003"]').click();

  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-CATEGORY-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  const status = await page.evaluate(() => progressStore['draw_animals_003']);
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

// Profile boots with two seeded progress records (draw_animals_001 =
// IN_PROGRESS, draw_nature_001 = COMPLETED) so the default app state is
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
  await expect(active(page).locator('[data-testid="drawing-card-draw_animals_001"]')).toBeVisible();
  await expect(active(page).locator('[data-testid="drawing-card-draw_nature_001"]')).toBeVisible();
});

test('TC-PROFILE-003 — Completed segment shows only COMPLETED artwork', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();

  await page.locator('[data-testid="profile-segment-completed"]').click();
  await expect(active(page).locator('[data-testid="drawing-card-draw_nature_001"]')).toBeVisible();
  await expect(active(page).locator('[data-testid="drawing-card-draw_animals_001"]')).toBeHidden();
});

test('TC-PROFILE-004 — In Progress segment shows only IN_PROGRESS artwork', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();

  await page.locator('[data-testid="profile-segment-in-progress"]').click();
  await expect(active(page).locator('[data-testid="drawing-card-draw_animals_001"]')).toBeVisible();
  await expect(active(page).locator('[data-testid="drawing-card-draw_nature_001"]')).toBeHidden();
});

test('TC-PROFILE-004b — Switching segments does not change artwork status', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();

  await page.locator('[data-testid="profile-segment-in-progress"]').click();
  await page.locator('[data-testid="profile-segment-all"]').click();

  const stillCorrect = await page.evaluate(() => ({
    animal: progressStore['draw_animals_001'],
    nature: progressStore['draw_nature_001'],
  }));
  expect(stillCorrect).toEqual({ animal: 'IN_PROGRESS', nature: 'COMPLETED' });
});

test('TC-PROFILE-005 — Profile artwork opens Coloring directly and resumes existing progress', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();

  await active(page).locator('[data-testid="drawing-card-draw_nature_001"]').click();
  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-CATEGORY-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);

  const status = await page.evaluate(() => progressStore['draw_nature_001']);
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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

  const pink = page.locator('[data-testid="palette-color-pink"]');
  await pink.click();
  await expect(pink).toHaveClass(/selected/);
});

// --- Editor region-engine test helpers -------------------------------------
// Converts an artwork-space (0..360, the artwork's own native coordinate
// system) point into real screen coordinates via #brushCanvas's current
// bounding box, and drives real Pointer Events — never a synthetic DOM
// mutation — so the actual shared region-mask engine runs end to end.
async function artPoint(page, x, y) {
  const box = await page.locator('#brushCanvas').boundingBox();
  return { sx: box.x + (x / 360) * box.width, sy: box.y + (y / 360) * box.height };
}

async function tapInArtwork(page, x, y) {
  const p = await artPoint(page, x, y);
  await page.mouse.click(p.sx, p.sy);
}

async function waitForBarrierMask(page) {
  await page.waitForFunction(() => typeof barrierMaskReady === 'boolean' && barrierMaskReady === true, { timeout: 10000 });
}

// Reads one pixel's RGBA from a canvas layer (fillCanvas/brushCanvas) at a
// given artwork-space (0..360) coordinate.
async function readCanvasPixel(page, testid, x, y) {
  return page.evaluate(({ testid, x, y }) => {
    const canvas = document.querySelector(`[data-testid="${testid}"]`);
    const d = canvas.getContext('2d').getImageData(Math.round(x), Math.round(y), 1, 1).data;
    return { r: d[0], g: d[1], b: d[2], a: d[3] };
  }, { testid, x, y });
}

function hexToRgb(hex) {
  return { r: parseInt(hex.slice(1, 3), 16), g: parseInt(hex.slice(3, 5), 16), b: parseInt(hex.slice(5, 7), 16) };
}

// Empirically-verified artwork-space points (0..360) for draw_animals_001,
// each landing inside a distinct connected region per the shared flood-fill
// engine: NOSE and MOUTH are small isolated regions, FACE is the large open
// head area, LEFT_EAR/RIGHT_EAR are separate from FACE and each other, and
// BG points are all one connected region — the white background surrounding
// the subject, bounded by the artwork rectangle (the fix under test).
const NOSE = [180, 247];
const MOUTH = [180, 258];
const FACE = [180, 110];
const LEFT_EAR = [84, 115];
const RIGHT_EAR = [276, 115];
const BG_ABOVE = [180, 20];
const BG_LEFT = [10, 180];
const BG_RIGHT = [350, 180];

test('TC-EDITOR-022 — Palette selection does not immediately modify artwork', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  const before = await readCanvasPixel(page, 'editor-fill-canvas', ...NOSE);

  await page.locator('[data-testid="palette-color-pink"]').click();
  const after = await readCanvasPixel(page, 'editor-fill-canvas', ...NOSE);
  expect(after).toEqual(before); // still untouched — nothing filled yet
  await expect(page.locator('[data-testid="editor-active-color"]')).toHaveAttribute('data-active-color', '#FF6D80');
});

async function pickHueAtRightEdge(page) {
  const ring = await page.locator('#hueRingWrap').boundingBox();
  await page.mouse.click(ring.x + ring.width / 2 + ring.width * 0.4, ring.y + ring.height / 2);
}

test('TC-EDITOR-COLORPICKER-001 — Playful opens the Color Picker as a sheet over the Editor, not a new screen', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

  await expect(page.locator('[data-testid="color-picker-overlay"]')).toBeHidden();
  await page.locator('.playful').click();

  await expect(page.locator('[data-testid="color-picker-overlay"]')).toBeVisible();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/); // still the same screen
  await expect(page.locator('[data-testid="editor-tool-state"]')).toBeVisible(); // Editor behind it is still present
});

test('TC-EDITOR-COLORPICKER-002 — Picking a hue updates the draft/preview live but not activeColor', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  const before = await page.evaluate(() => activeColor);

  await page.locator('.playful').click();
  await pickHueAtRightEdge(page);

  const draft = await page.evaluate(() => draftColor);
  const stillActive = await page.evaluate(() => activeColor);
  expect(draft).not.toBe(before);
  expect(stillActive).toBe(before); // Editor's activeColor is untouched while the sheet is open
});

test('TC-EDITOR-COLORPICKER-003 — Back discards the draft and preserves the original color', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  const original = await page.evaluate(() => activeColor);

  await page.locator('.playful').click();
  await pickHueAtRightEdge(page);
  const draft = await page.evaluate(() => draftColor);
  await page.locator('[data-testid="color-picker-save"]').click();

  await expect(page.locator('[data-testid="color-picker-overlay"]')).toBeHidden();
  const committed = await page.evaluate(() => activeColor);
  expect(committed).toBe(draft);
  expect(committed).not.toBe(original);

  await waitForBarrierMask(page);
  await page.mouse.move((await artPoint(page, ...FACE)).sx, (await artPoint(page, ...FACE)).sy);
  await page.mouse.down();
  await page.mouse.up();
  const strokeColor = await page.evaluate(() => strokesList[strokesList.length - 1].color);
  expect(strokeColor.toUpperCase()).toBe(committed);
});

test('TC-EDITOR-COLORPICKER-006 — Draft-only color changes do not create Undo history', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

  await page.locator('[data-testid="palette-color-pink"]').click();
  await expect(page.locator('[data-testid="palette-color-pink"]')).toHaveClass(/selected/);

  await page.locator('.playful').click();
  await pickHueAtRightEdge(page);
  const draft = await page.evaluate(() => draftColor);
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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  await page.locator('[data-testid="tool-fill"]').click();
  await page.locator('[data-testid="palette-color-purple"]').click();
  await tapInArtwork(page, ...MOUTH); // fill the mouth purple
  await page.locator('[data-testid="palette-color-green"]').click(); // move activeColor away

  await page.locator('[data-testid="editor-eyedropper"]').click();
  const mouthPt = await artPoint(page, ...MOUTH);
  await page.mouse.move(mouthPt.sx, mouthPt.sy);
  await page.mouse.down();
  await expect(page.locator('[data-testid="eyedropper-magnifier"]')).toBeVisible();
  const colorOnMouth = await page.locator('[data-testid="eyedropper-magnifier"]').evaluate(el => el.style.background);

  const nosePt = await artPoint(page, ...NOSE); // background/white area near the nose (unfilled)
  await page.mouse.move(nosePt.sx, nosePt.sy, { steps: 4 });
  const colorOnNose = await page.locator('[data-testid="eyedropper-magnifier"]').evaluate(el => el.style.background);
  expect(colorOnNose).not.toBe(colorOnMouth); // live-updates while dragging

  await page.mouse.up();
});

test('TC-EDITOR-EYEDROPPER-002 — Release commits the sample to the right-most custom slot and restores the previous tool', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  await page.locator('[data-testid="tool-fill"]').click();
  await page.locator('[data-testid="palette-color-purple"]').click();
  await tapInArtwork(page, ...MOUTH);
  await page.locator('[data-testid="palette-color-green"]').click();

  await page.locator('[data-testid="editor-eyedropper"]').click();
  const mouthPt = await artPoint(page, ...MOUTH);
  await page.mouse.move(mouthPt.sx, mouthPt.sy);
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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  const eyedropper = page.locator('[data-testid="editor-eyedropper"]');
  const defaultColor = await eyedropper.evaluate(el => getComputedStyle(el).color);

  await eyedropper.click(); // arm
  await expect(eyedropper).toHaveClass(/armed/);
  const armedColor = await eyedropper.evaluate(el => getComputedStyle(el).color);
  expect(armedColor).not.toBe(defaultColor);
  expect(armedColor).toBe('rgb(124, 77, 255)'); // the same theme purple used by other selected Editor tools

  const p = await artPoint(page, ...FACE);
  await page.mouse.move(p.sx, p.sy);
  await page.mouse.down();
  await page.mouse.up(); // completes sampling

  await expect(eyedropper).not.toHaveClass(/armed/);
  const restoredColor = await eyedropper.evaluate(el => getComputedStyle(el).color);
  expect(restoredColor).toBe(defaultColor);
});

test('TC-EDITOR-EYEDROPPER-003 — Cancelling (pointercancel) keeps the previous color and does not touch the custom slot', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  await page.locator('[data-testid="palette-color-pink"]').click();
  const before = await page.evaluate(() => activeColor);
  const customBefore = await page.locator('[data-testid="palette-color-custom"]').getAttribute('data-color');

  await page.locator('[data-testid="editor-eyedropper"]').click();
  const p = await artPoint(page, ...FACE);
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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

  await expect(page.locator('[data-testid="editor-settings-overlay"]')).toBeHidden();
  await page.locator('[data-testid="editor-settings-gear"]').click();

  await expect(page.locator('[data-testid="editor-settings-overlay"]')).toBeVisible();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-SETTINGS-001"]')).not.toHaveClass(/active/);
});

test('TC-EDITOR-SETTINGS-002 — Toggles work and Close preserves Editor state (artwork, tool, color, lock, history)', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

  await expect(page.locator('.workspace-settings')).toHaveCount(0);
  await expect(page.locator('[data-testid="tool-more"]')).toHaveCount(0);
});

test('TC-EDITOR-BRUSH-001 — Brush tool does not accidentally trigger Fill', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  // Brush is selected by default on entry.
  await expect(page.locator('[data-testid="tool-brush"]')).toHaveClass(/selected/);

  const before = await readCanvasPixel(page, 'editor-fill-canvas', ...NOSE);
  await tapInArtwork(page, ...NOSE); // a tap with Brush active must never run Fill's flood-fill
  const after = await readCanvasPixel(page, 'editor-fill-canvas', ...NOSE);
  expect(after).toEqual(before); // fillCanvas is untouched — only brushCanvas may have gained a dot
});

// Drags a short brush/erase stroke inside the FACE region (a large, verified
// open area) using real Pointer Events — never a synthetic DOM mutation — so
// the prototype's actual pointerdown/pointermove/pointerup engine runs.
async function dragOnArtboard(page, { dx = 60, dy = 25 } = {}) {
  const start = await artPoint(page, FACE[0], FACE[1]);
  const endArt = [FACE[0] + dx * (360 / 262), FACE[1] + dy * (360 / 262)]; // dx/dy in old ~262px-box units, scaled to art space
  const end = await artPoint(page, endArt[0], endArt[1]);
  await page.mouse.move(start.sx, start.sy);
  await page.mouse.down();
  await page.mouse.move((start.sx + end.sx) / 2, (start.sy + end.sy) / 2, { steps: 5 });
  await page.mouse.move(end.sx, end.sy, { steps: 5 });
  await page.mouse.up();
}

test('TC-EDITOR-BRUSH-002 — Brush drag with the selected color produces a visible stroke', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  await page.locator('[data-testid="palette-color-pink"]').click();
  await expect(page.locator('[data-testid="tool-brush"]')).toHaveClass(/selected/);

  await dragOnArtboard(page);

  const strokes = await page.evaluate(() => strokesList.length);
  expect(strokes).toBe(1);
  const color = await page.evaluate(() => strokesList[0].color);
  expect(color.toUpperCase()).toBe('#FF6D80');
});

test('TC-EDITOR-BRUSH-003 — Changing color does not recolor strokes already drawn', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  await page.locator('[data-testid="palette-color-pink"]').click();
  await dragOnArtboard(page, { dx: 40, dy: 10 });

  await page.locator('[data-testid="palette-color-blue"]').click();
  await dragOnArtboard(page, { dx: 40, dy: 40 });

  const colors = await page.evaluate(() => strokesList.map(s => s.color.toUpperCase()));
  expect(colors).toEqual(['#FF6D80', '#4A82FF']); // first stroke stays pink, only the new one is blue
});

test('TC-EDITOR-SLIDER-001 — Brush size slider changes new stroke width', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  await dragOnArtboard(page, { dx: 30, dy: 10 });
  const widthBefore = await page.evaluate(() => strokesList[0].width);

  await page.locator('[data-testid="editor-slider"]').evaluate(el => {
    el.value = 90;
    el.dispatchEvent(new Event('input', { bubbles: true }));
  });
  await dragOnArtboard(page, { dx: 30, dy: 40 });
  const widthAfter = await page.evaluate(() => strokesList[1].width);

  expect(widthAfter).toBeGreaterThan(widthBefore);
});

test('TC-EDITOR-ERASE-002 — Erase removes a user stroke via true transparent removal, not white paint', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  const lineArtBefore = await page.locator('.editor-screen .lineart').first().innerHTML();

  await page.locator('[data-testid="palette-color-purple"]').click();
  await dragOnArtboard(page, { dx: 50, dy: 20 });
  expect((await page.evaluate(() => strokesList[0].color)).toUpperCase()).toBe('#C34AD8');

  const paintedPixel = await readCanvasPixel(page, 'editor-brush-layer', ...FACE);
  expect(paintedPixel.a).toBeGreaterThan(0); // the purple stroke is opaque here

  await page.locator('[data-testid="tool-erase"]').click();
  await dragOnArtboard(page, { dx: 50, dy: 20 }); // erase over the same path

  const tools = await page.evaluate(() => strokesList.map(s => s.tool));
  expect(tools).toEqual(['brush', 'erase']);

  const erasedPixel = await readCanvasPixel(page, 'editor-brush-layer', ...FACE);
  expect(erasedPixel.a).toBe(0); // truly transparent (destination-out) — never repainted white

  const lineArtAfter = await page.locator('.editor-screen .lineart').first().innerHTML();
  expect(lineArtAfter).toBe(lineArtBefore); // original line art group is byte-for-byte unchanged — untouched underneath
});

test('TC-EDITOR-UNDO-001 — Undo/Redo reflect real history, never a faked enabled state', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  const undoBtn = page.locator('[data-testid="undo"]');
  const redoBtn = page.locator('[data-testid="redo"]');

  // Nothing to undo/redo yet on a fresh Editor entry.
  await expect(undoBtn).toBeDisabled();
  await expect(redoBtn).toBeDisabled();

  await page.locator('[data-testid="tool-fill"]').click();
  const original = await readCanvasPixel(page, 'editor-fill-canvas', ...MOUTH);
  await tapInArtwork(page, ...MOUTH);
  const filled = await readCanvasPixel(page, 'editor-fill-canvas', ...MOUTH);
  expect(filled).not.toEqual(original);

  await expect(undoBtn).toBeEnabled();
  await expect(redoBtn).toBeDisabled();

  await undoBtn.click();
  expect(await readCanvasPixel(page, 'editor-fill-canvas', ...MOUTH)).toEqual(original);
  await expect(undoBtn).toBeDisabled();
  await expect(redoBtn).toBeEnabled();

  await redoBtn.click();
  expect(await readCanvasPixel(page, 'editor-fill-canvas', ...MOUTH)).toEqual(filled);
  await expect(undoBtn).toBeEnabled();
  await expect(redoBtn).toBeDisabled();
});

test('TC-EDITOR-UNDO-002 — Undo removes the latest Brush stroke; Redo restores it', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  await dragOnArtboard(page);
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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);
  await expect(page.locator('[data-testid="editor-lock-toggle"]')).toHaveAttribute('aria-pressed', 'true'); // LOCKED by default

  await tapInArtwork(page, ...FACE);
  await tapInArtwork(page, ...LEFT_EAR);

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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  await tapInArtwork(page, ...FACE); // locked stroke
  expect(await page.evaluate(() => !!strokesList[0].maskCanvas)).toBe(true);

  await page.locator('[data-testid="editor-lock-toggle"]').click(); // UNLOCK
  await tapInArtwork(page, ...FACE); // free stroke, same start point

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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  await tapInArtwork(page, ...FACE); // locked stroke #1

  await page.locator('[data-testid="editor-lock-toggle"]').click(); // unlock
  await tapInArtwork(page, ...FACE); // free stroke

  await page.locator('[data-testid="editor-lock-toggle"]').click(); // lock again
  await tapInArtwork(page, ...RIGHT_EAR); // locked stroke #3, a different region

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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);
  await expect(page.locator('[data-testid="editor-lock-toggle"]')).toHaveAttribute('aria-pressed', 'true');

  await tapInArtwork(page, ...BG_ABOVE); // starts in the background above the head
  const info = await page.evaluate(() => ({
    count: strokesList.length,
    masked: strokesList.length === 1 && !!strokesList[0].maskCanvas,
  }));
  expect(info.count).toBe(1); // it was NOT rejected as "no valid region" — this is the fix under test
  expect(info.masked).toBe(true); // still contained to the background's own connected region
});

test('TC-EDITOR-LOCK-005 — Erase is never affected by Lock/Unlock', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);
  await expect(page.locator('[data-testid="editor-lock-toggle"]')).toHaveAttribute('aria-pressed', 'true');

  await page.locator('[data-testid="tool-erase"]').click();
  await tapInArtwork(page, ...FACE);

  const masked = await page.evaluate(() => !!strokesList[0].maskCanvas);
  expect(masked).toBe(false);
});

test('TC-EDITOR-PROGRESS-001 — Back then reopen preserves the drawn Brush stroke', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);
  await dragOnArtboard(page);
  expect(await page.evaluate(() => strokesList.length)).toBe(1);

  await active(page).locator('[aria-label="Back"]').click();
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);

  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  expect(await page.evaluate(() => strokesList.length)).toBe(1); // same in-memory stroke, not recreated or lost
});

test('TC-EDITOR-PROGRESS-002 — Completion header Back preserves the Brush stroke and COMPLETED status', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);
  await dragOnArtboard(page);

  await active(page).locator('[data-testid="editor-done"]').click();
  await expect(page.locator('[data-screen-id="SCR-COMPLETE-001"]')).toHaveClass(/active/);

  await active(page).locator('[data-testid="completion-back"]').click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  expect(await page.evaluate(() => strokesList.length)).toBe(1);

  const status = await page.evaluate(() => progressStore['draw_animals_001']);
  expect(status).toBe('COMPLETED'); // header Back never reverts completed status
});

test('TC-EDITOR-BACK-001 — Back returns to Home when Editor was entered from Home', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_manga_001"]').click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);

  await page.locator('.editor-topbar .editor-circle').click();
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
});

test('TC-EDITOR-BACK-002 — Back returns to Library when Editor was entered from Library', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-library"]').click();
  await active(page).locator('[data-testid="drawing-card-draw_food_001"]').click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);

  await page.locator('.editor-topbar .editor-circle').click();
  await expect(page.locator('[data-screen-id="SCR-LIBRARY-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
});

test('TC-EDITOR-BACK-003 — Back returns to Profile when Editor was entered from Profile, and preserves colored state', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="nav-profile"]').click();
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);

  await waitForBarrierMask(page);
  await page.locator('[data-testid="tool-fill"]').click();
  await tapInArtwork(page, ...MOUTH);
  const filledColor = await readCanvasPixel(page, 'editor-fill-canvas', ...MOUTH);

  await page.locator('.editor-topbar .editor-circle').click();
  await expect(page.locator('[data-screen-id="SCR-PROFILE-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);

  // Reopening the same artwork must show the state exactly as left, not reset.
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  expect(await readCanvasPixel(page, 'editor-fill-canvas', ...MOUTH)).toEqual(filledColor);

  const status = await page.evaluate(() => progressStore['draw_animals_001']);
  expect(status).toBe('IN_PROGRESS'); // resumed, not reset — status untouched by Back
});

test('TC-EDITOR-025 — Editor has no bottom navigation', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await expect(active(page).locator('.bottom-nav')).toHaveCount(0);
});

test('TC-SMOKE-004 — Prototype fill changes one region', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);

  await page.locator('[data-testid="tool-fill"]').click();

  const neighborBefore = await readCanvasPixel(page, 'editor-fill-canvas', ...NOSE);
  await tapInArtwork(page, ...MOUTH);

  const target = await readCanvasPixel(page, 'editor-fill-canvas', ...MOUTH);
  const neighborAfter = await readCanvasPixel(page, 'editor-fill-canvas', ...NOSE);
  expect(target.a).toBeGreaterThan(0); // filled — no longer transparent
  expect(neighborAfter).toEqual(neighborBefore); // adjacent region untouched
});

test('TC-EDITOR-023/FOCUS-001 — Maximize enters Focus mode; minimize exits it', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await page.locator('[data-testid="editor-fit"]').click();

  await expect(page.locator('.tool-rail')).toBeHidden();
  await expect(page.locator('.slider-wrap')).toBeHidden();
  await expect(page.locator('.palette')).toBeHidden();
  await expect(page.locator('.playful')).toBeHidden();
});

test('TC-EDITOR-FOCUS-003 — Top toolbar stays visible and functional in Focus mode', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

  const before = await page.locator('#artboard').boundingBox();
  await page.locator('[data-testid="editor-fit"]').click();
  await page.waitForTimeout(250); // CSS width transition
  const after = await page.locator('#artboard').boundingBox();

  expect(after.width).toBeGreaterThan(before.width);
});

test('TC-EDITOR-FOCUS-007 — Active-tool, active-color, and minimize controls share one baseline; Saved text is hidden', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await waitForBarrierMask(page);
  await page.locator('[data-testid="palette-color-purple"]').click();
  await page.locator('[data-testid="editor-lock-toggle"]').click(); // now UNLOCKED — confirms the state, not just the default

  await page.locator('[data-testid="editor-fit"]').click(); // enter Focus mode (Brush is still active by default)
  await dragOnArtboard(page); // the drawing engine listens on #brushCanvas regardless of the hidden rail/palette
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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

  await page.locator('[data-testid="editor-done"]').click();
  await expect(page.locator('[data-screen-id="SCR-COMPLETE-001"]')).toHaveClass(/active/);

  const status = await page.evaluate(() => progressStore['draw_animals_001']);
  expect(status).toBe('COMPLETED');
});

test('TC-COMPLETE-001 — Completion has no bottom navigation', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await page.locator('[data-testid="editor-done"]').click();

  await expect(active(page).locator('.bottom-nav')).toHaveCount(0);
});

test('TC-COMPLETE-002 — Back to home routes to Home directly (no Preview/Category/Library/Profile)', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
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
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);

  // Color a region so there's real state to verify is preserved.
  await waitForBarrierMask(page);
  await page.locator('[data-testid="tool-fill"]').click();
  await tapInArtwork(page, ...MOUTH);
  const filledColor = await readCanvasPixel(page, 'editor-fill-canvas', ...MOUTH);
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
  expect(reopenedId).toBe('draw_animals_001');

  // 7. Existing artwork state/progress is preserved (not a fresh blank session)
  expect(await readCanvasPixel(page, 'editor-fill-canvas', ...MOUTH)).toEqual(filledColor);

  // 8. Progress status remains COMPLETED (not reverted to IN_PROGRESS)
  let status = await page.evaluate(() => progressStore['draw_animals_001']);
  expect(status).toBe('COMPLETED');

  // 9. Done again returns to Completion, status still COMPLETED
  await page.locator('[data-testid="editor-done"]').click();
  await expect(page.locator('[data-screen-id="SCR-COMPLETE-001"]')).toHaveClass(/active/);
  status = await page.evaluate(() => progressStore['draw_animals_001']);
  expect(status).toBe('COMPLETED');

  // 10. Back to home is unaffected by this change — still goes to Home
  await page.locator('[data-testid="completion-back-home"]').click();
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
});

test('TC-COMPLETE-004 — Share shows a visible prototype confirmation', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await page.locator('[data-testid="editor-done"]').click();

  const status = page.locator('[data-testid="completion-share-status"]');
  await expect(status).toBeHidden();
  await page.locator('[data-testid="completion-share"]').click();
  await expect(status).toBeVisible();
});

test('TC-COMPLETE-005 — Save shows a visible prototype confirmation', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await page.locator('[data-testid="editor-done"]').click();

  const status = page.locator('[data-testid="completion-save-status"]');
  await expect(status).toBeHidden();
  await page.locator('[data-testid="completion-save"]').click();
  await expect(status).toBeVisible();
});

test('TC-COMPLETE-006 — Recommended artwork opens Coloring directly (resume-or-create)', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await page.locator('[data-testid="editor-done"]').click();

  const recommended = active(page).locator('[data-testid="completion-recommended"] .drawing-card').first();
  const recommendedId = await recommended.getAttribute('data-testid');
  await recommended.click();

  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-CATEGORY-001"]')).not.toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-EDITOR-001"]')).toHaveClass(/active/);
  expect(recommendedId).toMatch(/^drawing-card-draw_/);
});

test('TC-COMPLETE-007 — Recommended for you shows 4 cards excluding the just-completed artwork', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await page.locator('[data-testid="editor-done"]').click();

  const cards = active(page).locator('[data-testid="completion-recommended"] .drawing-card');
  await expect(cards).toHaveCount(4);
  await expect(active(page).locator('[data-testid="drawing-card-draw_animals_001"]')).toHaveCount(0);
});

test('TC-COMPLETE-008 — Completed artwork appears under Profile All and Completed, not In Progress', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await page.locator('[data-testid="editor-done"]').click();
  await page.locator('[data-testid="completion-back-home"]').click();

  await active(page).locator('[data-testid="nav-profile"]').click();

  await expect(page.locator('[data-testid="profile-segment-all"]')).toHaveClass(/selected/);
  await expect(active(page).locator('[data-testid="drawing-card-draw_animals_001"]')).toBeVisible();

  await page.locator('[data-testid="profile-segment-completed"]').click();
  await expect(active(page).locator('[data-testid="drawing-card-draw_animals_001"]')).toBeVisible();

  await page.locator('[data-testid="profile-segment-in-progress"]').click();
  await expect(active(page).locator('[data-testid="drawing-card-draw_animals_001"]')).toBeHidden();
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
  await expect(active(page).locator('[data-testid="drawing-card-draw_nature_001"]')).toBeVisible();
  await expect(active(page).locator('[data-testid="drawing-card-draw_animals_001"]')).toBeHidden();
});
