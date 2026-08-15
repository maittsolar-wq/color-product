let activeColor = '#168B2D';
let activeTool = 'brush';
let zoomed = false;
let currentArtworkId = 'draw_animals_001';
// The screen Editor was entered from, captured fresh each time openArtwork()
// runs. Editor's own Back button returns here — per NAV-008 this must be
// "the actual previous screen" (Home/Library/Profile/Completion), never the
// legacy Preview/Category hop.
let editorOrigin = 'SCR-HOME-001';

// Session-only fill history (data-model.md: activeTool/activeColor/etc. are
// explicitly session-only, not persisted Progress fields — undo/redo history
// belongs in that same category). Reset whenever Editor is freshly entered.
// Entries are tagged { type: 'fill' | 'stroke', ... } — see pushHistory().
let undoStack = [];
let redoStack = [];
const HISTORY_LIMIT = 40; // modest capped history — prototype only, not an unlimited production log

// In-progress Brush/Erase stroke ({ points, color, width, maskCanvas }),
// cleared on pointerup/pointercancel. See the shared closed-region engine
// and drawing functions further below.
let activeStroke = null;

const progressStore = {
  draw_animals_001: 'IN_PROGRESS',
  draw_nature_001: 'COMPLETED'
};

// Recency signal only, for the Continue card's "most recently updated wins"
// rule (data-model.md already documents Progress.updatedAt — this is that
// field for the prototype's flat progressStore, not a second status store).
const progressUpdatedAt = {
  draw_animals_001: Date.now()
};

// Display metadata for artwork already introduced on Home/Library. Profile
// renders purely from progressStore (the single source of truth for which
// artworks have progress); this table only supplies title/thumbnail for
// whatever IDs happen to be in progressStore — it is not a second store.
const ARTWORK_LIBRARY = {
  draw_manga_001: { title: 'Moon Samurai', thumbClass: 'thumb-lilac', thumbContent: '☾' },
  draw_manga_002: { title: 'Star Racer', thumbClass: 'thumb-blue', thumbContent: '☆' },
  draw_manga_003: { title: 'Ink Fox', thumbClass: 'thumb-pink', thumbContent: '✎' },
  draw_animals_001: { title: 'Little Elephant', thumbClass: 'thumb-pink', thumbImg: 'assets/elephant-lineart.svg' },
  draw_animals_002: { title: 'Penguin Family', thumbClass: 'thumb-blue', thumbContent: '☁' },
  draw_animals_003: { title: 'Baby Deer', thumbClass: 'thumb-green', thumbContent: '♧' },
  draw_food_001: { title: 'Donut Stack', thumbClass: 'thumb-blue', thumbContent: '◍' },
  draw_food_002: { title: 'Cupcake Swirl', thumbClass: 'thumb-pink', thumbContent: '✤' },
  draw_food_003: { title: 'Berry Bowl', thumbClass: 'thumb-green', thumbContent: '✧' },
  draw_nature_001: { title: 'Moon Flowers', thumbClass: 'thumb-lilac', thumbContent: '✿' },
  draw_nature_002: { title: 'Flower Fairy', thumbClass: 'thumb-pink', thumbContent: '✾' },
  draw_nature_003: { title: 'Misty Forest', thumbClass: 'thumb-green', thumbContent: '♣' }
};

function showScreen(id){
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  const target = document.querySelector(`[data-screen-id="${id}"]`);
  if(target) target.classList.add('active');
  // Re-evaluate every time Home becomes active (not just cold start) so the
  // card reflects the latest state after returning from Editor/Completion/etc.
  if(id === 'SCR-HOME-001') renderHomeContinue();
}

function openArtwork(drawingId){
  const activeScreen = document.querySelector('.screen.active');
  if(activeScreen) editorOrigin = activeScreen.dataset.screenId;

  currentArtworkId = drawingId;
  if(!progressStore[drawingId]){
    progressStore[drawingId] = 'IN_PROGRESS';
  }
  progressUpdatedAt[drawingId] = Date.now();

  undoStack = [];
  redoStack = [];
  activeStroke = null;
  updateHistoryButtons();

  showScreen('SCR-EDITOR-001');
}

function exitEditor(){
  // Autosave is already continuous (Fill/Brush/undo/redo flip the Saving/
  // Saved indicator immediately); this just returns to wherever the user
  // actually came from — never a hardcoded Preview/Category hop.
  showScreen(editorOrigin);
}

function completeArtwork(){
  progressStore[currentArtworkId] = 'COMPLETED';
  progressUpdatedAt[currentArtworkId] = Date.now();
  renderCompletion();
  showScreen('SCR-COMPLETE-001');
}

function getContinueArtworkId(){
  const inProgressIds = Object.keys(progressStore).filter(id => progressStore[id] === 'IN_PROGRESS');
  if(inProgressIds.length === 0) return null;
  return inProgressIds.sort((a, b) => (progressUpdatedAt[b] || 0) - (progressUpdatedAt[a] || 0))[0];
}

function renderHomeContinue(){
  const card = document.querySelector('[data-testid="continue-coloring"]');
  if(!card) return;

  const id = getContinueArtworkId();
  if(!id){
    card.hidden = true;
    return;
  }

  const meta = ARTWORK_LIBRARY[id] || { title: id, thumbClass: 'thumb-blue', thumbContent: '★' };
  card.hidden = false;
  card.dataset.artworkId = id;

  const title = card.querySelector('.continue-title');
  if(title) title.textContent = meta.title;

  const art = card.querySelector('.continue-art');
  if(art){
    art.innerHTML = '';
    art.className = 'continue-art';
    if(meta.thumbImg){
      const img = document.createElement('img');
      img.src = meta.thumbImg;
      art.appendChild(img);
    } else {
      const symbol = document.createElement('div');
      symbol.className = `thumb ${meta.thumbClass}`;
      symbol.textContent = meta.thumbContent;
      art.appendChild(symbol);
    }
  }
}

function continueCurrentArtwork(){
  const id = getContinueArtworkId();
  if(!id) return; // card should be hidden already if this is null
  openArtwork(id);
}

