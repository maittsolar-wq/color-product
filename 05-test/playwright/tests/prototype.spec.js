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
  // Uses dispatchEvent('click'): region_001/region_002 have a known,
  // pre-existing, unrelated geometric overlap in the Editor SVG (see
  // TC-SMOKE-004) — a real mouse click at region_001's screen coordinates
  // actually lands on region_002 (even with force:true, since that still
  // uses real hit-testing). dispatchEvent fires the click directly on the
  // element, bypassing hit-testing — it does not touch or fix Editor.
  await page.locator('[data-testid="tool-fill"]').click();
  await page.locator('#region_001').dispatchEvent('click');
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
