let activeColor = '#168B2D';
let activeTool = 'brush';
let zoomed = false;
let currentArtworkId = 'draw_animals_001';

const progressStore = {
  draw_animals_001: 'IN_PROGRESS',
  draw_nature_001: 'COMPLETED'
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
}

function openArtwork(drawingId){
  currentArtworkId = drawingId;
  if(!progressStore[drawingId]){
    progressStore[drawingId] = 'IN_PROGRESS';
  }
  showScreen('SCR-EDITOR-001');
}

function completeArtwork(){
  progressStore[currentArtworkId] = 'COMPLETED';
  showScreen('SCR-COMPLETE-001');
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

function fillRegion(el){
  if(activeTool === 'erase'){
    el.setAttribute('fill','#fff');
  } else {
    el.setAttribute('fill',activeColor);
  }
  const status = document.getElementById('saveStatus');
  status.textContent = 'Saving...';
  setTimeout(()=>status.textContent='Saved',350);
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