// Candidate pool for "Recommended for you" — filtered to exclude whatever was
// just completed. Not a second artwork store: titles/thumbs still come from
// ARTWORK_LIBRARY, and opening still goes through the shared openArtwork().
const RECOMMENDED_POOL = [
  'draw_manga_001', 'draw_animals_002', 'draw_nature_002', 'draw_food_001',
  'draw_manga_002', 'draw_animals_003', 'draw_nature_003', 'draw_food_002'
];

function renderCompletion(){
  const scope = document.querySelector('[data-screen-id="SCR-COMPLETE-001"]');
  if(!scope) return;

  const shareStatus = scope.querySelector('[data-testid="completion-share-status"]');
  const saveStatus = scope.querySelector('[data-testid="completion-save-status"]');
  if(shareStatus) shareStatus.hidden = true;
  if(saveStatus) saveStatus.hidden = true;

  const meta = ARTWORK_LIBRARY[currentArtworkId] || { thumbClass: 'thumb-blue', thumbContent: '★' };
  const card = scope.querySelector('[data-testid="completion-artwork"]');
  if(card){
    card.className = 'completion-artwork-card';
    card.innerHTML = '';
    // For the one artwork with real interactive state, composite the live
    // Fill/Brush canvases + line art into a static image rather than falling
    // back to the flat thumbnail — "the most faithful available way" the
    // prototype can show it. Async (canvas/SVG rasterization) — the flat
    // thumbnail (if any) shows immediately and is swapped once ready.
    if(currentArtworkId === 'draw_animals_001'){
      const img = document.createElement('img');
      img.alt = meta.title || '';
      card.appendChild(img);
      renderArtboardToDataURL(dataUrl => { img.src = dataUrl; });
    } else if(meta.thumbImg){
      const img = document.createElement('img');
      img.src = meta.thumbImg;
      card.appendChild(img);
    } else {
      card.classList.add(meta.thumbClass);
      card.textContent = meta.thumbContent;
    }
  }

  const grid = scope.querySelector('[data-testid="completion-recommended"]');
  if(grid){
    grid.innerHTML = '';
    RECOMMENDED_POOL
      .filter(id => id !== currentArtworkId)
      .slice(0, 4)
      .forEach(id => {
        const cardMeta = ARTWORK_LIBRARY[id] || { title: id, thumbClass: 'thumb-blue', thumbContent: '★' };
        const btn = document.createElement('button');
        btn.className = 'drawing-card';
        btn.dataset.testid = `drawing-card-${id}`;
        btn.onclick = () => openArtwork(id);

        const thumb = document.createElement('div');
        thumb.className = `thumb ${cardMeta.thumbClass}`;
        if(cardMeta.thumbImg){
          const img = document.createElement('img');
          img.src = cardMeta.thumbImg;
          thumb.appendChild(img);
        } else {
          thumb.textContent = cardMeta.thumbContent;
        }

        const title = document.createElement('b');
        title.textContent = cardMeta.title;

        btn.append(thumb, title);
        grid.appendChild(btn);
      });
  }
}

function reopenCompletedArtwork(){
  // Completion header Back: reopen the SAME artwork just completed.
  // openArtwork() already resumes existing progress without touching status
  // when a record exists (COMPLETED here) — pure reuse, no separate
  // opening system, and distinct from "Back to home" (showScreen to Home).
  openArtwork(currentArtworkId);
}

function shareCompletion(){
  const scope = document.querySelector('[data-screen-id="SCR-COMPLETE-001"]');
  const status = scope && scope.querySelector('[data-testid="completion-share-status"]');
  if(status) status.hidden = false;
}

function saveCompletion(){
  const scope = document.querySelector('[data-screen-id="SCR-COMPLETE-001"]');
  const status = scope && scope.querySelector('[data-testid="completion-save-status"]');
  if(status) status.hidden = false;
}

function filterLibrary(categoryId, btn){
  const scope = document.querySelector('[data-screen-id="SCR-LIBRARY-001"]');
  if(!scope) return;
  scope.querySelectorAll('.filter-chips button').forEach(b => b.classList.remove('selected'));
  if(btn) btn.classList.add('selected');

  const grid = scope.querySelector('[data-testid="library-grid"]');
  const cards = scope.querySelectorAll('.drawing-card');
  let visibleCount = 0;
  cards.forEach(card => {
    const show = categoryId === 'all' || card.dataset.category === categoryId;
    card.style.display = show ? '' : 'none';
    if(show) visibleCount++;
  });
  if(grid) grid.dataset.activeFilter = categoryId;

  const emptyState = scope.querySelector('[data-testid="library-empty-state"]');
  if(emptyState) emptyState.hidden = visibleCount > 0;
}

function openLibrary(categoryId){
  showScreen('SCR-LIBRARY-001');
  const btn = document.querySelector(`[data-screen-id="SCR-LIBRARY-001"] [data-testid="library-filter-${categoryId}"]`);
  filterLibrary(categoryId, btn);
}

// Library filter/state captured when Search opens, so Back can restore it —
// distinct from "Explore library", which always forces "All" (REQ-LIB-010/011).
let libraryReturnFilter = 'all';

function openSearch(){
  const libScope = document.querySelector('[data-screen-id="SCR-LIBRARY-001"]');
  const grid = libScope && libScope.querySelector('[data-testid="library-grid"]');
  libraryReturnFilter = (grid && grid.dataset.activeFilter) || 'all';

  const input = document.querySelector('[data-testid="search-input"]');
  if(input) input.value = '';
  renderSearch('');

  showScreen('SCR-SEARCH-001');
}

function onSearchInput(value){
  renderSearch(value);
}

function clearSearch(){
  const input = document.querySelector('[data-testid="search-input"]');
  if(input){
    input.value = '';
    input.focus();
  }
  renderSearch('');
}

