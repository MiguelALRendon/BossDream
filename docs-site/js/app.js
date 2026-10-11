const DATA = window.SITE_DATA;
const FLOWS = window.FLOWS;
const REDUCED = matchMedia('(prefers-reduced-motion: reduce)').matches;
const FUSE_URL = 'https://cdn.jsdelivr.net/npm/fuse.js@7.5.0/dist/fuse.min.mjs';
const MERMAID_URL = 'https://cdn.jsdelivr.net/npm/mermaid@12.1.0/dist/mermaid.min.js';

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const inline = (s) => esc(s).replace(/`([^`]+)`/g, '<code>$1</code>');
const store = {
  get: (k) => { try { return localStorage.getItem(k); } catch (e) { return null; } },
  set: (k, v) => { try { localStorage.setItem(k, v); } catch (e) { return; } }
};

const ICONS = {
  inicio: 'M3 11l9-8 9 8M5 10v10h14V10',
  instalar: 'M12 3v12m0 0l-4-4m4 4l4-4M4 21h16',
  comandos: 'M4 5h16v14H4zM8 10l3 2-3 2M13 15h4',
  skills: 'M12 3l9 5-9 5-9-5zM3 13l9 5 9-5',
  agentes: 'M12 8a3 3 0 100-6 3 3 0 000 6zM5 21v-2a7 7 0 0114 0v2',
  flujos: 'M6 3v12M18 9a3 3 0 100-6 3 3 0 000 6zM6 21a3 3 0 100-6 3 3 0 000 6zM18 9c0 6-12 3-12 6',
  pipeline: 'M4 6h10M4 12h16M4 18h7',
  templates: 'M3 6h6l2 2h10v12H3z',
  mcp: 'M9 2v6M15 2v6M6 8h12v4a6 6 0 01-12 0zM12 18v4',
  config: 'M4 6h16M4 12h16M4 18h16M9 4v4M15 10v4M8 16v4',
  estado: 'M12 22a10 10 0 100-20 10 10 0 000 20zM8 12l3 3 5-6'
};

const TABS = [
  ['inicio', 'Inicio'], ['instalar', 'Instalar'], ['comandos', 'Comandos', () => DATA.commands.length],
  ['skills', 'Skills', () => DATA.skills.length], ['agentes', 'Agentes', () => DATA.agents.length],
  ['flujos', 'Flujos', () => FLOWS.length], ['pipeline', 'Pipeline', () => DATA.pipeline.nodejs.length],
  ['templates', 'Templates'], ['mcp', 'MCP', () => DATA.mcp.length], ['config', 'Config'], ['estado', 'Estado']
];

let fuseCtor = null;
let lenis = null;

function toast(msg) {
  const el = $('#toast');
  el.textContent = msg;
  el.classList.add('show');
  clearTimeout(toast.t);
  toast.t = setTimeout(() => el.classList.remove('show'), 1600);
}

async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
    toast('Copiado');
  } catch (e) {
    toast('No se pudo copiar');
  }
}

function buildTabs() {
  $('#tabs').innerHTML = TABS.map(([id, label, count]) =>
    `<a class="tab" href="#${id}" data-tab-link="${id}"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="${ICONS[id]}"/></svg><span>${label}</span>${count ? `<span class="count">${count()}</span>` : ''}</a>`
  ).join('');
}

function showTab(id) {
  const tab = TABS.some(([t]) => t === id) ? id : 'inicio';
  $$('.panel').forEach((p) => { p.hidden = p.dataset.tab !== tab; });
  $$('.tab').forEach((a) => { if (a.dataset.tabLink === tab) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current'); });
  $(`.tab[data-tab-link="${tab}"]`)?.scrollIntoView({ inline: 'center', block: 'nearest' });
  window.scrollTo(0, 0);
  lenis?.scrollTo(0, { immediate: true });
  observeReveals();
  if (tab === 'flujos') renderFlow(currentFlow);
}

function route() {
  showTab(location.hash.replace('#', '') || 'inicio');
}

function observeReveals() {
  const targets = $$('.panel:not([hidden]) .reveal:not(.in)');
  if (REDUCED || !('IntersectionObserver' in window)) return targets.forEach((el) => el.classList.add('in'));
  targets.forEach((el, i) => el.style.setProperty('--d', `${Math.min(i % 4, 3) * 70}ms`));
  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } });
  }, { threshold: 0.08, rootMargin: '0px 0px -30px 0px' });
  targets.forEach((el) => io.observe(el));
}

function countUp(el, to) {
  if (REDUCED) { el.textContent = to; return; }
  const start = performance.now();
  const tick = (now) => {
    const p = Math.min((now - start) / 900, 1);
    el.textContent = Math.round(to * (1 - Math.pow(1 - p, 3)));
    if (p < 1) requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
}

function renderStats() {
  const items = [
    ['Comandos', DATA.commands.length], ['Skills', DATA.skills.length], ['Agentes', DATA.agents.length],
    ['MCP', DATA.mcp.length], ['Etapas de pipeline', DATA.pipeline.nodejs.length]
  ];
  $('#stats').innerHTML = items.map(([k, v]) => `<div class="stat"><dd data-to="${v}">0</dd><dt>${k}</dt></div>`).join('');
  $$('#stats dd').forEach((dd) => countUp(dd, Number(dd.dataset.to)));
}

function renderArch() {
  const notes = {
    'bossdream-core': 'El motor: Delivery Cycle, pipeline, Completion Criteria, hooks, 11 MCP y la gobernanza de documentos de negocio.',
    'bossdream-dotnet': 'Pack de lenguaje .NET: pipeline, CI, editorconfig y permisos de dotnet.',
    'bossdream-nodejs': 'Pack de lenguaje Node y TypeScript: Vitest, Prettier, Playwright y Stryker JS.'
  };
  $('#arch').innerHTML = DATA.plugins.map((p) =>
    `<article class="card spot ${p.name === 'bossdream-core' ? 'core' : ''}"><span class="ver">v${esc(p.version)}${p.name === 'bossdream-core' ? ' · obligatorio' : ' · elige uno'}</span><h3>${esc(p.name)}</h3><p>${esc(notes[p.name])}</p></article>`
  ).join('');
  $('#foot-version').textContent = DATA.plugins[0].version;
}

function toolLabel(t) {
  return t.replace('mcp__plugin_bossdream-core_', 'mcp:');
}

const KINDS = {
  comandos: { data: () => DATA.commands, prefix: '/', lead: (n) => `${n} comandos del plugin. Los que llevan "solo usuario" no los dispara el modelo por su cuenta.` },
  skills: { data: () => DATA.skills, prefix: '', lead: (n) => `${n} skills. Las marcadas "slash" también se invocan tecleándolas.` },
  agentes: { data: () => DATA.agents, prefix: '', lead: (n) => `${n} agentes. Los auditores corren en contexto desechable y no escribieron el código que revisan.` }
};

function itemTags(kind, it) {
  const tags = [`<span class="group-label">${esc(it.group)}</span>`];
  if (kind === 'comandos' && it.userOnly) tags.push('<span class="tag hot">solo usuario</span>');
  if (kind === 'skills' && it.userOnly) tags.push('<span class="tag hot">slash</span>');
  if (kind === 'agentes' && it.model) tags.push(`<span class="tag hot">${esc(it.model)}</span>`);
  return tags.join('');
}

function itemMore(kind, it) {
  const parts = [];
  if (it.args?.length) parts.push(`<div class="tags">${it.args.map((a) => `<span class="tag">arg: ${esc(a)}</span>`).join('')}</div>`);
  if (kind === 'agentes' && it.tools.length) parts.push(`<div class="tags">${it.tools.map((t) => `<span class="tag ${t.startsWith('mcp__') ? 'hot' : ''}">${esc(toolLabel(t))}</span>`).join('')}</div>`);
  return parts.join('') || '<span>Sin detalle adicional.</span>';
}

function agentSource(it) {
  return `<div class="code"><pre><code>${esc(it.source)}</code></pre><button type="button" class="copy-btn" data-copy-sibling aria-label="Copiar el markdown del agente">Copiar</button></div>`;
}

function renderItem(kind, it) {
  const prefix = kind === 'comandos' || (kind === 'skills' && it.userOnly) ? '/' : '';
  return `<article class="card item spot" id="${kind}-${esc(it.name)}" tabindex="0" role="button" aria-expanded="false">
    <div class="item-head"><span class="item-name" data-prefix="${prefix}">${esc(it.name)}</span></div>
    <div class="tags">${itemTags(kind, it)}</div>
    <p class="item-desc">${inline(it.description)}</p>
    ${kind === 'agentes' ? agentSource(it) : ''}
    <div class="item-more">${itemMore(kind, it)}</div></article>`;
}

function matches(kind, state) {
  let list = KINDS[kind].data();
  if (state.group) list = list.filter((i) => i.group === state.group);
  const q = state.query.trim();
  if (!q) return list;
  if (!fuseCtor) return list.filter((i) => `${i.name} ${i.description}`.toLowerCase().includes(q.toLowerCase()));
  const fuse = new fuseCtor(list, { keys: [{ name: 'name', weight: 2 }, 'description', 'group'], threshold: 0.35, ignoreLocation: true });
  return fuse.search(q).map((r) => r.item);
}

function paintList(kind, state) {
  const found = matches(kind, state);
  $(`#list-${kind}`).innerHTML = found.length
    ? found.map((it) => renderItem(kind, it)).join('')
    : '<p class="empty">Nada coincide con ese filtro.</p>';
}

