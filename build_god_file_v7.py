#!/usr/bin/env python3
"""GOD FILE INDEX V7 Builder — advanced search with dates, topics, ecosystems, actions."""
import json, os
from pathlib import Path
from datetime import datetime

INPUT_JSON  = "/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/ecosystem_search_results_v7.json"
OUTPUT_HTML = "/Users/Broyhill/Documents/GitHub/BroyhillGOP/GOD_FILE_INDEX_V7.html"
RELAY_URL   = "http://5.9.99.109:8080"

PRIORITY_TYPES  = {'md','sql','py','docx','xlsx','csv','txt','sh','json','numbers','jsx','ts'}
CATEGORY_PRIORITY = {'BroyhillGOP','Documents','Donors/FEC','Google Drive'}
SKIP_DIRS = {'node_modules','.git','.next','__pycache__','dist','build','.vercel','.cursor','venv'}

ECOSYSTEM_NAMES = {
    "E00":"DataHub/Master DB","E01":"Donor Intelligence","E02":"Donation Processing",
    "E03":"Candidate Profiles","E04":"Activist Network","E05":"Volunteer Mgmt",
    "E06":"Analytics Engine","E07":"Issue Tracking","E08":"Communications Lib",
    "E09":"Content Creation AI","E10":"Compliance Manager","E11":"Budget/Training",
    "E12":"Campaign Operations","E13":"AI Hub","E14":"Print Production",
    "E15":"Contact Directory","E16":"TV/Radio AI","E17":"RVM",
    "E18":"VDP/Print Ads","E19":"Social Media Mgr","E20":"Intelligence Brain",
    "E21":"ML Clustering","E22":"A/B Testing","E23":"Creative/3D Engine",
    "E24":"Candidate Portal","E25":"Donor Portal","E26":"Volunteer Portal",
    "E27":"Realtime Dashboard","E28":"Financial Dashboard","E29":"Analytics Dashboard",
    "E30":"Email Engine","E31":"SMS/MMS","E32":"Phone Banking",
    "E33":"Direct Mail","E34":"Events","E35":"Interactive Comm Hub",
    "E36":"Messenger","E37":"Event Mgmt","E38":"Volunteer Coord",
    "E39":"P2P Fundraising","E40":"Automation Control","E41":"Campaign Builder",
    "E42":"News Intelligence","E43":"Advocacy Tools","E44":"Vendor Compliance",
    "E45":"Video Studio","E46":"Broadcast Hub","E47":"AI Script Generator",
    "E48":"Communication DNA","E49":"Interview System","E50":"GPU Orchestrator",
    "E51":"Nexus Dashboard","E52":"Contact Intelligence","E53":"Document Generation",
    "E54":"Calendar/Scheduling","E55":"API Gateway","E56":"Visitor Deanon",
    "E57":"Messaging Center","E58":"Business Model",
}

def get_category(path_str):
    p = path_str.lower()
    if 'googledrive' in p or ('cloudstorage' in p):
        return 'Google Drive'
    if '/downloads/' in p:
        return 'Downloads'
    if '/documents/' in p:
        return 'Documents'
    if 'broyhillgop' in p or 'cursor' in p:
        return 'BroyhillGOP'
    if 'ncboe' in p or 'donors' in p or 'fec' in p:
        return 'Donors/FEC'
    return 'Other'

def should_keep(r):
    path = r.get('path','')
    ftype = r.get('type','')
    cat = r.get('category','') or get_category(path)
    for part in path.split('/'):
        if part in SKIP_DIRS: return False
    if cat in CATEGORY_PRIORITY:
        return ftype in PRIORITY_TYPES
    if cat == 'Downloads':
        return bool(r.get('topics') or r.get('ecosystems') or r.get('is_session')) and ftype in PRIORITY_TYPES
    return ftype in PRIORITY_TYPES

print("Loading enriched JSON...")
with open(INPUT_JSON) as f:
    data = json.load(f)
fi = data['file_index']
print(f"Total: {len(fi)} → filtering...")

filtered = [r for r in fi if should_keep(r)]
print(f"Filtered: {len(filtered)}")