function renderSearch(query){
  const scope = document.querySelector('[data-screen-id="SCR-SEARCH-001"]');
  if(!scope) return;

  const clearBtn = scope.querySelector('[data-testid="search-clear"]');
  const grid = scope.querySelector('[data-testid="search-results-grid"]');
  const emptyState = scope.querySelector('[data-testid="search-empty-state"]');
  const trimmed = query.trim();

  if(clearBtn) clearBtn.hidden = trimmed.length === 0;

  if(trimmed.length === 0){
    if(grid){ grid.hidden = true; grid.innerHTML = ''; }
    if(emptyState) emptyState.hidden = true;
    return;
  }

  // Matches against the same artwork title metadata already used by
  // Library/Home/Profile — no separate search index/database (REQ-LIB-009).
  const q = trimmed.toLowerCase();
  const matches = Object.keys(ARTWORK_LIBRARY).filter(id =>
    ARTWORK_LIBRARY[id].title.toLowerCase().includes(q)
  );

  if(matches.length === 0){
    if(grid){ grid.hidden = true; grid.innerHTML = ''; }
    if(emptyState) emptyState.hidden = false;
    return;
  }

  if(emptyState) emptyState.hidden = true;
  if(grid){
    grid.hidden = false;
    grid.innerHTML = '';
    matches.forEach(id => {
      const meta = ARTWORK_LIBRARY[id];
      const btn = document.createElement('button');
      btn.className = 'drawing-card';
      btn.dataset.testid = `drawing-card-${id}`;
      // Same shared resolver as Home/Library/Profile — no duplicate opening system.
      btn.onclick = () => openArtwork(id);

      const thumb = document.createElement('div');
      thumb.className = `thumb ${meta.thumbClass}`;
      if(meta.thumbImg){
        const img = document.createElement('img');
        img.src = meta.thumbImg;
        thumb.appendChild(img);
      } else {
        thumb.textContent = meta.thumbContent;
      }

      const title = document.createElement('b');
      title.textContent = meta.title;

      btn.append(thumb, title);
      grid.appendChild(btn);
    });
  }
}

function closeSearch(){
  showScreen('SCR-LIBRARY-001');
  const btn = document.querySelector(`[data-screen-id="SCR-LIBRARY-001"] [data-testid="library-filter-${libraryReturnFilter}"]`);
  filterLibrary(libraryReturnFilter, btn);
}

function exploreLibraryFromSearch(){
  openLibrary('all');
}

function openProfile(){
  showScreen('SCR-PROFILE-001');
  renderProfile();
}

function renderProfile(){
  const scope = document.querySelector('[data-screen-id="SCR-PROFILE-001"]');
  if(!scope) return;

  const hasProgress = Object.keys(progressStore).length > 0;
  const emptyState = scope.querySelector('[data-testid="profile-empty-state"]');
  const segmented = scope.querySelector('[data-testid="profile-segmented"]');
  const grid = scope.querySelector('[data-testid="profile-grid"]');

  if(!hasProgress){
    if(emptyState) emptyState.hidden = false;
    if(segmented) segmented.hidden = true;
    if(grid) grid.hidden = true;
    return;
  }

  if(emptyState) emptyState.hidden = true;
  if(segmented) segmented.hidden = false;
  if(grid) grid.hidden = false;
  renderProfileGrid();
}

function filterProfile(segment, btn){
  const scope = document.querySelector('[data-screen-id="SCR-PROFILE-001"]');
  if(!scope) return;
  scope.querySelectorAll('.profile-segmented button').forEach(b => b.classList.remove('selected'));
  if(btn) btn.classList.add('selected');
  // Switching segments only changes what's visible, never progressStore itself.
  renderProfileGrid();
}

function renderProfileGrid(){
  const scope = document.querySelector('[data-screen-id="SCR-PROFILE-001"]');
  if(!scope) return;

  const grid = scope.querySelector('[data-testid="profile-grid"]');
  const segmentEmpty = scope.querySelector('[data-testid="profile-segment-empty"]');
  const activeBtn = scope.querySelector('.profile-segmented .selected');
  const segment = activeBtn ? activeBtn.dataset.segment : 'all';

  grid.innerHTML = '';
  let visibleCount = 0;

  Object.keys(progressStore).forEach(drawingId => {
    const status = progressStore[drawingId];
    const matches =
      segment === 'all' ||
      (segment === 'in_progress' && status === 'IN_PROGRESS') ||
      (segment === 'completed' && status === 'COMPLETED');
    if(!matches) return;

    visibleCount++;
    const meta = ARTWORK_LIBRARY[drawingId] || { title: drawingId, thumbClass: 'thumb-blue', thumbContent: '★' };

    const card = document.createElement('button');
    card.className = 'drawing-card';
    card.dataset.testid = `drawing-card-${drawingId}`;
    card.dataset.status = status === 'IN_PROGRESS' ? 'in_progress' : 'completed';
    // Profile only ever lists IDs already in progressStore, so this always
    // resumes existing progress — the create branch in openArtwork() never
    // fires from here. No separate Profile-only opening path is created.
    card.onclick = () => openArtwork(drawingId);

    const thumb = document.createElement('div');
    thumb.className = `thumb ${meta.thumbClass}`;
    if(meta.thumbImg){
      const img = document.createElement('img');
      img.src = meta.thumbImg;
      thumb.appendChild(img);
    } else {
      thumb.textContent = meta.thumbContent;
    }

    const title = document.createElement('b');
    title.textContent = meta.title;

    const statusLabel = document.createElement('span');
    statusLabel.textContent = status === 'IN_PROGRESS' ? 'In Progress' : 'Completed';

    card.append(thumb, title, statusLabel);
    grid.appendChild(card);
  });

  if(segmentEmpty) segmentEmpty.hidden = visibleCount > 0;
}

// Shared across Profile Settings (SCR-SETTINGS-001) and the Editor Settings
// sheet — "Sounds" is the same app-wide toggle in both places, so both
// instances (matched via data-setting-key) stay visually in sync no matter
// which one is tapped. colorHistory/mirrorMode only exist in Editor Settings.
const settingsState = { sound: true, colorHistory: false, mirrorMode: false };

function toggleSetting(key, btn){
  settingsState[key] = !settingsState[key];
  const on = settingsState[key];
  document.querySelectorAll(`[data-setting-key="${key}"]`).forEach(b => {
    b.setAttribute('aria-checked', String(on));
    const sw = b.querySelector('.toggle-switch');
    if(sw) sw.dataset.state = on ? 'on' : 'off';
  });
}

function openEditorSettings(){
  const overlay = document.querySelector('[data-testid="editor-settings-overlay"]');
  if(overlay) overlay.hidden = false;
}