function setupList(kind) {
  const state = { query: '', group: '' };
  const groups = [...new Set(KINDS[kind].data().map((i) => i.group))];
  $(`#lead-${kind}`).textContent = KINDS[kind].lead(KINDS[kind].data().length);
  const chips = $(`[data-chips="${kind}"]`);
  chips.innerHTML = ['Todos', ...groups].map((g, i) => `<button type="button" class="chip" aria-pressed="${i === 0}" data-g="${i === 0 ? '' : esc(g)}">${esc(g)}</button>`).join('');
  chips.addEventListener('click', (e) => {
    const b = e.target.closest('.chip');
    if (!b) return;
    state.group = b.dataset.g;
    $$('.chip', chips).forEach((c) => c.setAttribute('aria-pressed', String(c === b)));
    paintList(kind, state);
  });
  $(`.filter[data-list="${kind}"]`).addEventListener('input', (e) => { state.query = e.target.value; paintList(kind, state); });
  paintList(kind, state);
  KINDS[kind].repaint = () => paintList(kind, state);
}

function toggleItem(card) {
  const open = card.classList.toggle('open');
  card.setAttribute('aria-expanded', String(open));
}

function renderMcp() {
  $('#lead-mcp').textContent = `${DATA.mcp.length} servidores con versión fijada, listos al habilitar el plugin.`;
  $('#list-mcp').innerHTML = DATA.mcp.map((m) =>
    `<article class="card spot reveal" id="mcp-${esc(m.name)}"><div class="item-head"><span class="item-name">${esc(m.name)}</span></div><p class="item-desc" style="-webkit-line-clamp:unset;display:block">${esc(m.note)}</p><div class="tags"><span class="tag hot">${esc(m.runner)}</span><span class="tag">${esc(m.package)}</span></div></article>`
  ).join('');
}

