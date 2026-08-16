let activeColor = '#168B2D';
let activeTool = 'brush';
let zoomed = false;
// No lesson is open until the user actually taps one — Home is the initial
// screen, so there is no meaningful "default" artwork anymore now that
// content is real, per-lesson data instead of one hardcoded drawing.
let currentArtworkId = null;
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

// Seeded with real lesson IDs from the approved 25-lesson dataset (see
// data/lessons.json) so Profile/Home-Continue have real demo content from
// first load — the same "one in progress, one completed" pattern as before,
// just pointed at real content instead of the old placeholder IDs.
const progressStore = {
  animal_babydeer: 'IN_PROGRESS',
  nature_mountainlake: 'COMPLETED'
};

// Recency signal only, for the Continue card's "most recently updated wins"
// rule (data-model.md already documents Progress.updatedAt — this is that
// field for the prototype's flat progressStore, not a second status store).
const progressUpdatedAt = {
  animal_babydeer: Date.now()
};

// --- Real lesson content (data/lessons.json + data/categories.json) -------
// The single source of truth for lesson data — Home/Library/Search/Profile/
// Completion all read from `lessons`/`LESSONS_BY_ID`, never a second
// hardcoded copy. Populated asynchronously by loadContent() at the bottom of
// this file; empty until then (the fetch is same-origin/local and resolves
// well before a user could interact with Home/Library in practice).
let lessons = [];
let categories = [];
let LESSONS_BY_ID = {};

async function loadContent(){
  try {
    const [lessonsRes, categoriesRes] = await Promise.all([
      fetch('data/lessons.json'),
      fetch('data/categories.json')
    ]);
    lessons = await lessonsRes.json();
    categories = await categoriesRes.json();
  } catch(err) {
    lessons = [];
    categories = [];
  }
  LESSONS_BY_ID = {};
  lessons.forEach(l => { LESSONS_BY_ID[l.id] = l; });

  renderHomeCategorySections();
  renderLibraryGrid();
  // Home is the initially-active screen in static markup — showScreen() is
  // never called for that first render, so the Continue card needs one
  // explicit render once real lesson data (and the seeded progress above)
  // is actually available to look up titles/thumbnails from.
  renderHomeContinue();
}

// One shared thumbnail builder — Home, Library, Search, Profile, and
// Completion's "Recommended for you" all render the identical 250×250
// lesson.thumbnail the same one way, never a second thumbnail code path.
function createLessonThumb(lesson){
  const thumb = document.createElement('div');
  thumb.className = 'thumb';
  const img = document.createElement('img');
  img.src = lessonPreviewSrc(lesson);
  img.alt = '';
  thumb.appendChild(img);
  return thumb;
}

function renderHomeCategorySections(){
  // Home shows only these three sections (approved structure, unchanged) —
  // Dumpling is intentionally NOT added here; it's discoverable via
  // Library/Search only, per this pass's explicit scope.
  ['manga', 'animal', 'nature'].forEach(categoryId => {
    const row = document.querySelector(`[data-testid="home-${categoryId}-row"]`);
    if(!row) return;
    row.innerHTML = '';
    lessons
      .filter(l => l.categoryId === categoryId)
      .sort((a, b) => a.sortOrder - b.sortOrder)
      .forEach(lesson => {
        const btn = document.createElement('button');
        btn.className = 'art-card';
        btn.dataset.category = lesson.categoryId;
        btn.dataset.testid = `drawing-card-${lesson.id}`;
        btn.setAttribute('aria-label', lesson.title);
        btn.onclick = () => openArtwork(lesson.id);
        btn.appendChild(createLessonThumb(lesson));
        row.appendChild(btn);
      });
  });
}

function renderLibraryGrid(){
  const grid = document.querySelector('[data-testid="library-grid"]');
  if(!grid) return;
  grid.innerHTML = '';
  lessons.forEach(lesson => {
    const btn = document.createElement('button');
    btn.className = 'drawing-card';
    btn.dataset.componentId = 'CMP-LIBRARY-DRAWING-CARD';
    btn.dataset.category = lesson.categoryId;
    btn.dataset.testid = `drawing-card-${lesson.id}`;
    btn.onclick = () => openArtwork(lesson.id);
    const title = document.createElement('b');
    title.textContent = lesson.title;
    btn.append(createLessonThumb(lesson), title);
    grid.appendChild(btn);
  });
}

function showScreen(id){
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  const target = document.querySelector(`[data-screen-id="${id}"]`);
  if(target) target.classList.add('active');
  // Re-render every time one of these becomes active (not just cold start),
  // covering EVERY path that reaches them (bottom nav, Home "See all", the
  // Editor Back button, Search's Explore-library/Back, etc. all funnel
  // through this one function) so dynamic progress-thumbnails/newly-started
  // lessons are never stale — never just the direct-tap entry points.
  if(id === 'SCR-HOME-001'){
    renderHomeCategorySections();
    renderHomeContinue();
  } else if(id === 'SCR-LIBRARY-001'){
    const grid = document.querySelector('[data-screen-id="SCR-LIBRARY-001"] [data-testid="library-grid"]');
    const activeFilter = (grid && grid.dataset.activeFilter) || 'all';
    renderLibraryGrid();
    const btn = document.querySelector(`[data-screen-id="SCR-LIBRARY-001"] [data-testid="library-filter-${activeFilter}"]`);
    filterLibrary(activeFilter, btn);
  } else if(id === 'SCR-PROFILE-001'){
    renderProfile();
  }
}