function closeEditorSettings(){
  // Just hides the overlay — artwork/activeTool/activeColor/Lock/history all
  // live outside this sheet entirely, so nothing here can touch them.
  const overlay = document.querySelector('[data-testid="editor-settings-overlay"]');
  if(overlay) overlay.hidden = true;
}

// There is always exactly ONE focused/selected swatch. applyActiveColor()
// sets activeColor and focuses the GIVEN element specifically — it never
// searches for "a matching preset," so callers are explicit about which
// swatch represents the new color (req. 10: never focus two at once, never
// falsely light an unrelated preset).
function applyActiveColor(hex, focusBtn){
  activeColor = hex.toUpperCase();
  const palette = document.querySelector('.palette');
  if(palette) palette.dataset.activeColor = activeColor;
  if(focusBtn) focusPaletteSwatch(focusBtn);
  syncFocusIndicators();
}

function focusPaletteSwatch(btn){
  document.querySelectorAll('.palette .color').forEach(c => {
    const isMatch = c === btn;
    c.classList.toggle('selected', isMatch);
    c.setAttribute('aria-pressed', String(isMatch));
  });
}

function selectColor(btn){
  applyActiveColor(btn.dataset.color, btn);
}

// Playful's Previous/Next arrows — step through ALL palette swatches
// (presets + the right-most custom slot) in DOM order, wrapping at either end.
function stepPaletteColor(direction){
  const swatches = Array.from(document.querySelectorAll('.palette .color'));
  if(swatches.length === 0) return;
  let index = swatches.findIndex(s => s.classList.contains('selected'));
  if(index === -1) index = direction > 0 ? -1 : 0;
  const nextIndex = (index + direction + swatches.length) % swatches.length;
  selectColor(swatches[nextIndex]);
  swatches[nextIndex].focus();
}

// Color Picker Save and Eyedropper release both target the SAME dedicated
// right-most palette slot — replace its color and focus it, unconditionally,
// even when the chosen color happens to match an existing preset exactly.
function setCustomPaletteColor(hex){
  const customBtn = document.querySelector('[data-testid="palette-color-custom"]');
  if(!customBtn) return;
  const upper = hex.toUpperCase();
  customBtn.dataset.color = upper;
  customBtn.style.setProperty('--c', upper);
  applyActiveColor(upper, customBtn);
}

function selectTool(btn, tool){
  activeTool = tool;
  document.querySelectorAll('.tool-rail button').forEach(b=>{
    b.classList.remove('selected');
    if(b.hasAttribute('aria-pressed')) b.setAttribute('aria-pressed','false');
  });
  btn.classList.add('selected');
  if(btn.hasAttribute('aria-pressed')) btn.setAttribute('aria-pressed','true');
  const rail = document.querySelector('.tool-rail');
  if(rail) rail.dataset.activeTool = activeTool;
  syncFocusIndicators();
}

// Keeps Focus mode's compact tool/color indicators correct at all times —
// updated on every tool/color change regardless of whether Focus mode is
// currently visible, so it's always accurate the moment it appears.
function syncFocusIndicators(){
  const toolIcon = document.querySelector('[data-testid="focus-active-tool-icon"]');
  if(toolIcon) toolIcon.className = `tool-icon tool-icon-${activeTool}`;
  const toolWrap = document.querySelector('[data-testid="focus-active-tool"]');
  if(toolWrap) toolWrap.setAttribute('aria-label', `Current tool: ${activeTool.charAt(0).toUpperCase()}${activeTool.slice(1)}`);
  const colorIndicator = document.querySelector('[data-testid="focus-active-color"]');
  if(colorIndicator) colorIndicator.style.setProperty('--c', activeColor);
}

function markSaving(){
  const status = document.getElementById('saveStatus');
  if(!status) return;
  status.textContent = 'Saving...';
  setTimeout(()=>status.textContent='Saved',350);
}

// Generalized history entry point for every editable action (Fill, Brush
// stroke, Erase stroke). Keeps a single capped stack instead of a separate
// mechanism per tool.
function pushHistory(action){
  undoStack.push(action);
  if(undoStack.length > HISTORY_LIMIT) undoStack.shift();
  redoStack = [];
  updateHistoryButtons();
}

function updateHistoryButtons(){
  const undoBtn = document.querySelector('[data-testid="undo"]');
  const redoBtn = document.querySelector('[data-testid="redo"]');
  if(undoBtn) undoBtn.disabled = undoStack.length === 0;
  if(redoBtn) redoBtn.disabled = redoStack.length === 0;
}

function applyActionInverse(action){
  if(action.type === 'fill'){
    document.getElementById('fillCanvas').getContext('2d').putImageData(action.before, 0, 0);
  } else if(action.type === 'stroke'){
    const idx = strokesList.indexOf(action.stroke);
    if(idx !== -1) strokesList.splice(idx, 1);
    redrawBrushCanvas();
  }
}

function applyActionForward(action){
  if(action.type === 'fill'){
    document.getElementById('fillCanvas').getContext('2d').putImageData(action.after, 0, 0);
  } else if(action.type === 'stroke'){
    strokesList.push(action.stroke);
    redrawBrushCanvas();
  }
}

function undoAction(){
  if(undoStack.length === 0) return; // never fake an enabled state with nothing to undo
  const action = undoStack.pop();
  applyActionInverse(action);
  redoStack.push(action);
  if(redoStack.length > HISTORY_LIMIT) redoStack.shift();
  progressUpdatedAt[currentArtworkId] = Date.now();
  updateHistoryButtons();
  markSaving();
}

function redoAction(){
  if(redoStack.length === 0) return;
  const action = redoStack.pop();
  applyActionForward(action);
  undoStack.push(action);
  if(undoStack.length > HISTORY_LIMIT) undoStack.shift();
  progressUpdatedAt[currentArtworkId] = Date.now();
  updateHistoryButtons();
  markSaving();
}

// LOCKED/UNLOCKED only ever changes how a NEW Brush stroke behaves — it is
// never applied retroactively. Each stroke independently detects, at its own
// pointerdown, the connected region the pointer started in (via the shared
// region-mask engine below) and is clipped to only that region for its own
// lifetime. Switching Lock state, or drawing more strokes, never touches any
// earlier stroke's already-baked-in mask.
let coloringLocked = true;

