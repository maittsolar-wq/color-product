let activeColor = '#168B2D';
let activeTool = 'brush';
let zoomed = false;

function showScreen(id){
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  const target = document.querySelector(`[data-screen-id="${id}"]`);
  if(target) target.classList.add('active');
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