function openArtwork(lessonId){
  const activeScreen = document.querySelector('.screen.active');
  if(activeScreen) editorOrigin = activeScreen.dataset.screenId;

  // Persist whatever is currently on-canvas under the PREVIOUS lesson's ID
  // before switching — otherwise opening a different lesson would silently
  // carry over (or discard) the wrong drawing state.
  saveCurrentLessonState();

  currentArtworkId = lessonId;
  if(!progressStore[lessonId]){
    progressStore[lessonId] = 'IN_PROGRESS';
  }
  progressUpdatedAt[lessonId] = Date.now();

  undoStack = [];
  redoStack = [];
  activeStroke = null;
  updateHistoryButtons();

  showScreen('SCR-EDITOR-001');
  loadLessonArtwork(lessonId); // async — rebuilds the region-mask/line-art for THIS lesson, then restores its saved drawing (if any)
}

function exitEditor(){
  // Autosave is already continuous (Fill/Brush/undo/redo flip the Saving/
  // Saved indicator immediately); this just returns to wherever the user
  // actually came from — never a hardcoded Preview/Category hop.
  updateLessonPreview(currentArtworkId); // belt-and-suspenders freshness on the way out
  showScreen(editorOrigin);
}

function completeArtwork(){
  progressStore[currentArtworkId] = 'COMPLETED';
  progressUpdatedAt[currentArtworkId] = Date.now();
  updateLessonPreview(currentArtworkId);
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

  const lesson = LESSONS_BY_ID[id];
  if(!lesson){ card.hidden = true; return; } // defensive: id not (yet) in loaded content
  card.hidden = false;
  card.dataset.artworkId = id;

  const title = card.querySelector('.continue-title');
  if(title) title.textContent = lesson.title;

  const art = card.querySelector('.continue-art');
  if(art){
    art.innerHTML = '';
    art.className = 'continue-art';
    const img = document.createElement('img');
    img.src = lessonPreviewSrc(lesson);
    art.appendChild(img);
  }
}

function continueCurrentArtwork(){
  const id = getContinueArtworkId();
  if(!id) return; // card should be hidden already if this is null
  openArtwork(id);
}