function toggleColoringLock(btn){
  coloringLocked = !coloringLocked;
  btn.setAttribute('aria-pressed', String(coloringLocked));
}

// ===========================================================================
// SHARED CLOSED-REGION ENGINE — used by BOTH Locked Brush and Fill.
//
// The immutable line art is rasterized once (off the visible DOM, from a
// clone of the .lineart/.fill-region geometry — the original is never
// touched) into a barrier bitmap: sufficiently dark/opaque pixels are
// BARRIERS, one pixel of dilation is added so anti-aliased line edges don't
// leak between regions, and the raster's own edges are implicit barriers
// (the artwork rectangle boundary). floodFillMaskFrom() then does a 4-
// directional flood fill from a start point across non-barrier pixels,
// returning a same-size boolean mask of the connected region — which is
// exactly as valid for the white background surrounding the subject as it
// is for any internal enclosed area, since both are just "non-barrier
// pixels reachable from the start point" to this engine.
// ===========================================================================

const RASTER_SIZE = 360; // matches the artwork's own viewBox — 1 raster px per SVG unit
let barrierMask = null; // Uint8Array, RASTER_SIZE*RASTER_SIZE, 1 = barrier
let barrierMaskReady = false;

function buildBarrierMask(){
  const svgRoot = document.getElementById('artboardSvg');
  if(!svgRoot) return;
  const svgNS = 'http://www.w3.org/2000/svg';
  const tempSvg = document.createElementNS(svgNS, 'svg');
  tempSvg.setAttribute('viewBox', '0 0 360 360');
  tempSvg.setAttribute('width', String(RASTER_SIZE));
  tempSvg.setAttribute('height', String(RASTER_SIZE));

  // Immutable line art, unmodified.
  svgRoot.querySelectorAll('.lineart').forEach(g => tempSvg.appendChild(g.cloneNode(true)));
  // The mouth/nose outlines also act as barriers (their own enclosed area is
  // a distinct region from the surrounding face) — only the outline stroke
  // matters here, never a filled block, regardless of what fill-region.
  svgRoot.querySelectorAll('.fill-region').forEach(shape => {
    const clone = shape.cloneNode(true);
    clone.setAttribute('fill', 'none');
    tempSvg.appendChild(clone);
  });

  const svgStr = new XMLSerializer().serializeToString(tempSvg);
  const blob = new Blob([svgStr], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const img = new Image();
  img.onload = () => {
    const canvas = document.createElement('canvas');
    canvas.width = RASTER_SIZE; canvas.height = RASTER_SIZE;
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    ctx.drawImage(img, 0, 0, RASTER_SIZE, RASTER_SIZE);
    const data = ctx.getImageData(0, 0, RASTER_SIZE, RASTER_SIZE).data;
    const mask = new Uint8Array(RASTER_SIZE * RASTER_SIZE);
    for(let i = 0; i < RASTER_SIZE * RASTER_SIZE; i++){
      const a = data[i * 4 + 3];
      const darkness = 255 - (data[i * 4] + data[i * 4 + 1] + data[i * 4 + 2]) / 3;
      mask[i] = (a > 40 && darkness > 90) ? 1 : 0; // threshold tolerant of anti-aliased edges
    }
    dilateBarrierMask(mask, RASTER_SIZE, RASTER_SIZE, 1);
    barrierMask = mask;
    barrierMaskReady = true;
    URL.revokeObjectURL(url);
  };
  img.src = url;
}

function dilateBarrierMask(mask, w, h, radius){
  const copy = mask.slice();
  for(let y = 0; y < h; y++){
    for(let x = 0; x < w; x++){
      if(copy[y * w + x]) continue;
      let hit = false;
      for(let dy = -radius; dy <= radius && !hit; dy++){
        for(let dx = -radius; dx <= radius && !hit; dx++){
          const nx = x + dx, ny = y + dy;
          if(nx >= 0 && nx < w && ny >= 0 && ny < h && copy[ny * w + nx]) hit = true;
        }
      }
      if(hit) mask[y * w + x] = 1;
    }
  }
}

// Stack-based 4-directional flood fill. Returns a Uint8Array mask of the
// connected non-barrier region containing (px,py), or null if the point
// itself is a barrier (tapped directly on a line) or the mask isn't ready
// yet. Out-of-bounds is an implicit barrier — the raster edge IS the
// artwork rectangle boundary, so the surrounding background region is
// naturally bounded by it exactly like any internal enclosed area.
function floodFillMaskFrom(px, py){
  if(!barrierMaskReady || !barrierMask) return null;
  const w = RASTER_SIZE, h = RASTER_SIZE;
  const sx = Math.max(0, Math.min(w - 1, Math.round(px)));
  const sy = Math.max(0, Math.min(h - 1, Math.round(py)));
  if(barrierMask[sy * w + sx]) return null;

  const visited = new Uint8Array(w * h);
  const stack = [sy * w + sx];
  visited[sy * w + sx] = 1;
  while(stack.length){
    const idx = stack.pop();
    const x = idx % w, y = (idx / w) | 0;
    const candidates = [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]];
    for(const [nx, ny] of candidates){
      if(nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
      const nIdx = ny * w + nx;
      if(visited[nIdx] || barrierMask[nIdx]) continue;
      visited[nIdx] = 1;
      stack.push(nIdx);
    }
  }
  return visited;
}

function maskToCanvas(mask){
  const c = document.createElement('canvas');
  c.width = RASTER_SIZE; c.height = RASTER_SIZE;
  const ctx = c.getContext('2d');
  const imgData = ctx.createImageData(RASTER_SIZE, RASTER_SIZE);
  for(let i = 0; i < mask.length; i++){
    if(mask[i]) imgData.data[i * 4 + 3] = 255; // opaque alpha marks "inside the region"
  }
  ctx.putImageData(imgData, 0, 0);
  return c;
}

function hexToRgbArr(hex){
  return [parseInt(hex.slice(1, 3), 16), parseInt(hex.slice(3, 5), 16), parseInt(hex.slice(5, 7), 16)];
}

function rgbToHex(r, g, b){
  const toHex = n => n.toString(16).padStart(2, '0');
  return `#${toHex(r)}${toHex(g)}${toHex(b)}`.toUpperCase();
}

// Composites fillCanvas + brushCanvas + the immutable line art SVG into one
// flat image (for the Completion preview) — reuses the same SVG-to-canvas
// rasterization technique as buildBarrierMask(), just at full visual fidelity
// instead of as a barrier bitmap. Async; calls back with a PNG data URL.
function renderArtboardToDataURL(callback){
  const composite = document.createElement('canvas');
  composite.width = RASTER_SIZE; composite.height = RASTER_SIZE;
  const ctx = composite.getContext('2d');
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, RASTER_SIZE, RASTER_SIZE);

  const fillCanvas = document.getElementById('fillCanvas');
  const brushCanvasEl = document.getElementById('brushCanvas');
  if(fillCanvas) ctx.drawImage(fillCanvas, 0, 0);
  if(brushCanvasEl) ctx.drawImage(brushCanvasEl, 0, 0);

  const svg = document.getElementById('artboardSvg');
  if(!svg){ callback(composite.toDataURL('image/png')); return; }
  const svgStr = new XMLSerializer().serializeToString(svg);
  const blob = new Blob([svgStr], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const img = new Image();
  img.onload = () => {
    ctx.drawImage(img, 0, 0, RASTER_SIZE, RASTER_SIZE);
    URL.revokeObjectURL(url);
    callback(composite.toDataURL('image/png'));
  };
  img.onerror = () => callback(composite.toDataURL('image/png')); // still show fill/brush even if the line-art layer fails to rasterize
  img.src = url;
}

// ---------------------------------------------------------------------------
// FILL — flood fill using the exact same region-mask engine as Locked Brush.
// Renders onto #fillCanvas (the bottom-most visual layer — see index.html),
// never touching the immutable line art SVG or #brushCanvas above it.
// ---------------------------------------------------------------------------
function performFillAt(px, py){
  if(!barrierMaskReady) return;
  const mask = floodFillMaskFrom(px, py);
  if(!mask) return; // tapped directly on a barrier line — nothing to fill

  const canvas = document.getElementById('fillCanvas');
  const ctx = canvas.getContext('2d');
  const before = ctx.getImageData(0, 0, RASTER_SIZE, RASTER_SIZE);
  const after = ctx.createImageData(RASTER_SIZE, RASTER_SIZE);
  after.data.set(before.data);
  const [r, g, b] = hexToRgbArr(activeColor);
  for(let i = 0; i < mask.length; i++){
    if(mask[i]){
      after.data[i * 4] = r; after.data[i * 4 + 1] = g; after.data[i * 4 + 2] = b; after.data[i * 4 + 3] = 255;
    }
  }
  ctx.putImageData(after, 0, 0);
  pushHistory({ type: 'fill', before, after });
  progressUpdatedAt[currentArtworkId] = Date.now();
  markSaving();
}

// ---------------------------------------------------------------------------
// BRUSH / ERASE — strokes are plain JS objects (not DOM nodes), redrawn onto
// #brushCanvas from strokesList. A locked stroke carries a maskCanvas (built
// once at pointerdown from the SAME floodFillMaskFrom() used by Fill) that
// clips it via 'destination-in' compositing; an unlocked or erase stroke
// carries none and draws freely. Undo/redo just remove/re-append the stroke
// object and redraw — no DOM diffing needed.
// ---------------------------------------------------------------------------
let strokesList = [];

function canvasPointFromEvent(canvas, evt){
  const rect = canvas.getBoundingClientRect();
  return {
    x: (evt.clientX - rect.left) / rect.width * canvas.width,
    y: (evt.clientY - rect.top) / rect.height * canvas.height
  };
}

function brushStrokeWidth(){
  const val = Number(slider ? slider.value : 18);
  return 2 + (val / 100) * 22; // 0–100 slider mapped to a visibly distinct 2–24 raster-px range
}

function strokePath(ctx, stroke){
  if(stroke.points.length === 0) return;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.lineWidth = stroke.width;
  ctx.strokeStyle = stroke.color;
  ctx.beginPath();
  stroke.points.forEach((p, i) => { if(i === 0) ctx.moveTo(p.x, p.y); else ctx.lineTo(p.x, p.y); });
  if(stroke.points.length === 1){
    // A tap with no drag — draw a dot so a single click is still visible.
    ctx.lineTo(stroke.points[0].x + 0.01, stroke.points[0].y);
  }
  ctx.stroke();
}

function drawStroke(ctx, stroke){
  if(!stroke.maskCanvas){
    strokePath(ctx, stroke);
    return;
  }
  const temp = document.createElement('canvas');
  temp.width = RASTER_SIZE; temp.height = RASTER_SIZE;
  const tctx = temp.getContext('2d');
  strokePath(tctx, stroke);
  tctx.globalCompositeOperation = 'destination-in';
  tctx.drawImage(stroke.maskCanvas, 0, 0);
  ctx.drawImage(temp, 0, 0);
}

function redrawBrushCanvas(){
  const canvas = document.getElementById('brushCanvas');
  if(!canvas) return;
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, RASTER_SIZE, RASTER_SIZE);
  strokesList.forEach(stroke => drawStroke(ctx, stroke));
}