function renderDebt() {
  $('#list-debt').innerHTML = DATA.debt.map((d) =>
    `<article class="card spot reveal"><div class="tags" style="margin:0 0 8px"><span class="tag hot">${esc(d.id)}</span><span class="tag">${esc(d.severity)}</span><span class="tag">${esc(d.status)}</span></div><h3>${esc(d.where)}</h3><p>${inline(d.problem)}</p><p class="note"><b>Salida:</b> ${inline(d.fix)}</p></article>`
  ).join('');
  $('#plugins-table').innerHTML = `<thead><tr><th>Plugin</th><th>Versión</th><th>Rol</th></tr></thead><tbody>${DATA.plugins.map((p) =>
    `<tr><td><code>${esc(p.name)}</code></td><td>${esc(p.version)}</td><td>${p.name === 'bossdream-core' ? 'Motor' : 'Pack de lenguaje'}</td></tr>`).join('')}</tbody>`;
}

function renderPipeline(stack) {
  const rows = DATA.pipeline[stack];
  $('#pipeline-table').innerHTML = `<thead><tr><th>#</th><th>Etapa</th><th>Comando</th><th>Tier</th><th>Bloqueo</th></tr></thead><tbody>${rows.map((s) =>
    `<tr class="${s.enabled ? '' : 'off'}"><td>${s.order}</td><td><code>${esc(s.id)}</code></td><td><code>${esc(s.cmd)}</code>${s.enabled ? '' : ' <span class="tag">apagada</span>'}</td><td>${esc(s.tier)}</td><td>${esc(s.blocking)}</td></tr>`).join('')}</tbody>`;
  $$('#pipeline-seg button').forEach((b) => b.classList.toggle('on', b.dataset.stack === stack));
}

