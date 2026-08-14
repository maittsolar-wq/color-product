let activeColor = '#168B2D';
let activeTool = 'brush';
let zoomed = false;
let currentArtworkId = 'draw_animals_001';

const progressStore = {
  draw_animals_001: 'IN_PROGRESS',
  draw_nature_001: 'COMPLETED'
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

function filterProfile(status, btn){
  const scope = document.querySelector('[data-screen-id="SCR-PROFILE-001"]');
  if(!scope) return;
  scope.querySelectorAll('.profile-segmented button').forEach(b => b.classList.remove('selected'));
  if(btn) btn.classList.add('selected');

  const cards = scope.querySelectorAll('.drawing-card');
  cards.forEach(card => {
    const show = status === 'all' || card.dataset.status === status;
    card.style.display = show ? '' : 'none';
  });
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