slim = []
for r in filtered:
    path = r.get('path','')
    cat  = r.get('category','') or get_category(path)
    slim.append({
        'n': r.get('name',''),
        'p': path,
        't': r.get('type',''),
        'c': cat,
        's': r.get('size',0),
        'q': r.get('topics',''),
        'd': r.get('mtime',''),
        'e': r.get('ecosystems',''),
        'x': 1 if r.get('is_session') else 0,
    })

js_data  = json.dumps(slim, separators=(',',':'), ensure_ascii=False)
eco_js   = json.dumps(ECOSYSTEM_NAMES)
generated = datetime.now().strftime('%B %d, %Y %H:%M')
file_count = len(slim)
print(f"Building HTML for {file_count} files...")

HTML_HEAD = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>BroyhillGOP GOD FILE V7</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#0d1117;color:#e6edf3;font-family:'Segoe UI',system-ui,sans-serif;height:100vh;display:flex;flex-direction:column;overflow:hidden}
#topbar{background:#161b22;border-bottom:1px solid #30363d;padding:10px 16px;display:flex;align-items:center;gap:12px;flex-shrink:0;z-index:10}
#topbar h1{font-size:16px;font-weight:700;color:#f0883e;white-space:nowrap}
#topbar .relay-badge{font-size:11px;padding:2px 8px;border-radius:10px;background:#21262d;border:1px solid #30363d;color:#8b949e}
#topbar .relay-badge.ok{border-color:#3fb950;color:#3fb950}
#search-box{flex:1;background:#21262d;border:1px solid #30363d;border-radius:6px;padding:7px 12px;color:#e6edf3;font-size:14px;outline:none}
#search-box:focus{border-color:#388bfd}
#stats-bar{font-size:12px;color:#8b949e;white-space:nowrap}
#main{display:flex;flex:1;overflow:hidden}
#sidebar{width:270px;flex-shrink:0;background:#161b22;border-right:1px solid #30363d;overflow-y:auto;padding:12px}
#results{flex:1;overflow-y:auto;padding:12px}
.filter-section{margin-bottom:16px}
.filter-label{font-size:11px;font-weight:600;text-transform:uppercase;color:#8b949e;letter-spacing:.05em;margin-bottom:6px;display:flex;align-items:center;justify-content:space-between;cursor:pointer}
.filter-label .arrow{transition:transform .2s}
.filter-label.collapsed .arrow{transform:rotate(-90deg)}
.filter-body{display:block}
.filter-body.hidden{display:none}
.pill-row{display:flex;flex-wrap:wrap;gap:4px}
.pill{font-size:11px;padding:3px 8px;border-radius:10px;background:#21262d;border:1px solid #30363d;cursor:pointer;color:#8b949e;transition:all .15s}
.pill:hover,.pill.active{background:#388bfd22;border-color:#388bfd;color:#79c0ff}
.pill.active{font-weight:600}
input[type=date]{background:#21262d;border:1px solid #30363d;color:#e6edf3;padding:4px 8px;border-radius:5px;font-size:12px;width:100%}
.date-row{display:flex;gap:6px;align-items:center;font-size:11px;color:#8b949e}
.eco-grid{display:grid;grid-template-columns:1fr 1fr;gap:3px;max-height:200px;overflow-y:auto}
.eco-chip{font-size:10px;padding:2px 5px;border-radius:4px;background:#21262d;border:1px solid #30363d;cursor:pointer;color:#8b949e;text-align:center;transition:all .15s}
.eco-chip:hover,.eco-chip.active{background:#f0883e22;border-color:#f0883e;color:#f0883e}
.toggle-row{display:flex;flex-direction:column;gap:4px}
.toggle-btn{display:flex;align-items:center;gap:8px;font-size:12px;color:#8b949e;cursor:pointer;padding:4px 6px;border-radius:5px;border:1px solid transparent}
.toggle-btn:hover{background:#21262d;border-color:#30363d}
.toggle-btn.active{color:#3fb950;border-color:#3fb950;background:#3fb95011}
.toggle-btn .dot{width:10px;height:10px;border-radius:50%;background:#30363d;flex-shrink:0}
.toggle-btn.active .dot{background:#3fb950}
.clear-btn{font-size:11px;color:#8b949e;background:none;border:1px solid #30363d;padding:2px 8px;border-radius:5px;cursor:pointer;margin-top:8px;width:100%}
.clear-btn:hover{border-color:#f85149;color:#f85149}
.card{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:12px;margin-bottom:8px;transition:border-color .15s}
.card:hover{border-color:#388bfd44}
.card-header{display:flex;align-items:flex-start;gap:8px;margin-bottom:6px}
.file-name{font-size:13px;font-weight:600;color:#e6edf3;flex:1;word-break:break-all;line-height:1.3}
.type-badge{font-size:10px;padding:1px 6px;border-radius:4px;font-weight:700;flex-shrink:0;font-family:monospace}
.date-badge{font-size:10px;color:#8b949e;flex-shrink:0;padding-top:1px}
.card-meta{display:flex;align-items:center;gap:8px;margin-bottom:6px;flex-wrap:wrap}
.meta-item{font-size:10px;color:#8b949e}
.badge{font-size:9px;padding:1px 5px;border-radius:3px;font-weight:700;text-transform:uppercase;flex-shrink:0}
.badge-session{background:#6e40c911;border:1px solid #6e40c9;color:#a371f7}
.badge-eco{background:#f0883e11;border:1px solid #f0883e;color:#f0883e}
.eco-tags{display:flex;flex-wrap:wrap;gap:3px;margin-bottom:6px}
.eco-tag{font-size:9px;padding:1px 5px;border-radius:3px;background:#f0883e22;border:1px solid #f0883e55;color:#f0883e;cursor:pointer}
.eco-tag:hover{background:#f0883e44}
.topic-tags{display:flex;flex-wrap:wrap;gap:3px;margin-bottom:8px}
.topic-chip{font-size:10px;padding:1px 6px;border-radius:8px;background:#388bfd11;border:1px solid #388bfd44;color:#79c0ff;cursor:pointer}
.topic-chip:hover{background:#388bfd33}
.actions{display:flex;gap:5px;flex-wrap:wrap}
.btn{font-size:10px;padding:3px 9px;border-radius:4px;cursor:pointer;border:1px solid;text-decoration:none;display:inline-block;transition:all .15s;font-weight:500}
.btn-open{background:#21262d;border-color:#30363d;color:#8b949e}
.btn-open:hover{border-color:#3fb950;color:#3fb950}
.btn-reveal{background:#21262d;border-color:#30363d;color:#8b949e}
.btn-reveal:hover{border-color:#f0883e;color:#f0883e}
.btn-copy{background:#21262d;border-color:#30363d;color:#8b949e}
.btn-copy:hover{border-color:#388bfd;color:#79c0ff}
.btn-drive{background:#21262d;border-color:#30363d;color:#8b949e}
.btn-drive:hover{border-color:#34d399;color:#34d399}
.btn.copied{border-color:#3fb950!important;color:#3fb950!important}
#load-more{width:100%;padding:10px;background:#21262d;border:1px solid #30363d;color:#8b949e;border-radius:6px;cursor:pointer;margin-top:8px;font-size:13px}
#load-more:hover{border-color:#388bfd;color:#79c0ff}
.highlight{background:#f0883e44;border-radius:2px}
.no-results{text-align:center;color:#8b949e;padding:60px 20px;font-size:14px}
::-webkit-scrollbar{width:6px;height:6px}
::-webkit-scrollbar-track{background:#0d1117}
::-webkit-scrollbar-thumb{background:#30363d;border-radius:3px}
::-webkit-scrollbar-thumb:hover{background:#388bfd}
</style>
</head>"""

HTML_BODY = """
<body>
<div id="topbar">
  <h1>⚡ BROYHILLGOP GOD FILE V7</h1>
  <span class="relay-badge" id="relay-badge">● RELAY</span>
  <span class="relay-badge" id="bridge-badge" title="Local bridge server (localhost:8181) — enables OPEN/REVEAL/COPY">● BRIDGE</span>
  <input id="search-box" type="text" placeholder="Search files, topics, ecosystems, dates..." autocomplete="off">
  <span id="stats-bar">Loading...</span>
</div>
<div id="main">
  <div id="sidebar">

    <div class="filter-section">
      <div class="filter-label" onclick="toggleSection(this)">
        CATEGORY <span class="arrow">▼</span>
      </div>
      <div class="filter-body">
        <div class="pill-row" id="cat-pills"></div>
      </div>
    </div>

    <div class="filter-section">
      <div class="filter-label" onclick="toggleSection(this)">
        FILE TYPE <span class="arrow">▼</span>
      </div>
      <div class="filter-body">
        <div class="pill-row" id="type-pills"></div>
      </div>
    </div>

    <div class="filter-section">
      <div class="filter-label" onclick="toggleSection(this)">
        DATE RANGE <span class="arrow">▼</span>
      </div>
      <div class="filter-body">
        <div class="date-row">
          <span>From</span>
          <input type="date" id="date-from" onchange="applyFilters()">
        </div>
        <div class="date-row" style="margin-top:5px">
          <span>To&nbsp;&nbsp;&nbsp;</span>
          <input type="date" id="date-to" onchange="applyFilters()">
        </div>
      </div>
    </div>

    <div class="filter-section">
      <div class="filter-label" onclick="toggleSection(this)">
        ECOSYSTEM <span class="arrow">▼</span>
      </div>
      <div class="filter-body">
        <div class="eco-grid" id="eco-grid"></div>
      </div>
    </div>

    <div class="filter-section">
      <div class="filter-label" onclick="toggleSection(this)">
        SMART FILTERS <span class="arrow">▼</span>
      </div>
      <div class="filter-body">
        <div class="toggle-row">
          <div class="toggle-btn" id="toggle-session" onclick="toggleFilter('session')">
            <div class="dot"></div>Session Transcripts Only
          </div>
          <div class="toggle-btn" id="toggle-ecoref" onclick="toggleFilter('ecoref')">
            <div class="dot"></div>Ecosystem Files Only
          </div>
          <div class="toggle-btn" id="toggle-enhancer" onclick="toggleFilter('enhancer')">
            <div class="dot"></div>Ecosystem Enhancers
          </div>
          <div class="toggle-btn" id="toggle-py" onclick="toggleFilter('py')">
            <div class="dot"></div>Python / SQL / Schema
          </div>
        </div>
      </div>
    </div>

    <button class="clear-btn" onclick="clearAllFilters()">✕ Clear All Filters</button>

    <div style="margin-top:16px;font-size:10px;color:#484f58;line-height:1.6">
      Generated: GENERATED_DATE<br>
      TOTAL_COUNT files indexed
    </div>
  </div>

  <div id="results">
    <div id="cards-container"></div>
    <button id="load-more" onclick="loadMore()" style="display:none">Load more results...</button>
    <div class="no-results" id="no-results" style="display:none">
      No files match your filters.<br>
      <span style="font-size:12px">Try clearing some filters or broadening your search.</span>
    </div>
  </div>
</div>
</body>
</html>"""

JS_SCRIPT = r"""<script>
const FILES = DATA_PLACEHOLDER;
const ECO_NAMES = ECO_PLACEHOLDER;

const TYPE_COLORS = {
  md:'#4ade80',sql:'#60a5fa',py:'#f59e0b',sh:'#f59e0b',
  docx:'#818cf8',xlsx:'#34d399',csv:'#34d399',txt:'#94a3b8',
  json:'#fb923c',html:'#f87171',js:'#fde68a',ts:'#67e8f9',
  jsx:'#67e8f9',pdf:'#f87171',numbers:'#34d399',png:'#c084fc'
};

const CAT_COLORS = {
  'BroyhillGOP':'#388bfd','Downloads':'#8b949e','Documents':'#a371f7',
  'Donors/FEC':'#3fb950','Google Drive':'#34d399','Other':'#484f58'
};

let state = {
  search:'', cats:new Set(), types:new Set(),
  dateFrom:'', dateTo:'', ecos:new Set(),
  session:false, ecoref:false, enhancer:false, py:false,
  page:0, pageSize:50
};
let filtered = [];

// ── Build sidebar UI ──────────────────────────────────────────────────────────
function buildSidebar() {
  const cats = [...new Set(FILES.map(f=>f.c))].filter(Boolean).sort();
  const catEl = document.getElementById('cat-pills');
  catEl.innerHTML = makePill('All','all-cat','cat');
  cats.forEach(c => {
    const ct = FILES.filter(f=>f.c===c).length;
    catEl.innerHTML += makePill(`${c} <span style="opacity:.5">${ct}</span>`, c, 'cat');
  });

  const types = [...new Set(FILES.map(f=>f.t))].filter(Boolean).sort();
  const typeEl = document.getElementById('type-pills');
  typeEl.innerHTML = makePill('All','all-type','type');
  types.forEach(t => {
    const ct = FILES.filter(f=>f.t===t).length;
    const col = TYPE_COLORS[t]||'#8b949e';
    typeEl.innerHTML += `<span class="pill" data-filter-type="type" data-val="${t}"
      onclick="togglePill(this,'type')" style="border-color:${col}44;color:${col}"
      >.${t} <span style="opacity:.5">${ct}</span></span>`;
  });
  document.querySelector('[data-val="all-cat"]').classList.add('active');
  document.querySelector('[data-val="all-type"]').classList.add('active');

  const ecoGrid = document.getElementById('eco-grid');
  Object.entries(ECO_NAMES).forEach(([id, name]) => {
    const used = FILES.filter(f=>f.e&&f.e.includes(id)).length;
    ecoGrid.innerHTML += `<div class="eco-chip" data-eco="${id}" title="${id}: ${name}"
      onclick="toggleEco('${id}')">${id}<br><span style="font-size:8px;opacity:.6">${used}</span></div>`;
  });
}

function makePill(label, val, group) {
  return `<span class="pill" data-filter-type="${group}" data-val="${val}"
    onclick="togglePill(this,'${group}')">${label}</span>`;
}

// ── Filter logic ──────────────────────────────────────────────────────────────
function applyFilters() {
  const q = state.search.toLowerCase().trim();
  filtered = FILES.filter(f => {
    if (q) {
      const hay = `${f.n} ${f.q} ${f.e} ${f.c} ${f.t} ${f.d}`.toLowerCase();
      if (!q.split(' ').every(term => hay.includes(term))) return false;
    }
    if (state.cats.size && !state.cats.has(f.c)) return false;
    if (state.types.size && !state.types.has(f.t)) return false;
    if (state.dateFrom && f.d && f.d < state.dateFrom) return false;
    if (state.dateTo && f.d && f.d > state.dateTo) return false;
    if (state.ecos.size) {
      const fileEcos = (f.e||'').split(',').map(s=>s.trim()).filter(Boolean);
      if (!fileEcos.some(e => state.ecos.has(e))) return false;
    }
    if (state.session && !f.x) return false;
    if (state.ecoref && !f.e) return false;
    if (state.enhancer && !f.e) return false;
    if (state.py && !['py','sql','sh'].includes(f.t)) return false;
    return true;
  });
  state.page = 0;
  render();
}

function render() {
  const container = document.getElementById('cards-container');
  const end = (state.page + 1) * state.pageSize;
  const slice = filtered.slice(0, end);
  const q = state.search.toLowerCase().trim();

  if (filtered.length === 0) {
    container.innerHTML = '';
    document.getElementById('no-results').style.display = 'block';
    document.getElementById('load-more').style.display = 'none';
    document.getElementById('stats-bar').textContent = '0 results';
    return;
  }
  document.getElementById('no-results').style.display = 'none';
  container.innerHTML = slice.map(f => renderCard(f, q)).join('');
  document.getElementById('load-more').style.display = end < filtered.length ? 'block' : 'none';
  document.getElementById('stats-bar').textContent =
    `${filtered.length.toLocaleString()} of ${FILES.length.toLocaleString()} files`;
}

function loadMore() { state.page++; render(); }
</script>"""

JS_RENDER = r"""<script>
function renderCard(f, q) {
  const tc = TYPE_COLORS[f.t] || '#8b949e';
  const isGDrive = f.p.toLowerCase().includes('googledrive') || f.p.toLowerCase().includes('cloudstorage');
  const dirPath  = f.p.substring(0, f.p.lastIndexOf('/'));
  const fileUrl  = 'file://' + f.p;
  const dirUrl   = 'file://' + dirPath;

  // Size format
  const sz = f.s > 1048576 ? (f.s/1048576).toFixed(1)+'MB'
           : f.s > 1024    ? (f.s/1024).toFixed(0)+'KB'
           : f.s+'B';

  // Highlight search term in name
  let name = esc(f.n);
  if (q) {
    q.split(' ').filter(Boolean).forEach(term => {
      name = name.replace(new RegExp(escRe(term),'gi'),
        m=>`<span class="highlight">${m}</span>`);
    });
  }

  // Topic chips
  let topicHtml = '';
  if (f.q) {
    const topics = f.q.split(',').slice(0,8);
    topicHtml = `<div class="topic-tags">${
      topics.map(t=>`<span class="topic-chip" onclick="addTopicSearch('${esc(t.trim())}')">${esc(t.trim())}</span>`).join('')
    }</div>`;
  }

  // Ecosystem badges
  let ecoHtml = '';
  if (f.e) {
    const ecos = f.e.split(',').filter(Boolean);
    ecoHtml = `<div class="eco-tags">${
      ecos.map(e=>`<span class="eco-tag" title="${ECO_NAMES[e]||e}" onclick="filterByEco('${e}')">${e}</span>`).join('')
    }</div>`;
  }

  // Session / Ecosystem badges
  let badges = '';
  if (f.x) badges += `<span class="badge badge-session">📋 TRANSCRIPT</span> `;
  if (f.e) badges += `<span class="badge badge-eco">⚡ ECOSYSTEM</span> `;

  // Drive link
  const fname = encodeURIComponent(f.n.replace(/\.[^.]+$/,''));
  const driveHtml = isGDrive
    ? `<a class="btn btn-drive" href="https://drive.google.com/drive/search?q=${fname}" target="_blank">☁ DRIVE</a>`
    : '';

  return `<div class="card" id="card-${esc(f.p.replace(/[^a-z0-9]/gi,'_'))}">
    <div class="card-header">
      <div class="file-name">${name}</div>
      <span class="type-badge" style="background:${tc}22;color:${tc};border:1px solid ${tc}44">.${esc(f.t)}</span>
      ${f.d ? `<span class="date-badge">📅 ${f.d}</span>` : ''}
    </div>
    <div class="card-meta">
      <span class="meta-item">📁 ${esc(f.c)}</span>
      <span class="meta-item">💾 ${sz}</span>
      ${badges}
    </div>
    ${ecoHtml}
    ${topicHtml}
    <div class="actions">
      <span class="btn btn-open" onclick="openFile('${fileUrl}','${esc(f.p)}')" title="Open in default app">▶ OPEN</span>
      <span class="btn btn-reveal" onclick="revealFile('${dirUrl}','${esc(f.p)}')" title="Reveal in Finder">📂 REVEAL</span>
      <span class="btn btn-copy" onclick="copyPath('${esc(f.p)}',this)" title="Copy full path">⎘ COPY</span>
      ${driveHtml}
    </div>
    <div style="font-size:9px;color:#484f58;margin-top:5px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${esc(f.p)}">${esc(f.p)}</div>
  </div>`;
}

function esc(s) { return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
function escRe(s) { return s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'); }

// Bridge server running on Mac localhost:8181
// Handles OPEN, REVEAL, COPY via native Mac commands (open, open -R, pbcopy)
const BRIDGE = 'http://localhost:8181';
let _bridgeOk = null;  // null=unknown, true=live, false=down

async function checkBridge() {
  try {
    const r = await fetch(BRIDGE+'/health', {signal:AbortSignal.timeout(1500)});
    _bridgeOk = r.ok;
  } catch(e) { _bridgeOk = false; }
  return _bridgeOk;
}

async function bridgeCall(endpoint, param, value) {
  if (_bridgeOk === null) await checkBridge();
  if (!_bridgeOk) return false;
  try {
    const r = await fetch(`${BRIDGE}/${endpoint}?${param}=${encodeURIComponent(value)}`,
      {signal:AbortSignal.timeout(3000)});
    return r.ok;
  } catch(e) { return false; }
}

async function copyPath(path, el) {
  const done = () => {
    el.textContent = '✓ COPIED';
    el.classList.add('copied');
    setTimeout(()=>{ el.textContent='⎘ COPY'; el.classList.remove('copied'); }, 2000);
  };
  // Try bridge first (works from any URL)
  const bridged = await bridgeCall('copy','text', path);
  if (bridged) { done(); return; }
  // Fallback: clipboard API (works on file:// and https://)
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(path).then(done).catch(()=>execCopy(path, el, done));
  } else { execCopy(path, el, done); }
}

function execCopy(path, el, done) {
  const ta = document.createElement('textarea');
  ta.value = path;
  ta.style.cssText = 'position:fixed;top:-9999px;opacity:0';
  document.body.appendChild(ta);
  ta.select(); ta.setSelectionRange(0,99999);
  try { document.execCommand('copy'); done(); } catch(e) { prompt('Copy path (⌘C):', path); }
  document.body.removeChild(ta);
}

async function openFile(fileUrl, path) {
  // Try bridge (native open — works in all apps)
  const bridged = await bridgeCall('open','path', path);
  if (bridged) return;
  // Fallback: direct file:// (works when page is served as file://)
  if (location.protocol === 'file:') { window.open(fileUrl,'_blank'); return; }
  // Last resort: show path
  showPathModal('Bridge server offline. Paste this into Finder (⌘⇧G) or Terminal:', path, false);
}

async function revealFile(fileUrl, path) {
  const bridged = await bridgeCall('reveal','path', path);
  if (bridged) return;
  if (location.protocol === 'file:') { window.open(fileUrl,'_blank'); return; }
  showPathModal('Bridge server offline. Paste this into Finder (⌘⇧G) or Terminal:', path, false);
}

function showPathModal(msg, path, autoClose=true) {
  const ex = document.getElementById('path-modal'); if(ex) ex.remove();
  const m = document.createElement('div');
  m.id='path-modal';
  m.style.cssText='position:fixed;top:0;left:0;right:0;bottom:0;background:#000a;z-index:9999;display:flex;align-items:center;justify-content:center';
  m.innerHTML=`<div style="background:#161b22;border:1px solid #388bfd;border-radius:10px;padding:24px;max-width:700px;width:90%;box-shadow:0 8px 32px #000">
    <div style="font-size:12px;color:#8b949e;margin-bottom:10px">${msg}</div>
    <input id="pmi" value="${path.replace(/"/g,'&quot;')}" readonly
      style="width:100%;background:#0d1117;border:1px solid #30363d;color:#e6edf3;padding:8px 12px;border-radius:5px;font-size:12px;font-family:monospace">
    <div style="display:flex;gap:8px;margin-top:12px;align-items:center">
      <span style="flex:1;font-size:10px;color:#484f58">Start bridge: python3 god_file_server.py</span>
      <button onclick="document.getElementById('path-modal').remove()"
        style="background:#21262d;border:1px solid #30363d;color:#8b949e;padding:4px 14px;border-radius:5px;cursor:pointer;font-size:12px">✕</button>
    </div></div>`;
  m.addEventListener('click',e=>{if(e.target===m)m.remove()});
  document.body.appendChild(m);
  const inp=document.getElementById('pmi');
  inp.addEventListener('click',()=>inp.select());
  inp.select();
}

function addTopicSearch(t) {
  const box = document.getElementById('search-box');
  const cur = box.value.trim();
  box.value = cur ? cur+' '+t : t;
  state.search = box.value;
  applyFilters();
}

function filterByEco(ecoId) {
  state.ecos.clear();
  state.ecos.add(ecoId);
  document.querySelectorAll('.eco-chip').forEach(c => {
    c.classList.toggle('active', c.dataset.eco === ecoId);
  });
  applyFilters();
}

// ── Pill / toggle logic ───────────────────────────────────────────────────────
function togglePill(el, group) {
  const val = el.dataset.val;
  if (val.startsWith('all-')) {
    document.querySelectorAll(`[data-filter-type="${group}"]`).forEach(p=>p.classList.remove('active'));
    el.classList.add('active');
    if (group==='cat') state.cats.clear();
    else state.types.clear();
  } else {
    document.querySelector(`[data-val="all-${group}"]`).classList.remove('active');
    el.classList.toggle('active');
    const target = group==='cat' ? state.cats : state.types;
    if (el.classList.contains('active')) target.add(val);
    else target.delete(val);
    if (target.size===0) {
      document.querySelector(`[data-val="all-${group}"]`).classList.add('active');
    }
  }
  applyFilters();
}

function toggleEco(id) {
  const chip = document.querySelector(`[data-eco="${id}"]`);
  if (state.ecos.has(id)) { state.ecos.delete(id); chip.classList.remove('active'); }
  else { state.ecos.add(id); chip.classList.add('active'); }
  applyFilters();
}

function toggleFilter(key) {
  state[key] = !state[key];
  document.getElementById('toggle-'+key).classList.toggle('active', state[key]);
  applyFilters();
}

function toggleSection(label) {
  label.classList.toggle('collapsed');
  const body = label.nextElementSibling;
  body.classList.toggle('hidden');
}

function clearAllFilters() {
  state.search=''; state.cats.clear(); state.types.clear();
  state.dateFrom=''; state.dateTo=''; state.ecos.clear();
  state.session=false; state.ecoref=false; state.enhancer=false; state.py=false;
  document.getElementById('search-box').value='';
  document.getElementById('date-from').value='';
  document.getElementById('date-to').value='';
  document.querySelectorAll('.pill').forEach(p=>p.classList.remove('active'));
  document.querySelectorAll('[data-val="all-cat"],[data-val="all-type"]').forEach(p=>p.classList.add('active'));
  document.querySelectorAll('.eco-chip').forEach(c=>c.classList.remove('active'));
  document.querySelectorAll('.toggle-btn').forEach(b=>b.classList.remove('active'));
  applyFilters();
}

// ── Relay health check ────────────────────────────────────────────────────────
async function checkRelay() {
  try {
    const r = await fetch('RELAY_URL_PLACEHOLDER/health', {signal:AbortSignal.timeout(4000)});
    const b = document.getElementById('relay-badge');
    if (r.ok) { b.textContent='● RELAY ONLINE'; b.classList.add('ok'); }
    else b.textContent='● RELAY ERR';
  } catch(e) { document.getElementById('relay-badge').textContent='● RELAY OFFLINE'; }
}

// ── Init ──────────────────────────────────────────────────────────────────────
document.getElementById('search-box').addEventListener('input', e=>{
  state.search = e.target.value;
  applyFilters();
});
document.getElementById('date-from').addEventListener('change', e=>{
  state.dateFrom = e.target.value; applyFilters();
});
document.getElementById('date-to').addEventListener('change', e=>{
  state.dateTo = e.target.value; applyFilters();
});

buildSidebar();
applyFilters();
async function checkBridgeBadge() {
  const ok = await checkBridge();
  const b = document.getElementById('bridge-badge');
  if (ok) { b.textContent='● BRIDGE ONLINE'; b.classList.add('ok'); }
  else { b.textContent='● BRIDGE OFFLINE'; b.style.color='#f85149'; }
}
checkRelay();
checkBridgeBadge();
setInterval(checkRelay, 30000);
setInterval(checkBridgeBadge, 15000);
</script>"""

# ── Assembly ─────────────────────────────────────────────────────────────────
html = HTML_HEAD
html += HTML_BODY.replace('GENERATED_DATE', generated).replace('TOTAL_COUNT', str(file_count))

# Inject data into JS (split to avoid Python/JS confusion)
script1 = JS_SCRIPT.replace('DATA_PLACEHOLDER', js_data).replace('ECO_PLACEHOLDER', eco_js)
script2 = JS_RENDER.replace('RELAY_URL_PLACEHOLDER', RELAY_URL)

# Close body tag needs scripts before it
html = html.replace('</body>', f'{script1}\n{script2}\n</body>')

with open(OUTPUT_HTML, 'w', encoding='utf-8') as fout:
    fout.write(html)

size_kb = os.path.getsize(OUTPUT_HTML) / 1024
print(f"✅ Written: {OUTPUT_HTML}")
print(f"   Size: {size_kb:.0f} KB | Files: {file_count}")
