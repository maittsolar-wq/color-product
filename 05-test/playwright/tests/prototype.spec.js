const { test, expect } = require('@playwright/test');

async function openHome(page) {
  await page.goto('/');
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
}

test('TC-SMOKE-002/003 — Home to Preview to Editor', async ({ page }) => {
  await openHome(page);

  await page.locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await expect(page.locator('[data-screen-id="SCR-PREVIEW-001"]')).toHaveClass(/active/);

  await page.locator('[data-testid="start-coloring"]').click();
  await expect(page.locator('[data-testid="coloring-canvas"]')).toBeVisible();
});

test('TC-EDITOR-016/017/018 — Tool rail selection', async ({ page }) => {
  await openHome(page);
  await page.locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await page.locator('[data-testid="start-coloring"]').click();

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
  await page.locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await page.locator('[data-testid="start-coloring"]').click();

  const pink = page.locator('[data-testid="palette-color-pink"]');
  await pink.click();
  await expect(pink).toHaveClass(/selected/);
});

test('TC-SMOKE-004 — Prototype fill changes one region', async ({ page }) => {
  await openHome(page);
  await page.locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await page.locator('[data-testid="start-coloring"]').click();

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
  await page.locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await page.locator('[data-testid="start-coloring"]').click();

  const artboard = page.locator('#artboard');
  await expect(artboard).not.toHaveClass(/zoomed/);

  await page.locator('[data-testid="editor-fit"]').click();
  await expect(artboard).toHaveClass(/zoomed/);
});

test('TC-EDITOR-024 — Done opens Completion', async ({ page }) => {
  await openHome(page);
  await page.locator('[data-testid="drawing-card-draw_animals_001"]').click();
  await page.locator('[data-testid="start-coloring"]').click();

  await page.locator('[data-testid="editor-done"]').click();
  await expect(page.locator('[data-screen-id="SCR-COMPLETE-001"]')).toHaveClass(/active/);
});

test('TC-WORK-001 — My Works opens', async ({ page }) => {
  await openHome(page);
  await page.locator('[data-testid="my-works"]').click();
  await expect(page.locator('[data-screen-id="SCR-WORKS-001"]')).toHaveClass(/active/);
});

test('TC-MON-002 — Paywall close returns to Home', async ({ page }) => {
  await openHome(page);
  await page.locator('[data-testid="premium-home"]').click();
  await expect(page.locator('[data-screen-id="SCR-PAYWALL-001"]')).toHaveClass(/active/);

  await page.locator('.paywall-close').click();
  await expect(page.locator('[data-screen-id="SCR-HOME-001"]')).toHaveClass(/active/);
});

test('TC-SET-001 — Settings opens', async ({ page }) => {
  await openHome(page);
  await page.locator('[data-testid="settings"]').click();
  await expect(page.locator('[data-screen-id="SCR-SETTINGS-001"]')).toHaveClass(/active/);
});