function setupPipeline() {
  renderPipeline('nodejs');
  $('#pipeline-seg').addEventListener('click', (e) => { const b = e.target.closest('button'); if (b) renderPipeline(b.dataset.stack); });
  const completion = DATA.templates.core.find((t) => t.path === 'completion.json');
  $('#completion-json').textContent = completion ? completion.content.trim() : '';
}

let tplPlugin = 'core';
let tplFile = null;

function renderTree() {
  const files = DATA.templates[tplPlugin];
  let lastDir = null;
  $('#tpl-tree').innerHTML = files.map((f) => {
    const parts = f.path.split('/');
    const dir = parts.length > 1 ? parts.slice(0, -1).join('/') : '';
    const head = dir !== lastDir && dir ? `<li class="dir">${esc(dir)}/</li>` : '';
    lastDir = dir;
    return `${head}<li><button type="button" data-path="${esc(f.path)}">${esc(parts[parts.length - 1])}</button></li>`;
  }).join('');
  $$('#tpl-seg button').forEach((b) => b.classList.toggle('on', b.dataset.pl === tplPlugin));
}

function openTemplate(path) {
  const f = DATA.templates[tplPlugin].find((x) => x.path === path);
  if (!f) return;
  tplFile = f;
  $$('#tpl-tree button').forEach((b) => { if (b.dataset.path === path) b.setAttribute('aria-current', 'true'); else b.removeAttribute('aria-current'); });
  $('#tpl-name').textContent = f.path;
  $('#tpl-note').textContent = f.note || '';
  $('#tpl-code').textContent = f.content || 'Archivo grande o binario: se omite la vista previa.';
  $('#tpl-copy').hidden = !f.content;
}

function setupTemplates() {
  renderTree();
  $('#tpl-seg').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    tplPlugin = b.dataset.pl;
    renderTree();
    const first = DATA.templates[tplPlugin].find((f) => f.content);
    if (first) openTemplate(first.path);
  });
  $('#tpl-tree').addEventListener('click', (e) => { const b = e.target.closest('button'); if (b) openTemplate(b.dataset.path); });
  $('#tpl-copy').addEventListener('click', () => tplFile && copyText(tplFile.content));
  openTemplate('bossdream.json');
}

let currentFlow = FLOWS[0].id;
let mermaidReady = null;
const diagramCache = new Map();

