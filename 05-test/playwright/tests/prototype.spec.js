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

test('TC-EDITOR-022 — Palette selection does not immediately modify artwork', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

  const region = page.locator('#region_001');
  const before = await region.getAttribute('fill');

  await page.locator('[data-testid="palette-color-pink"]').click();
  await expect(region).toHaveAttribute('fill', before);
  await expect(page.locator('[data-testid="editor-active-color"]')).toHaveAttribute('data-active-color', '#FF6D80');
});

test('TC-EDITOR-BRUSH-001 — Brush tool does not accidentally trigger Fill', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

  // Brush is selected by default on entry.
  await expect(page.locator('[data-testid="tool-brush"]')).toHaveClass(/selected/);

  const region = page.locator('#region_001');
  const before = await region.getAttribute('fill');
  await region.click();
  await expect(region).toHaveAttribute('fill', before);
});

test('TC-EDITOR-UNDO-001 — Undo/Redo reflect real history, never a faked enabled state', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

  const undoBtn = page.locator('[data-testid="undo"]');
  const redoBtn = page.locator('[data-testid="redo"]');

  // Nothing to undo/redo yet on a fresh Editor entry.
  await expect(undoBtn).toBeDisabled();
  await expect(redoBtn).toBeDisabled();

  await page.locator('[data-testid="tool-fill"]').click();
  const region = page.locator('#region_001');
  const original = await region.getAttribute('fill');
  await region.click();
  const filled = await region.getAttribute('fill');
  expect(filled).not.toBe(original);

  await expect(undoBtn).toBeEnabled();
  await expect(redoBtn).toBeDisabled();

  await undoBtn.click();
  await expect(region).toHaveAttribute('fill', original);
  await expect(undoBtn).toBeDisabled();
  await expect(redoBtn).toBeEnabled();

  await redoBtn.click();
  await expect(region).toHaveAttribute('fill', filled);
  await expect(undoBtn).toBeEnabled();
  await expect(redoBtn).toBeDisabled();
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

  await page.locator('[data-testid="tool-fill"]').click();
  await page.locator('#region_001').click();
  const filledColor = await page.locator('#region_001').getAttribute('fill');

  await page.locator('.editor-topbar .editor-circle').click();
  await expect(page.locator('[data-screen-id="SCR-PROFILE-001"]')).toHaveClass(/active/);
  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).not.toHaveClass(/active/);

  // Reopening the same artwork must show the state exactly as left, not reset.
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await expect(page.locator('#region_001')).toHaveAttribute('fill', filledColor);

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

  // Select Fill
  await page.locator('[data-testid="tool-fill"]').click();

  const target = page.locator('#region_001');
  const neighbor = page.locator('#region_002');

  const beforeNeighbor = await neighbor.getAttribute('fill');
  await target.click();

  await expect(target).not.toHaveAttribute('fill', '#fff');
  await expect(neighbor).toHaveAttribute('fill', beforeNeighbor);
});

test('TC-EDITOR-023 — Fit/Zoom quick action changes viewport only', async ({ page }) => {
  await openHome(page);
  await active(page).locator('[data-testid="drawing-card-draw_animals_001"]').click();

  const artboard = page.locator('#artboard');
  await expect(artboard).not.toHaveClass(/zoomed/);

  await page.locator('[data-testid="editor-fit"]').click();
  await expect(artboard).toHaveClass(/zoomed/);
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
  await page.locator('[data-testid="tool-fill"]').click();
  await page.locator('#region_001').click();
  const filledColor = await page.locator('#region_001').getAttribute('fill');
  expect(filledColor).not.toBe('#fff');

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
  await expect(page.locator('#region_001')).toHaveAttribute('fill', filledColor);

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
