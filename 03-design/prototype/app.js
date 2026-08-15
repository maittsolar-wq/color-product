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
let undoStack = [];
let redoStack = [];

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
  updateHistoryButtons();

  showScreen('SCR-EDITOR-001');
}

function exitEditor(){
  // Autosave is already continuous (fillRegion/undo/redo flip the Saving/
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
    // For the one artwork with real interactive fill state, clone the live,
    // currently-colored SVG rather than falling back to its flat thumbnail —
    // "the most faithful available way" the prototype can show it.
    const liveSvg = currentArtworkId === 'draw_animals_001'
      ? document.querySelector('#artboard svg')
      : null;
    if(liveSvg){
      const clone = liveSvg.cloneNode(true);
      // Static preview only — strip ids/handlers so the clone can't collide
      // with the live Editor's #region_001/#region_002 (duplicate DOM ids)
      // and can't be tapped to fill, since this isn't a second editable canvas.
      clone.removeAttribute('id');
      clone.querySelectorAll('[id]').forEach(el => el.removeAttribute('id'));
      clone.querySelectorAll('[onclick]').forEach(el => el.removeAttribute('onclick'));
      card.appendChild(clone);
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

const settingsState = { sound: true };

function toggleSetting(key, btn){
  settingsState[key] = !settingsState[key];
  const on = settingsState[key];
  btn.setAttribute('aria-checked', String(on));
  const sw = btn.querySelector('.toggle-switch');
  if(sw) sw.dataset.state = on ? 'on' : 'off';
}

function selectColor(btn){
  activeColor = btn.dataset.color;
  document.querySelectorAll('.palette .color').forEach(c=>{
    c.classList.remove('selected');
    c.setAttribute('aria-pressed','false');
  });
  btn.classList.add('selected');
  btn.setAttribute('aria-pressed','true');
  const palette = document.querySelector('.palette');
  if(palette) palette.dataset.activeColor = activeColor;
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
}

function markSaving(){
  const status = document.getElementById('saveStatus');
  if(!status) return;
  status.textContent = 'Saving...';
  setTimeout(()=>status.textContent='Saved',350);
}

function fillRegion(el){
  // Brush has no region-tap semantics in this prototype (no freehand stroke
  // engine — see report). A tap while Brush is active must NOT accidentally
  // run Fill's behavior.
  if(activeTool === 'brush') return;

  const nextFill = activeTool === 'erase' ? '#fff' : activeColor;
  const prevFill = el.getAttribute('fill');
  if(prevFill === nextFill) return; // nothing actually changed — no history entry

  el.setAttribute('fill', nextFill);
  undoStack.push({ el, prevFill });
  redoStack = [];
  progressUpdatedAt[currentArtworkId] = Date.now();
  updateHistoryButtons();
  markSaving();
}

function updateHistoryButtons(){
  const undoBtn = document.querySelector('[data-testid="undo"]');
  const redoBtn = document.querySelector('[data-testid="redo"]');
  if(undoBtn) undoBtn.disabled = undoStack.length === 0;
  if(redoBtn) redoBtn.disabled = redoStack.length === 0;
}

function undoAction(){
  if(undoStack.length === 0) return; // never fake an enabled state with nothing to undo
  const action = undoStack.pop();
  const currentFill = action.el.getAttribute('fill');
  action.el.setAttribute('fill', action.prevFill);
  redoStack.push({ el: action.el, prevFill: currentFill });
  progressUpdatedAt[currentArtworkId] = Date.now();
  updateHistoryButtons();
  markSaving();
}

function redoAction(){
  if(redoStack.length === 0) return;
  const action = redoStack.pop();
  const currentFill = action.el.getAttribute('fill');
  action.el.setAttribute('fill', action.prevFill);
  undoStack.push({ el: action.el, prevFill: currentFill });
  progressUpdatedAt[currentArtworkId] = Date.now();
  updateHistoryButtons();
  markSaving();
}

function toggleZoom(){
  zoomed = !zoomed;
  const artboard = document.getElementById('artboard');
  artboard.classList.toggle('zoomed', zoomed);
  artboard.dataset.state = zoomed ? 'zoomed' : 'default';
  const fitBtn = document.querySelector('[data-testid="editor-fit"]');
  if(fitBtn) fitBtn.setAttribute('aria-pressed', String(zoomed));
}

const slider = document.getElementById('brushSlider');
if(slider){
  const updateSliderFill = () => {
    slider.style.setProperty('--p', `${slider.value}%`);
  };
  updateSliderFill();
  slider.addEventListener('input', updateSliderFill);
}

// Home is the initially-active screen in static markup — showScreen() is
// never called for that first render, so the Continue card needs one
// explicit initial render to match the seeded progressStore state.
renderHomeContinue();