// --- Eyedropper ------------------------------------------------------------
// One-shot drag-to-sample: arm on button tap, begin sampling on the next
// artboard pointerdown, continuously re-sample + move the magnifier on every
// pointermove while the pointer is down, commit on pointerup, cancel (revert)
// on pointercancel. The previous tool is remembered and always restored.
let eyedropperArmed = false;
let eyedropperDragging = false;
let eyedropperLastColor = null;
let toolBeforeEyedropper = null;

function armEyedropper(){
  if(eyedropperArmed){ // tapping again while armed disarms it
    eyedropperArmed = false;
    document.querySelectorAll('[aria-label="Eyedropper"]').forEach(b => b.classList.remove('armed'));
    return;
  }
  toolBeforeEyedropper = activeTool;
  eyedropperArmed = true;
  document.querySelectorAll('[aria-label="Eyedropper"]').forEach(b => b.classList.add('armed'));
}

// Layered sampling, topmost-visible-layer-wins — matches the actual visual
// stack (line art above Brush above Fill above background white).
function sampleColorAt(px, py){
  const x = Math.max(0, Math.min(RASTER_SIZE - 1, Math.round(px)));
  const y = Math.max(0, Math.min(RASTER_SIZE - 1, Math.round(py)));
  if(barrierMaskReady && barrierMask && barrierMask[y * RASTER_SIZE + x]) return '#111111';
  const brushPixel = document.getElementById('brushCanvas').getContext('2d').getImageData(x, y, 1, 1).data;
  if(brushPixel[3] > 0) return rgbToHex(brushPixel[0], brushPixel[1], brushPixel[2]);
  const fillPixel = document.getElementById('fillCanvas').getContext('2d').getImageData(x, y, 1, 1).data;
  if(fillPixel[3] > 0) return rgbToHex(fillPixel[0], fillPixel[1], fillPixel[2]);
  return '#FFFFFF';
}