function loadMermaid() {
  if (mermaidReady) return mermaidReady;
  mermaidReady = new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = MERMAID_URL;
    s.onload = () => resolve(window.mermaid);
    s.onerror = reject;
    document.head.appendChild(s);
  });
  return mermaidReady;
}

function mermaidTheme() {
  const dark = document.documentElement.dataset.theme !== 'light';
  return {
    startOnLoad: false,
    securityLevel: 'strict',
    theme: 'base',
    themeVariables: dark
      ? { background: 'transparent', primaryColor: '#1e1838', primaryTextColor: '#ebe9f7', primaryBorderColor: '#8b5cf6', lineColor: '#a78bfa', secondaryColor: '#14122a', tertiaryColor: '#0f0d1a', fontFamily: 'JetBrains Mono, monospace', fontSize: '13px' }
      : { background: 'transparent', primaryColor: '#ede9fe', primaryTextColor: '#1b1733', primaryBorderColor: '#7c3aed', lineColor: '#7c3aed', secondaryColor: '#f3f1fb', tertiaryColor: '#ffffff', fontFamily: 'JetBrains Mono, monospace', fontSize: '13px' }
  };
}

async function drawDiagram(flow, host) {
  const key = `${flow.id}-${document.documentElement.dataset.theme}`;
  if (diagramCache.has(key)) { host.innerHTML = diagramCache.get(key); return; }
  host.innerHTML = '<span class="loading">Cargando diagrama…</span>';
  try {
    const mermaid = await loadMermaid();
    mermaid.initialize(mermaidTheme());
    const { svg } = await mermaid.render(`mm-${flow.id}-${Date.now()}`, flow.mermaid);
    diagramCache.set(key, svg);
    if (currentFlow === flow.id) host.innerHTML = svg;
  } catch (e) {
    host.innerHTML = '<span class="loading">No se pudo cargar el diagrama (¿sin conexión?). El detalle de abajo sigue disponible.</span>';
  }
}

function flowColumn(cls, title, items) {
  return `<section class="flow-col ${cls}"><h4>${title}</h4><ul>${items.map((i) => `<li>${inline(i)}</li>`).join('')}</ul></section>`;
}

function renderFlow(id) {
  currentFlow = id;
  const flow = FLOWS.find((f) => f.id === id) || FLOWS[0];
  $$('#flow-picker button').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.id === flow.id)));
  $('#flow-view').innerHTML = `<p class="flow-tagline">${inline(flow.tagline)}</p><div class="flow-diagram" id="flow-diagram"></div>
    <div class="flow-cols">${flowColumn('in', 'Entra', flow.entra)}${flowColumn('call', 'Se llama', flow.llama)}${flowColumn('out', 'Sale', flow.sale)}</div>`;
  drawDiagram(flow, $('#flow-diagram'));
}

function setupFlows() {
  $('#flow-picker').innerHTML = FLOWS.map((f) => `<button type="button" class="flow-btn" role="tab" data-id="${f.id}" aria-selected="false">${esc(f.title)}</button>`).join('');
  $('#flow-picker').addEventListener('click', (e) => { const b = e.target.closest('button'); if (b) renderFlow(b.dataset.id); });
}

function setupCopyBlocks() {
  $$('[data-copy]').forEach((block) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'copy-btn';
    btn.textContent = 'Copiar';
    btn.setAttribute('aria-label', 'Copiar al portapapeles');
    btn.addEventListener('click', () => copyText($('code', block).textContent));
    block.appendChild(btn);
  });
}

function setupSpotlight() {
  document.addEventListener('pointermove', (e) => {
    const card = e.target.closest?.('.spot');
    if (!card) return;
    const r = card.getBoundingClientRect();
    card.style.setProperty('--mx', `${e.clientX - r.left}px`);
    card.style.setProperty('--my', `${e.clientY - r.top}px`);
  });
}