function renderCompletion(){
  const scope = document.querySelector('[data-screen-id="SCR-COMPLETE-001"]');
  if(!scope) return;

  const shareStatus = scope.querySelector('[data-testid="completion-share-status"]');
  const saveStatus = scope.querySelector('[data-testid="completion-save-status"]');
  if(shareStatus) shareStatus.hidden = true;
  if(saveStatus) saveStatus.hidden = true;

  const lesson = LESSONS_BY_ID[currentArtworkId];
  const card = scope.querySelector('[data-testid="completion-artwork"]');
  if(card){
    card.className = 'completion-artwork-card';
    card.innerHTML = '';
    // Composite the live Fill/Brush/line-art canvases into a static image
    // rather than the flat thumbnail — "the most faithful available way"
    // the prototype can show the just-completed, actually-colored lesson.
    const img = document.createElement('img');
    img.alt = lesson ? lesson.title : '';
    card.appendChild(img);
    renderArtboardToDataURL(dataUrl => { img.src = dataUrl; });
  }

  const grid = scope.querySelector('[data-testid="completion-recommended"]');
  if(grid){
    grid.innerHTML = '';
    // Recommendations come from the same real 25-lesson dataset, excluding
    // whatever was just completed — no separate/second recommendation pool.
    lessons
      .filter(l => l.id !== currentArtworkId)
      .slice(0, 4)
      .forEach(l => {
        const btn = document.createElement('button');
        btn.className = 'drawing-card';
        btn.dataset.testid = `drawing-card-${l.id}`;
        btn.onclick = () => openArtwork(l.id);

        const title = document.createElement('b');
        title.textContent = l.title;

        btn.append(createLessonThumb(l), title);
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

  // Matches against the same real lesson titles used by Library/Home/Profile
  // — no separate search index/database (REQ-LIB-009).
  const q = trimmed.toLowerCase();
  const matches = lessons.filter(l => l.title.toLowerCase().includes(q));

  if(matches.length === 0){
    if(grid){ grid.hidden = true; grid.innerHTML = ''; }
    if(emptyState) emptyState.hidden = false;
    return;
  }

  if(emptyState) emptyState.hidden = true;
  if(grid){
    grid.hidden = false;
    grid.innerHTML = '';
    matches.forEach(lesson => {
      const btn = document.createElement('button');
      btn.className = 'drawing-card';
      btn.dataset.testid = `drawing-card-${lesson.id}`;
      // Same shared resolver as Home/Library/Profile — no duplicate opening system.
      btn.onclick = () => openArtwork(lesson.id);

      const title = document.createElement('b');
      title.textContent = lesson.title;

      btn.append(createLessonThumb(lesson), title);
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
    const lesson = LESSONS_BY_ID[drawingId] || { title: drawingId, thumbnail: '' };

    const card = document.createElement('button');
    card.className = 'drawing-card';
    card.dataset.testid = `drawing-card-${drawingId}`;
    card.dataset.status = status === 'IN_PROGRESS' ? 'in_progress' : 'completed';
    // Profile is the ONE place an artwork tap does NOT go straight to the
    // Editor — it opens the Artwork Detail Popup instead (Restart/Color).
    // Home/Library/Search/Completion are unchanged (still openArtwork()
    // directly) — this popup is Profile-only, per this pass's explicit scope.
    card.onclick = () => openProfilePopup(drawingId);

    const title = document.createElement('b');
    title.textContent = lesson.title;

    const statusLabel = document.createElement('span');
    statusLabel.textContent = status === 'IN_PROGRESS' ? 'In Progress' : 'Completed';

    card.append(createLessonThumb(lesson), title, statusLabel);
    grid.appendChild(card);
  });

  if(segmentEmpty) segmentEmpty.hidden = visibleCount > 0;
}

// --- Profile Artwork Detail Popup (Profile-only; see openProfilePopup) ----
// A modal OVER SCR-PROFILE-001, not a new Screen ID. Home/Library/Search/
// Completion artwork taps are unchanged — direct to Editor.
let profilePopupLessonId = null;

function openProfilePopup(lessonId){
  profilePopupLessonId = lessonId;
  const overlay = document.querySelector('[data-testid="profile-artwork-popup"]');
  if(!overlay) return;
  const lesson = LESSONS_BY_ID[lessonId];
  const img = overlay.querySelector('[data-testid="profile-popup-artwork"]');
  if(img) img.src = lessonPreviewSrc(lesson);
  const title = overlay.querySelector('[data-testid="profile-popup-title"]');
  if(title) title.textContent = lesson ? lesson.title : '';
  overlay.hidden = false;
}

function closeProfilePopup(){
  profilePopupLessonId = null;
  const overlay = document.querySelector('[data-testid="profile-artwork-popup"]');
  if(overlay) overlay.hidden = true;
}

// Color: close popup, open Editor, resume the lesson's EXISTING saved
// progress — openArtwork()/loadLessonArtwork() already do this by default,
// so no separate "resume" path is needed here.
function profilePopupColor(){
  const id = profilePopupLessonId;
  closeProfilePopup();
  if(id) openArtwork(id);
}

// Restart: wipe THIS lesson's saved coloring state only, then open a clean
// Editor session for it. Other lessons' lessonDrawingState/progressStore
// entries are untouched.
function profilePopupRestart(){
  const id = profilePopupLessonId;
  closeProfilePopup();
  if(!id) return;
  restartLesson(id);
  openArtwork(id);
}

function restartLesson(lessonId){
  delete lessonDrawingState[lessonId]; // no saved fill/strokes -> loadLessonArtwork() renders a clean lesson
  delete lessonPreviewCache[lessonId]; // no dynamic preview -> falls back to the original static thumbnail
  // Removing the progressStore/progressUpdatedAt entries entirely (rather
  // than setting some new status) means openArtwork()'s existing
  // `if(!progressStore[lessonId])` seed logic naturally creates a fresh
  // IN_PROGRESS record when Editor opens next — this is how a restarted
  // COMPLETED lesson stops being COMPLETED, with no new status value needed.
  delete progressStore[lessonId];
  delete progressUpdatedAt[lessonId];
  if(currentArtworkId === lessonId){
    // Lesson happens to already be the open one — clear the live canvases
    // immediately too, since loadLessonArtwork() won't be reloaded from
    // scratch by openArtwork() until its own async rasterize step finishes.
    undoStack = []; redoStack = []; strokesList = [];
    updateHistoryButtons();
    const fillCanvas = document.getElementById('fillCanvas');
    if(fillCanvas) fillCanvas.getContext('2d').clearRect(0, 0, ARTWORK_SIZE, ARTWORK_SIZE);
    redrawBrushCanvas();
  }
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
  // The palette row scrolls horizontally and the custom slot sits at the far
  // right — without this, Playful Save/Eyedropper correctly update the DOM
  // (selected class, --c, data-color) but the swatch can land scrolled out
  // of view, so the user visually sees no change at all. One shared call
  // site (every color-commit path routes through here) keeps whichever
  // swatch is actually active visible, not just technically "selected".
  if(btn && btn.scrollIntoView){
    btn.scrollIntoView({ behavior: 'smooth', inline: 'nearest', block: 'nearest' });
  }
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
  saveCurrentLessonState();
  // One shared hook point for every commit (stroke pointerup, Fill, Undo,
  // Redo — everywhere markSaving() is already called) keeps the dynamic
  // progress-thumbnail cache fresh without scattering update calls across
  // every tool — see updateLessonPreview()/PREVIEW-SIZE above.
  updateLessonPreview(currentArtworkId);
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
// Each lesson's artwork PNG is rasterized once, per lesson, off the visible
// DOM (the source PNG file itself is never modified) into a barrier bitmap:
// sufficiently dark/opaque pixels are BARRIERS, one pixel of dilation is
// added so anti-aliased line edges don't
// leak between regions, and the raster's own edges are implicit barriers
// (the artwork rectangle boundary). floodFillMaskFrom() then does a 4-
// directional flood fill from a start point across non-barrier pixels,
// returning a same-size boolean mask of the connected region — which is
// exactly as valid for the white background surrounding the subject as it
// is for any internal enclosed area, since both are just "non-barrier
// pixels reachable from the start point" to this engine.
// ===========================================================================

const ARTWORK_SIZE = 800; // matches every lesson artwork's real pixel dimensions (see data/lessons.json)
let barrierMask = null; // Uint8Array, ARTWORK_SIZE*ARTWORK_SIZE, 1 = barrier
let barrierMaskReady = false;
const artworkImageCache = {}; // lessonId -> loaded Image, avoids re-fetching the PNG on reopen

// Per-lesson drawing state, isolated by lesson.id — switching lessons must
// never carry over (or discard) the wrong artwork's pixels. Saved
// continuously via saveCurrentLessonState() (called from markSaving(), and
// once more explicitly in openArtwork() right before switching lessons) and
// restored by restoreLessonDrawingState() once the new lesson's barrier
// mask/line-art is ready.
let lessonDrawingState = {}; // lessonId -> { fillImageData, strokes }

function saveCurrentLessonState(){
  if(!currentArtworkId) return;
  const fillCanvas = document.getElementById('fillCanvas');
  if(!fillCanvas) return;
  const fillImageData = fillCanvas.getContext('2d').getImageData(0, 0, ARTWORK_SIZE, ARTWORK_SIZE);
  lessonDrawingState[currentArtworkId] = { fillImageData, strokes: strokesList.slice() };
}

function restoreLessonDrawingState(lessonId){
  const fillCanvas = document.getElementById('fillCanvas');
  if(!fillCanvas) return;
  const saved = lessonDrawingState[lessonId];
  const fillCtx = fillCanvas.getContext('2d');
  fillCtx.clearRect(0, 0, ARTWORK_SIZE, ARTWORK_SIZE);
  if(saved){
    fillCtx.putImageData(saved.fillImageData, 0, 0);
    strokesList = saved.strokes.slice();
  } else {
    strokesList = [];
  }
  redrawBrushCanvas();
}

// Loads the given lesson's 800×800 artwork PNG and rasterizes it, once, into
// BOTH the flood-fill barrier mask AND the visible line-art overlay — a
// simpler single-pass version of the prior SVG-serialization approach, since
// the artwork is already a raster image (no Blob-URL/XML-serialize step
// needed). Dark pixels become opaque black in the overlay (so it stays
// crisp/undilated for display) while a separately DILATED clone of the same
// darkness test becomes the barrier mask (so region-detection stays tolerant
// of anti-aliased edges without visually thickening the displayed ink).
function loadLessonArtwork(lessonId){
  barrierMaskReady = false;
  barrierMask = null;
  resetEditorView(); // fresh 1x/centered view for every (re)opened lesson

  const lineArtCanvas = document.getElementById('lineArtCanvas');
  const fillCanvas = document.getElementById('fillCanvas');
  const brushCanvas = document.getElementById('brushCanvas');
  if(lineArtCanvas) lineArtCanvas.getContext('2d').clearRect(0, 0, ARTWORK_SIZE, ARTWORK_SIZE);
  if(fillCanvas) fillCanvas.getContext('2d').clearRect(0, 0, ARTWORK_SIZE, ARTWORK_SIZE);
  if(brushCanvas) brushCanvas.getContext('2d').clearRect(0, 0, ARTWORK_SIZE, ARTWORK_SIZE);
  strokesList = [];

  const lesson = LESSONS_BY_ID[lessonId];
  if(!lesson || !lineArtCanvas) return;

  const rasterize = (img) => {
    const off = document.createElement('canvas');
    off.width = ARTWORK_SIZE; off.height = ARTWORK_SIZE;
    const octx = off.getContext('2d', { willReadFrequently: true });
    octx.drawImage(img, 0, 0, ARTWORK_SIZE, ARTWORK_SIZE);
    const data = octx.getImageData(0, 0, ARTWORK_SIZE, ARTWORK_SIZE).data;

    const mask = new Uint8Array(ARTWORK_SIZE * ARTWORK_SIZE);
    const overlay = lineArtCanvas.getContext('2d').createImageData(ARTWORK_SIZE, ARTWORK_SIZE);
    for(let i = 0; i < ARTWORK_SIZE * ARTWORK_SIZE; i++){
      const a = data[i * 4 + 3];
      const darkness = 255 - (data[i * 4] + data[i * 4 + 1] + data[i * 4 + 2]) / 3;
      const isDark = a > 40 && darkness > 90; // threshold tolerant of anti-aliased edges
      if(isDark){
        mask[i] = 1;
        overlay.data[i * 4 + 3] = 255; // opaque black ink; RGB already zeroed by createImageData
      }
    }
    lineArtCanvas.getContext('2d').putImageData(overlay, 0, 0);

    dilateBarrierMask(mask, ARTWORK_SIZE, ARTWORK_SIZE, 1);
    barrierMask = mask;
    barrierMaskReady = true;

    restoreLessonDrawingState(lessonId);
  };

  const cached = artworkImageCache[lessonId];
  if(cached && cached.complete){
    rasterize(cached);
    return;
  }

  const img = new Image();
  img.onload = () => { artworkImageCache[lessonId] = img; rasterize(img); };
  img.src = lesson.artwork;
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
  const w = ARTWORK_SIZE, h = ARTWORK_SIZE;
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
  c.width = ARTWORK_SIZE; c.height = ARTWORK_SIZE;
  const ctx = c.getContext('2d');
  const imgData = ctx.createImageData(ARTWORK_SIZE, ARTWORK_SIZE);
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

// Composites fillCanvas + brushCanvas + lineArtCanvas into one flat image
// (for the Completion preview and for dynamic progress-thumbnail previews —
// see updateLessonPreview() below). All three source layers are already
// canvases, so — unlike the prior SVG-based line art — this needs no async
// image-load step; callback is invoked synchronously, kept as a callback
// only so callers don't need to change. `size` defaults to the full
// ARTWORK_SIZE (Completion's large preview); pass PREVIEW_SIZE for the small
// 250×250 progress-thumbnail case.
function renderArtboardToDataURL(callback, size){
  const s = size || ARTWORK_SIZE;
  const composite = document.createElement('canvas');
  composite.width = s; composite.height = s;
  const ctx = composite.getContext('2d');
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, s, s);

  const fillCanvas = document.getElementById('fillCanvas');
  const brushCanvasEl = document.getElementById('brushCanvas');
  const lineArtCanvasEl = document.getElementById('lineArtCanvas');
  if(fillCanvas) ctx.drawImage(fillCanvas, 0, 0, s, s);
  if(brushCanvasEl) ctx.drawImage(brushCanvasEl, 0, 0, s, s);
  if(lineArtCanvasEl) ctx.drawImage(lineArtCanvasEl, 0, 0, s, s);

  callback(composite.toDataURL('image/png'));
}

// --- Dynamic progress thumbnails --------------------------------------
// Home/Library/Search/Profile/Completion-recommendations must show the
// CURRENT coloring state of a lesson, not always the static original
// thumbnail. One cache, one source of truth: lessonPreviewCache[lessonId] is
// a 250×250 data URL composited from the SAME live canvases Editor itself
// draws (via renderArtboardToDataURL above) — never a separately-tracked
// fake color state. Regenerated only at meaningful lifecycle points (stroke/
// fill/undo/redo commit via markSaving(), Editor exit, Done), not on every
// pointermove — see updateLessonPreview() call sites.
const PREVIEW_SIZE = 250;
let lessonPreviewCache = {}; // lessonId -> data URL, present only once a lesson has real progress

function updateLessonPreview(lessonId){
  if(!lessonId) return;
  renderArtboardToDataURL(dataUrl => { lessonPreviewCache[lessonId] = dataUrl; }, PREVIEW_SIZE);
}

// Every screen's thumbnail resolves through this one helper: dynamic preview
// if the lesson has progress, else the original static asset — never a
// second/fake thumbnail state.
function lessonPreviewSrc(lesson){
  if(!lesson) return '';
  return lessonPreviewCache[lesson.id] || lesson.thumbnail;
}

// ---------------------------------------------------------------------------
// FILL — flood fill using the exact same region-mask engine as Locked Brush.
// Renders onto #fillCanvas (the bottom-most visual layer — see index.html),
// never touching the immutable #lineArtCanvas or #brushCanvas above it.
// ---------------------------------------------------------------------------
function performFillAt(px, py){
  if(!barrierMaskReady) return;
  const mask = floodFillMaskFrom(px, py);
  if(!mask) return; // tapped directly on a barrier line — nothing to fill

  const canvas = document.getElementById('fillCanvas');
  const ctx = canvas.getContext('2d');
  const before = ctx.getImageData(0, 0, ARTWORK_SIZE, ARTWORK_SIZE);
  const after = ctx.createImageData(ARTWORK_SIZE, ARTWORK_SIZE);
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
  // Erase is true transparent removal (destination-out clears pixels back to
  // alpha 0, revealing whatever sits below — fillCanvas color, or the raw
  // white artboard) — never a painted color, so it can never cover the
  // immutable line-art with an opaque patch. strokeStyle's color is
  // irrelevant for destination-out; only the stroked shape/alpha matters.
  ctx.globalCompositeOperation = stroke.tool === 'erase' ? 'destination-out' : 'source-over';
  ctx.strokeStyle = stroke.tool === 'erase' ? 'rgba(0,0,0,1)' : stroke.color;
  ctx.beginPath();
  stroke.points.forEach((p, i) => { if(i === 0) ctx.moveTo(p.x, p.y); else ctx.lineTo(p.x, p.y); });
  if(stroke.points.length === 1){
    // A tap with no drag — draw a dot so a single click is still visible.
    ctx.lineTo(stroke.points[0].x + 0.01, stroke.points[0].y);
  }
  ctx.stroke();
  ctx.globalCompositeOperation = 'source-over'; // reset for whatever draws on this context next
}

function drawStroke(ctx, stroke){
  if(!stroke.maskCanvas){
    strokePath(ctx, stroke);
    return;
  }
  const temp = document.createElement('canvas');
  temp.width = ARTWORK_SIZE; temp.height = ARTWORK_SIZE;
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
  ctx.clearRect(0, 0, ARTWORK_SIZE, ARTWORK_SIZE);
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
  const x = Math.max(0, Math.min(ARTWORK_SIZE - 1, Math.round(px)));
  const y = Math.max(0, Math.min(ARTWORK_SIZE - 1, Math.round(py)));
  if(barrierMaskReady && barrierMask && barrierMask[y * ARTWORK_SIZE + x]) return '#111111';
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
    tool: activeTool, // 'brush' or 'erase' — strokePath() uses this to pick paint vs. true removal
    color: activeTool === 'erase' ? null : activeColor, // irrelevant for erase (destination-out)
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

// --- Gesture routing layer (pinch-zoom / two-finger pan / desktop pan) ----
// Sits in front of onArtboardPointerDown/Move/Up/Cancel above (which are
// UNCHANGED — still the exact single-pointer paint/fill/eyedropper logic).
// A single active pointer always falls straight through to those, so normal
// mouse/single-touch coloring behaves identically to before. A SECOND
// simultaneous pointer switches into a pinch/pan gesture instead — any
// in-progress stroke is cancelled first, per spec: a two-finger gesture must
// never be interpreted as Brush drawing.
let activePointers = new Map(); // pointerId -> {x, y} in client (screen) coords
let gestureActive = false;
let gesturePrevDist = null;
let gesturePrevMid = null;
let gestureUpdateScheduled = false; // see scheduleGestureUpdate()

function pointerDistance(a, b){ return Math.hypot(a.x - b.x, a.y - b.y); }
function pointerMidpoint(a, b){ return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }; }

// The two fingers of a pinch/pan gesture are independent event streams —
// their pointermove events do not arrive perfectly interleaved, so reading
// activePointers synchronously inside a single finger's own pointermove can
// see the OTHER finger's now-stale last-known position, producing a
// momentarily wrong distance/midpoint (and therefore visible scale jitter,
// even during a pure two-finger drag where the real distance never
// changes). Batching the actual recompute into one rAF per frame lets BOTH
// fingers' latest positions land in the Map first, so the gesture is always
// evaluated from a consistent snapshot.
function runGestureUpdate(){
  gestureUpdateScheduled = false;
  if(!gestureActive || activePointers.size < 2) return;
  const pts = Array.from(activePointers.values()).slice(0, 2);
  const dist = pointerDistance(pts[0], pts[1]);
  const mid = pointerMidpoint(pts[0], pts[1]);
  if(gesturePrevDist && gesturePrevMid){
    const nextScale = editorViewState.scale * (dist / gesturePrevDist);
    panZoomEditorTo(gesturePrevMid, mid, nextScale);
  }
  gesturePrevDist = dist;
  gesturePrevMid = mid;
}

function scheduleGestureUpdate(){
  if(gestureUpdateScheduled) return;
  gestureUpdateScheduled = true;
  requestAnimationFrame(runGestureUpdate);
}

function cancelInProgressStroke(){
  if(eyedropperDragging){ cancelEyedropperSample(); }
  if(!activeStroke) return;
  const idx = strokesList.indexOf(activeStroke);
  if(idx !== -1) strokesList.splice(idx, 1);
  activeStroke = null;
  redrawBrushCanvas();
}

// Desktop pan (mouse): middle-mouse-button drag, or holding Space + left-
// drag — neither collides with any existing left-click tool behavior, so
// painting/Fill/Eyedropper are unaffected when panning isn't in use.
let spacePanning = false;
let mousePanning = false;
let mousePanLast = null;

function onViewportPointerDown(e){
  if(e.pointerType === 'mouse' && (e.button === 1 || (e.button === 0 && spacePanning))){
    cancelInProgressStroke();
    mousePanning = true;
    mousePanLast = { x: e.clientX, y: e.clientY };
    const viewport = document.getElementById('artboardViewport');
    if(viewport){
      viewport.classList.add('panning');
      if(viewport.setPointerCapture && e.pointerId != null){
        try { viewport.setPointerCapture(e.pointerId); } catch(err) { /* not critical for the prototype */ }
      }
    }
    e.preventDefault();
    return;
  }

  activePointers.set(e.pointerId, { x: e.clientX, y: e.clientY });

  if(activePointers.size === 2){
    cancelInProgressStroke();
    gestureActive = true;
    const pts = Array.from(activePointers.values());
    gesturePrevDist = pointerDistance(pts[0], pts[1]);
    gesturePrevMid = pointerMidpoint(pts[0], pts[1]);
    e.preventDefault();
    return;
  }

  if(activePointers.size === 1 && !gestureActive){
    onArtboardPointerDown(e);
  }
}

function onViewportPointerMove(e){
  if(mousePanning){
    panEditorBy(e.clientX - mousePanLast.x, e.clientY - mousePanLast.y);
    mousePanLast = { x: e.clientX, y: e.clientY };
    e.preventDefault();
    return;
  }

  if(activePointers.has(e.pointerId)) activePointers.set(e.pointerId, { x: e.clientX, y: e.clientY });

  if(gestureActive && activePointers.size >= 2){
    // Record this finger's latest position now; the actual pinch/pan math
    // runs once per animation frame from BOTH fingers' latest positions —
    // see scheduleGestureUpdate() above.
    scheduleGestureUpdate();
    e.preventDefault();
    return;
  }

  if(!gestureActive){
    onArtboardPointerMove(e);
  }
}

function endViewportGesturePointer(e){
  // Flush any pending rAF-batched gesture update FIRST, while this pointer's
  // final position is still in activePointers — otherwise the last bit of
  // movement between the previous frame and this lift could be silently
  // dropped (the rAF callback would later see gestureActive already false /
  // the pointer already removed, and bail out doing nothing).
  if(gestureUpdateScheduled) runGestureUpdate();
  activePointers.delete(e.pointerId);
  if(mousePanning){
    mousePanning = false;
    mousePanLast = null;
    const viewport = document.getElementById('artboardViewport');
    if(viewport) viewport.classList.remove('panning');
    return true;
  }
  if(gestureActive){
    if(activePointers.size < 2){
      gestureActive = false;
      gesturePrevDist = null;
      gesturePrevMid = null;
      // A single finger still down after a pinch/two-finger-pan ends does
      // NOT resume painting mid-gesture — the user must lift and start a
      // fresh single-finger touch, per spec.
    }
    return true;
  }
  return false;
}

function onViewportPointerUp(e){
  if(endViewportGesturePointer(e)) return;
  onArtboardPointerUp(e);
}

function onViewportPointerCancel(e){
  if(endViewportGesturePointer(e)) return;
  onArtboardPointerCancel(e);
}

// Desktop zoom: Ctrl+wheel (browsers also report trackpad pinch as a wheel
// event with ctrlKey:true — the same standard convention Chrome/Firefox/
// Safari use) or a plain wheel anywhere over the artwork both zoom, per spec.
function onArtboardWheel(e){
  e.preventDefault();
  const factor = Math.exp(-e.deltaY * 0.0018);
  zoomEditorAt(e.clientX, e.clientY, editorViewState.scale * factor);
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
  // Normal <-> Expanded must PRESERVE the current zoom/pan state (never
  // reset artwork coloring or scale/position) — editorViewState itself is
  // untouched here. .artboard's own box size changes between modes though
  // (76% vs 94% width, see styles.css), so pan needs re-clamping against the
  // new container rect; applyEditorTransform() does that. A transitionend
  // listener (module init, below) reapplies it once more after the CSS
  // width transition finishes, since getBoundingClientRect() here still
  // reflects the pre-toggle frame.
  applyEditorTransform();
}

// ===========================================================================
// EDITOR ZOOM / PAN — an interaction state of SCR-EDITOR-001 itself (both
// Normal and Expanded/Focus mode), not a new screen or a second artwork.
//
// #artboardViewport (wrapping fillCanvas/brushCanvas/lineArtCanvas — see
// index.html) is the ONLY thing that ever gets a CSS transform; .artboard
// itself never moves and clips via overflow:hidden, so pan/zoom can never
// visually escape the card. Because the transform lives on an ANCESTOR of
// the canvases, canvasPointFromEvent()'s existing
// getBoundingClientRect()-based math (unchanged, see below) already resolves
// screen coordinates through the current pan/zoom automatically — the
// browser's own transform-aware layout geometry does the "subtract origin /
// undo pan / divide by scale" work for us, so Brush/Locked Brush/Fill/Erase/
// Eyedropper all continue to use correct 800×800 source coordinates with no
// changes to their own code.
// ===========================================================================
let editorViewState = { scale: 1, translateX: 0, translateY: 0 };
const EDITOR_ZOOM_MIN = 1, EDITOR_ZOOM_MAX = 4;

// transform-origin:0 0 on #artboardViewport (see styles.css) makes
// translateX/Y the screen offset of the viewport's own top-left corner, and
// clampEditorView()'s bounds fall out of one rule: the scaled content's
// edges may never leave a gap inside the (static) .artboard box. At scale 1
// that forces translate back to exactly (0,0) — "restore centered artwork".
function clampEditorView(){
  editorViewState.scale = Math.max(EDITOR_ZOOM_MIN, Math.min(EDITOR_ZOOM_MAX, editorViewState.scale));
  const artboardEl = document.getElementById('artboard');
  if(!artboardEl) return;
  const rect = artboardEl.getBoundingClientRect();
  const s = editorViewState.scale;
  const minTx = rect.width * (1 - s), minTy = rect.height * (1 - s);
  editorViewState.translateX = Math.max(minTx, Math.min(0, editorViewState.translateX));
  editorViewState.translateY = Math.max(minTy, Math.min(0, editorViewState.translateY));
}

function applyEditorTransform(){
  clampEditorView();
  const viewport = document.getElementById('artboardViewport');
  if(viewport) viewport.style.transform = `translate(${editorViewState.translateX}px, ${editorViewState.translateY}px) scale(${editorViewState.scale})`;
  const artboardEl = document.getElementById('artboard');
  if(artboardEl) artboardEl.dataset.zoomScale = editorViewState.scale.toFixed(2); // optional test hook, mirrors data-state
}

// Called whenever a lesson's artwork is (re)loaded — zoom/pan is a per-
// viewing-session convenience, not part of the lesson's saved progress, so a
// freshly opened (or re-opened) lesson always starts at a clean 1x/centered
// view. Switching Normal<->Expanded for the SAME open lesson is the only
// case that preserves it — see toggleZoom() above.
function resetEditorView(){
  editorViewState = { scale: 1, translateX: 0, translateY: 0 };
  applyEditorTransform();
}

// Zooms so that whatever artwork content is currently under the given
// SCREEN point (e.g. the cursor, or a pinch gesture's midpoint) stays
// visually fixed at that same screen point after the scale change — the
// gesture's focal point stays put while everything around it magnifies.
// Whatever artwork content was under `fromClient` (a screen point) BEFORE
// this call ends up under `toClient` AFTER it, as scale changes to
// newScale. This is the one real primitive: a pure zoom is fromClient ===
// toClient (the focal point stays put while scale changes); a pure
// two-finger drag pan is fromClient !== toClient with newScale left equal
// to the current scale (the content follows the finger delta exactly); a
// real pinch gesture combines both by passing the gesture's PREVIOUS
// midpoint as fromClient and its CURRENT midpoint as toClient every move.
function panZoomEditorTo(fromClient, toClient, newScale){
  const artboardEl = document.getElementById('artboard');
  if(!artboardEl) return;
  const rect = artboardEl.getBoundingClientRect();
  const s = editorViewState.scale;
  const contentX = (fromClient.x - rect.left - editorViewState.translateX) / s;
  const contentY = (fromClient.y - rect.top - editorViewState.translateY) / s;
  const sNew = Math.max(EDITOR_ZOOM_MIN, Math.min(EDITOR_ZOOM_MAX, newScale));
  editorViewState.translateX = toClient.x - rect.left - contentX * sNew;
  editorViewState.translateY = toClient.y - rect.top - contentY * sNew;
  editorViewState.scale = sNew;
  applyEditorTransform();
}

// Pure zoom around a fixed screen point (wheel zoom) — the focal point
// itself never moves, so from === to.
function zoomEditorAt(clientX, clientY, newScale){
  panZoomEditorTo({ x: clientX, y: clientY }, { x: clientX, y: clientY }, newScale);
}

function panEditorBy(dx, dy){
  editorViewState.translateX += dx;
  editorViewState.translateY += dy;
  applyEditorTransform();
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
  // Routed through the gesture layer (pinch-zoom / two-finger pan / desktop
  // pan) first — a single pointer always falls straight through to the
  // original paint/fill/eyedropper handlers unchanged. See "Gesture routing
  // layer" above.
  brushCanvasEl.addEventListener('pointerdown', onViewportPointerDown);
  brushCanvasEl.addEventListener('pointermove', onViewportPointerMove);
  brushCanvasEl.addEventListener('pointerup', onViewportPointerUp);
  brushCanvasEl.addEventListener('pointercancel', onViewportPointerCancel);
}

const artboardEl = document.getElementById('artboard');
if(artboardEl){
  artboardEl.addEventListener('wheel', onArtboardWheel, { passive: false });
  // Re-clamp/reapply pan once the Normal<->Expanded width transition
  // finishes — toggleZoom()'s own applyEditorTransform() call already
  // clamps against the pre-toggle frame; this catches the settled frame too.
  artboardEl.addEventListener('transitionend', (e) => { if(e.propertyName === 'width') applyEditorTransform(); });
}
window.addEventListener('keydown', (e) => { if(e.code === 'Space') spacePanning = true; });
window.addEventListener('keyup', (e) => { if(e.code === 'Space') spacePanning = false; });

const hueRingWrap = document.getElementById('hueRingWrap');
if(hueRingWrap){
  hueRingWrap.addEventListener('pointerdown', onHueRingPointerDown);
  hueRingWrap.addEventListener('pointermove', onHueRingPointerMove);
  hueRingWrap.addEventListener('pointerup', onHueRingPointerUp);
  hueRingWrap.addEventListener('pointercancel', onHueRingPointerUp);
}

syncFocusIndicators(); // match the seeded default activeTool/activeColor

// --- Horizontal drag-to-scroll (Home category rows, Library filter chips) --
// overflow-x:auto already gives real touch devices native swipe scrolling
// for free; this adds POINTER-drag scrolling (mouse, and mobile-emulation
// pointer events) on top, since a plain mouse click-drag does not scroll an
// overflow container on its own. A small movement threshold distinguishes a
// genuine drag from a tap, and a real drag suppresses the click that would
// otherwise follow — so dragging the row never accidentally opens an
// artwork or changes the selected filter.
function enableDragScroll(container){
  if(!container) return;
  let dragging = false;
  let moved = false;
  let startX = 0;
  let startScrollLeft = 0;
  const THRESHOLD = 6;

  container.addEventListener('pointerdown', (e) => {
    dragging = true;
    moved = false;
    startX = e.clientX;
    startScrollLeft = container.scrollLeft;
  });
  container.addEventListener('pointermove', (e) => {
    if(!dragging) return;
    const dx = e.clientX - startX;
    if(!moved && Math.abs(dx) > THRESHOLD) moved = true;
    if(moved){
      container.scrollLeft = startScrollLeft - dx;
      e.preventDefault();
    }
  });
  const endDrag = () => {
    if(!dragging) return;
    dragging = false;
    if(moved){
      container.dataset.justDragged = 'true';
      setTimeout(() => { delete container.dataset.justDragged; }, 0);
    }
  };
  container.addEventListener('pointerup', endDrag);
  container.addEventListener('pointercancel', endDrag);
  container.addEventListener('click', (e) => {
    if(container.dataset.justDragged === 'true'){
      e.stopPropagation();
      e.preventDefault();
    }
  }, true);
}

document.querySelectorAll('.featured-row, .library-filters').forEach(enableDragScroll);

// Kicks off the real content load — Home category sections, the Library
// grid, and the Continue card (which needs both LESSONS_BY_ID and the seeded
// progressStore) all render once this resolves. See loadContent() above.
loadContent();