function showEyedropperMagnifier(clientX, clientY, color){
  const el = document.querySelector('[data-testid="eyedropper-magnifier"]');
  if(!el) return;
  el.hidden = false;
  el.style.left = `${clientX}px`;
  el.style.top = `${clientY}px`;
  el.style.background = color;
}

function hideEyedropperMagnifier(){
  const el = document.querySelector('[data-testid="eyedropper-magnifier"]');
  if(el) el.hidden = true;
}

function updateEyedropperSample(e){
  const canvas = document.getElementById('brushCanvas');
  const p = canvasPointFromEvent(canvas, e);
  eyedropperLastColor = sampleColorAt(p.x, p.y);
  showEyedropperMagnifier(e.clientX, e.clientY, eyedropperLastColor);
}

function restoreToolAfterEyedropper(){
  const btn = document.querySelector(`[data-testid="tool-${toolBeforeEyedropper}"]`);
  if(btn) selectTool(btn, toolBeforeEyedropper);
  document.querySelectorAll('[aria-label="Eyedropper"]').forEach(b => b.classList.remove('armed'));
}

function finishEyedropperSample(){
  eyedropperDragging = false;
  hideEyedropperMagnifier();
  if(eyedropperLastColor) setCustomPaletteColor(eyedropperLastColor);
  restoreToolAfterEyedropper();
}

function cancelEyedropperSample(){
  eyedropperDragging = false;
  eyedropperArmed = false;
  hideEyedropperMagnifier();
  restoreToolAfterEyedropper();
  // activeColor / custom slot intentionally untouched — see "Eyedropper Cancel".
}

// --- Shared pointer handlers (Eyedropper / Fill / Brush / Erase) ----------
// Attached to #brushCanvas — the topmost element that actually captures
// pointer events (#artboardSvg above it is pointer-events:none, purely
// visual — see styles.css), so this is scoped to the artwork only: taps on
// the toolbar/palette/tool rail never reach here.
function onArtboardPointerDown(e){
  const canvas = document.getElementById('brushCanvas');
  if(!canvas) return;
  const p = canvasPointFromEvent(canvas, e);

  if(eyedropperArmed){
    eyedropperArmed = false;
    eyedropperDragging = true;
    updateEyedropperSample(e);
    if(canvas.setPointerCapture && e.pointerId != null){
      try { canvas.setPointerCapture(e.pointerId); } catch(err) { /* not critical for the prototype */ }
    }
    e.preventDefault();
    return;
  }

  if(activeTool === 'fill'){
    performFillAt(p.x, p.y);
    e.preventDefault();
    return;
  }

  if(activeTool !== 'brush' && activeTool !== 'erase') return;

  // LOCKED Brush: detect the connected region at THIS stroke's start point
  // using the same engine as Fill, and bake a one-off mask into just this
  // stroke. Erase is never affected by Lock (Lock only changes Brush).
  let maskCanvas = null;
  if(activeTool === 'brush' && coloringLocked){
    const mask = floodFillMaskFrom(p.x, p.y);
    if(!mask) return; // no closed region at the start point — nothing to constrain to
    maskCanvas = maskToCanvas(mask);
  }

  activeStroke = {
    points: [p],
    color: activeTool === 'erase' ? '#FFFFFF' : activeColor,
    width: brushStrokeWidth(),
    maskCanvas
  };
  strokesList.push(activeStroke);
  redrawBrushCanvas();

  if(canvas.setPointerCapture && e.pointerId != null){
    try { canvas.setPointerCapture(e.pointerId); } catch(err) { /* not critical for the prototype */ }
  }
  e.preventDefault();
}

function onArtboardPointerMove(e){
  if(eyedropperDragging){
    updateEyedropperSample(e);
    return;
  }
  if(!activeStroke) return;
  const canvas = document.getElementById('brushCanvas');
  const p = canvasPointFromEvent(canvas, e);
  activeStroke.points.push(p);
  redrawBrushCanvas();
  e.preventDefault();
}

function onArtboardPointerUp(){
  if(eyedropperDragging){
    finishEyedropperSample();
    return;
  }
  if(!activeStroke) return;
  const finished = activeStroke;
  activeStroke = null;
  // The stroke is already in strokesList (pushed at pointerdown so live
  // dragging renders); pushHistory only needs to record it for undo/redo.
  pushHistory({ type: 'stroke', stroke: finished });
  progressUpdatedAt[currentArtworkId] = Date.now();
  markSaving();
}

function onArtboardPointerCancel(){
  if(eyedropperDragging){
    cancelEyedropperSample();
    return;
  }
  if(!activeStroke) return;
  // Cancelled mid-stroke: drop it entirely rather than leaving a partial,
  // un-recorded stroke that Undo could never reach.
  const idx = strokesList.indexOf(activeStroke);
  if(idx !== -1) strokesList.splice(idx, 1);
  activeStroke = null;
  redrawBrushCanvas();
}

// #artboard.zoomed is now the single source of truth for Focus/Expanded
// mode — styles.css keys all of the tool-rail/slider/palette hide + compact
// controls + larger artwork off it via :has(), so entering/exiting never
// touches artwork, activeTool, activeColor, Lock/Unlock, or Undo/Redo state.
function toggleZoom(){
  zoomed = !zoomed;
  const artboard = document.getElementById('artboard');
  artboard.classList.toggle('zoomed', zoomed);
  artboard.dataset.state = zoomed ? 'zoomed' : 'default';
  const fitBtn = document.querySelector('[data-testid="editor-fit"]');
  if(fitBtn) fitBtn.setAttribute('aria-pressed', String(zoomed));
  syncFocusIndicators();
}