function setupTyped() {
  const phrases = [
    'pwsh -File pipeline.ps1 -Tier local   # pipeline OK',
    '/bossdream-plan "exportar facturas a Excel"',
    'command-lock: deny git push --force',
    '/bossdream-implement   # un increment, luego pide permiso',
    'Completion Criteria: pipeline OK · tasks OK · qa-manager ACCEPTED'
  ];
  const el = $('#typed');
  if (REDUCED) { el.textContent = phrases[0]; return; }
  let p = 0, i = 0, del = false;
  const step = () => {
    const full = phrases[p];
    i += del ? -1 : 1;
    el.textContent = full.slice(0, i);
    let wait = del ? 18 : 42;
    if (!del && i === full.length) { del = true; wait = 1800; }
    else if (del && i === 0) { del = false; p = (p + 1) % phrases.length; wait = 400; }
    setTimeout(step, wait);
  };
  step();
}

function setupParallax() {
  const layers = $$('[data-speed]');
  const apply = (y) => layers.forEach((el) => { el.style.transform = `translate3d(0, ${y * Number(el.dataset.speed)}px, 0)`; });
  if (REDUCED) return;
  if (window.Lenis) {
    lenis = new window.Lenis({ lerp: 0.1, smoothWheel: true });
    lenis.on('scroll', ({ scroll }) => apply(scroll));
    const raf = (t) => { lenis.raf(t); requestAnimationFrame(raf); };
    requestAnimationFrame(raf);
  } else {
    addEventListener('scroll', () => apply(scrollY), { passive: true });
  }
}

async function setupParticles() {
  const lib = window.tsParticles;
  if (!lib || REDUCED) return;
  const dark = () => document.documentElement.dataset.theme !== 'light';
  const small = innerWidth < 700;
  try {
    await lib.load({
      id: 'particles',
      options: {
        fpsLimit: 60,
        background: { color: 'transparent' },
        detectRetina: true,
        particles: {
          number: { value: small ? 38 : 80, density: { enable: true } },
          color: { value: dark() ? ['#8b5cf6', '#c4b5fd', '#6d28d9'] : ['#7c3aed', '#5b21b6'] },
          opacity: { value: { min: 0.25, max: 0.7 } },
          size: { value: { min: 1, max: 3.4 }, animation: { enable: true, speed: 2.4, sync: false, startValue: 'random' } },
          links: { enable: true, distance: 130, color: dark() ? '#8b5cf6' : '#7c3aed', opacity: 0.16, width: 1 },
          move: { enable: true, speed: 0.55, outModes: { default: 'out' } }
        },
        interactivity: {
          events: { onHover: { enable: !small, mode: 'grab' }, onClick: { enable: true, mode: 'push' } },
          modes: { grab: { distance: 150, links: { opacity: 0.5 } }, push: { quantity: 3 } }
        }
      }
    });
  } catch (e) {
    $('#particles').remove();
  }
}

function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
  store.set('bd-theme', theme);
  $('meta[name="theme-color"]').content = theme === 'dark' ? '#09080f' : '#f7f6fc';
  if (!$('.panel[data-tab="flujos"]').hidden) renderFlow(currentFlow);
}