// --- Color Picker (bottom sheet over SCR-EDITOR-001) ---------------------
// draft/original color pair per the approved state model: dragging the hue
// ring only ever updates draftColor + the live preview; activeColor itself
// is untouched until Save explicitly commits it. Back discards the draft.
let originalColor = null;
let draftColor = null;
let colorPickerDragging = false;

function openColorPicker(){
  originalColor = activeColor;
  draftColor = activeColor;
  updateColorPickerPreview(draftColor);
  positionHueHandle(hexToHue(draftColor));
  const overlay = document.querySelector('[data-testid="color-picker-overlay"]');
  if(overlay) overlay.hidden = false;
}

function closeColorPicker(save){
  // Save: setCustomPaletteColor() replaces + focuses the right-most custom
  // slot — the same shared rule Eyedropper release uses (req. 1/7/9). Back:
  // activeColor and the palette's focus state were never touched while the
  // sheet was open (dragging the hue ring only ever wrote draftColor), so
  // whatever was focused before Save/opening is still exactly what's
  // showing — the custom slot is never replaced on Back (req. 2/8).
  if(save && draftColor){
    setCustomPaletteColor(draftColor);
  }
  originalColor = null;
  draftColor = null;
  const overlay = document.querySelector('[data-testid="color-picker-overlay"]');
  if(overlay) overlay.hidden = true;
}

function updateColorPickerPreview(hex){
  const preview = document.getElementById('colorPreview');
  if(preview) preview.style.background = hex;
}

function hexToHue(hex){
  const r = parseInt(hex.slice(1,3),16) / 255;
  const g = parseInt(hex.slice(3,5),16) / 255;
  const b = parseInt(hex.slice(5,7),16) / 255;
  const max = Math.max(r,g,b), min = Math.min(r,g,b);
  if(max === min) return 0;
  const d = max - min;
  let h;
  if(max === r) h = ((g - b) / d) % 6;
  else if(max === g) h = (b - r) / d + 2;
  else h = (r - g) / d + 4;
  h *= 60;
  return h < 0 ? h + 360 : h;
}

function hslToHex(h, s, l){
  s /= 100; l /= 100;
  const k = n => (n + h / 30) % 12;
  const a = s * Math.min(l, 1 - l);
  const f = n => l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
  const toHex = x => Math.round(255 * x).toString(16).padStart(2, '0');
  return `#${toHex(f(0))}${toHex(f(8))}${toHex(f(4))}`.toUpperCase();
}

// Angle convention matches CSS conic-gradient(from 0deg, ...): 0deg = up
// (12 o'clock), increasing clockwise — so hue and handle position/gradient
// stay visually aligned.
function positionHueHandle(hue){
  const wrap = document.getElementById('hueRingWrap');
  const handle = document.getElementById('hueHandle');
  if(!wrap || !handle) return;
  const size = wrap.getBoundingClientRect().width || wrap.offsetWidth || 220;
  const cx = size / 2, cy = size / 2;
  const midRadius = (size / 2) * 0.83;
  const rad = hue * Math.PI / 180;
  handle.style.left = `${cx + midRadius * Math.sin(rad)}px`;
  handle.style.top = `${cy - midRadius * Math.cos(rad)}px`;
}

function hueFromPointer(evt, wrap){
  const rect = wrap.getBoundingClientRect();
  const cx = rect.left + rect.width / 2, cy = rect.top + rect.height / 2;
  const dx = evt.clientX - cx, dy = evt.clientY - cy;
  let deg = Math.atan2(dx, -dy) * 180 / Math.PI;
  return deg < 0 ? deg + 360 : deg;
}

function updateDraftFromPointer(e){
  const wrap = document.getElementById('hueRingWrap');
  if(!wrap) return;
  const hue = hueFromPointer(e, wrap);
  draftColor = hslToHex(hue, 88, 55);
  updateColorPickerPreview(draftColor);
  positionHueHandle(hue);
}

function onHueRingPointerDown(e){
  colorPickerDragging = true;
  const wrap = document.getElementById('hueRingWrap');
  updateDraftFromPointer(e);
  if(wrap && wrap.setPointerCapture && e.pointerId != null){
    try { wrap.setPointerCapture(e.pointerId); } catch(err) { /* not critical for the prototype */ }
  }
  e.preventDefault();
}

function onHueRingPointerMove(e){
  if(!colorPickerDragging) return;
  updateDraftFromPointer(e);
}

function onHueRingPointerUp(){
  colorPickerDragging = false;
}

const slider = document.getElementById('brushSlider');
if(slider){
  const updateSliderFill = () => {
    slider.style.setProperty('--p', `${slider.value}%`);
  };
  updateSliderFill();
  slider.addEventListener('input', updateSliderFill);
}

const brushCanvasEl = document.getElementById('brushCanvas');
if(brushCanvasEl){
  brushCanvasEl.addEventListener('pointerdown', onArtboardPointerDown);
  brushCanvasEl.addEventListener('pointermove', onArtboardPointerMove);
  brushCanvasEl.addEventListener('pointerup', onArtboardPointerUp);
  brushCanvasEl.addEventListener('pointercancel', onArtboardPointerCancel);
}
buildBarrierMask(); // async — see barrierMaskReady; only one real artwork in this prototype, so once is enough

const hueRingWrap = document.getElementById('hueRingWrap');
if(hueRingWrap){
  hueRingWrap.addEventListener('pointerdown', onHueRingPointerDown);
  hueRingWrap.addEventListener('pointermove', onHueRingPointerMove);
  hueRingWrap.addEventListener('pointerup', onHueRingPointerUp);
  hueRingWrap.addEventListener('pointercancel', onHueRingPointerUp);
}

syncFocusIndicators(); // match the seeded default activeTool/activeColor

// Home is the initially-active screen in static markup — showScreen() is
// never called for that first render, so the Continue card needs one
// explicit initial render to match the seeded progressStore state.
renderHomeContinue();