function setupTheme() {
  $('#theme-toggle').addEventListener('click', () => {
    applyTheme(document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark');
    window.tsParticles?.domItem(0)?.destroy();
    setupParticles();
  });
}

function paletteEntries() {
  const e = [];
  DATA.commands.forEach((c) => e.push({ kind: 'Comando', tab: 'comandos', id: `comandos-${c.name}`, name: `/${c.name}`, text: c.description }));
  DATA.skills.forEach((c) => e.push({ kind: 'Skill', tab: 'skills', id: `skills-${c.name}`, name: c.name, text: c.description }));
  DATA.agents.forEach((c) => e.push({ kind: 'Agente', tab: 'agentes', id: `agentes-${c.name}`, name: c.name, text: c.description }));
  DATA.mcp.forEach((c) => e.push({ kind: 'MCP', tab: 'mcp', id: `mcp-${c.name}`, name: c.name, text: c.note }));
  FLOWS.forEach((f) => e.push({ kind: 'Flujo', tab: 'flujos', flow: f.id, name: f.title, text: f.tagline }));
  return e;
}

function setupPalette() {
  const root = $('#palette');
  const input = $('#palette-input');
  const list = $('#palette-results');
  const entries = paletteEntries();
  let shown = [];
  let active = 0;

  const paint = () => {
    list.innerHTML = shown.length
      ? shown.map((r, i) => `<li><button type="button" data-i="${i}" aria-selected="${i === active}"><span>${esc(r.name)}</span><small>${r.kind}</small></button></li>`).join('')
      : '<li class="hint-none">Sin resultados.</li>';
  };
  const search = () => {
    const q = input.value.trim();
    if (!q) shown = entries.slice(0, 8);
    else if (fuseCtor) shown = new fuseCtor(entries, { keys: [{ name: 'name', weight: 2 }, 'text'], threshold: 0.35, ignoreLocation: true }).search(q, { limit: 10 }).map((r) => r.item);
    else shown = entries.filter((x) => `${x.name} ${x.text}`.toLowerCase().includes(q.toLowerCase())).slice(0, 10);
    active = 0;
    paint();
  };
  const close = () => { root.hidden = true; };
  const open = () => { root.hidden = false; input.value = ''; search(); input.focus(); };
  const go = (r) => {
    close();
    if (r.flow) currentFlow = r.flow;
    location.hash = r.tab;
    if (!r.id) return;
    setTimeout(() => {
      const el = document.getElementById(r.id);
      if (!el) return;
      el.classList.add('open');
      el.scrollIntoView({ behavior: REDUCED ? 'auto' : 'smooth', block: 'center' });
    }, 120);
  };

  $('#open-search').addEventListener('click', open);
  input.addEventListener('input', search);
  root.addEventListener('click', (e) => { if (e.target === root) close(); const b = e.target.closest('button[data-i]'); if (b) go(shown[Number(b.dataset.i)]); });
  addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); root.hidden ? open() : close(); return; }
    if (root.hidden) return;
    if (e.key === 'Escape') close();
    if (e.key === 'ArrowDown') { e.preventDefault(); active = Math.min(active + 1, shown.length - 1); paint(); }
    if (e.key === 'ArrowUp') { e.preventDefault(); active = Math.max(active - 1, 0); paint(); }
    if (e.key === 'Enter' && shown[active]) go(shown[active]);
  });
}

function setupItemToggle() {
  document.addEventListener('click', (e) => {
    const card = e.target.closest('.item');
    const copy = e.target.closest('[data-copy-sibling]');
    if (copy) { copyText($('code', copy.parentElement).textContent); return; }
    if (card && !e.target.closest('a, .code')) toggleItem(card);
  });
  document.addEventListener('keydown', (e) => {
    const card = e.target.closest?.('.item');
    if (card && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); toggleItem(card); }
  });
}

async function loadFuse() {
  try {
    fuseCtor = (await import(FUSE_URL)).default;
    Object.values(KINDS).forEach((k) => k.repaint?.());
  } catch (e) {
    fuseCtor = null;
  }
}

function init() {
  buildTabs();
  renderStats();
  renderArch();
  Object.keys(KINDS).forEach(setupList);
  renderMcp();
  renderDebt();
  setupPipeline();
  setupTemplates();
  setupFlows();
  setupCopyBlocks();
  setupSpotlight();
  setupTheme();
  setupPalette();
  setupItemToggle();
  setupTyped();
  setupParallax();
  setupParticles();
  addEventListener('hashchange', route);
  route();
  loadFuse();
}

init();
