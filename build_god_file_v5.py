#!/usr/bin/env python3
"""Build GOD_FILE_INDEX_V5.html — complete searchable index with topic tagging."""
import os, json, re
from datetime import datetime

SCAN_DIRS = [
    "/Users/Broyhill/Desktop/BroyhillGOP-CURSOR",
    "/Users/Broyhill/Desktop/NCBOE-FEC- DONORS 2015-2026",
]
SKIP_DIRS = {'.git','node_modules','.vercel','.cursor','__pycache__','.next','.DS_Store','.npm-global'}
EXTENSIONS = {'md','py','sql','html','docx','pdf','csv','xlsx','xls','json','numbers','sh','txt','jsx','tsx','js','ts','css','pptx','log','yml','yaml','toml','cjs','mjs','svg','aiff','mp4','zip'}

TOPIC_TAGS = {
    'donor':['donor','donation','contribut','giving','fundrais','winred'],
    'fec':['fec','federal_election','fec_god'],
    'ncboe':['ncboe','nc_boe','board_of_election','general_fund'],
    'spine':['spine','person_spine','identity_resolution','dedup','golden_record','merge'],
    'datatrust':['datatrust','data_trust','voter_file','rnc_data','voter_rncid'],
    'matching':['match','tier_1','tier_2','tier_3','name_variant'],
    'ecosystem':['ecosystem'],
    'migration':['migration','migrate'],
    'brain':['brain','nexus','intelligence','e20','neural','ai_hub'],
    'compliance':['compliance','fec_report','filing','disclosure','audit'],
    'voice':['voice','synthesis','ultra','xtts','replicate','tts','clone'],
    'campaign':['campaign','gotv','canvass','field_op','precinct','turf'],
    'email':['email','smtp','deliverability','drip','newsletter'],
    'sms':['sms','texting','messaging','dropcowboy','bandwidth'],
    'analytics':['analytics','dashboard','kpi','metric','visualiz','chart'],
    'candidate':['candidate','race','committee','filing_deadline','ballot'],
    'volunteer':['volunteer','shift','recruit','mobiliz'],
    'legal':['legal','ncrdc','formation','safe_harbor','llc','agreement'],
    'api':['api','gateway','endpoint','webhook'],
    'gpu':['gpu','runpod','cuda','orchestrat','serverless'],
    'video':['video','studio','ffmpeg','thumbnail','broadcast','stream'],
    'pipeline':['pipeline','ingest','etl','loader','import','seed','normaliz'],
    'scoring':['score','scoring','grade','grading','percentile','rank','propensity'],
    'schema':['schema','ddl','table_create','alter_table'],
}

def get_cat(path, name):
    p = path.lower()
    if '/ecosystem_reports/' in p or '/aaa ecosystem_reports/' in p: return 'ECOSYSTEM_REPORTS'
    if '/database/migrations/' in p: return 'MIGRATIONS'
    if '/backend/python/ecosystems/' in p: return 'ECO_CODE'
    if '/backend/python/integrations/' in p: return 'INTEGRATIONS'
    if '/backend/python/engines/' in p: return 'ENGINES'
    if '/backend/python/' in p: return 'BACKEND'
    if '/pipeline/' in p: return 'PIPELINE'
    if '/scripts/' in p: return 'SCRIPTS'
    if '/docs/' in p: return 'DOCS'
    if '/scrapers/' in p: return 'SCRAPERS'
    if '/frontend/' in p: return 'FRONTEND'
    if '/core/' in p: return 'CORE'
    if '/ecosystems/' in p: return 'ECO_CODE_ROOT'
    if '/runpod/' in p: return 'RUNPOD'
    if '/sql/' in p: return 'SQL'
    if 'ncboe-fec' in p: return 'RAW_DATA'
    if name.lower().startswith('session-state'): return 'SESSION'
    return 'ROOT'

def get_topics(name, path):
    tags = set()
    combo = (name + ' ' + path).lower().replace('-','_').replace(' ','_')
    for topic, kws in TOPIC_TAGS.items():
        for kw in kws:
            if kw in combo:
                tags.add(topic)
                break
    return sorted(tags)

def get_src(path):
    if 'NCBOE-FEC' in path: return 'NCBOE-FEC'
    return 'BroyhillGOP'

def scan():
    files = []
    seen = set()
    for base in SCAN_DIRS:
        for root, dirs, fnames in os.walk(base):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for fn in fnames:
                if fn.startswith('.') or fn.startswith('~$'): continue
                ext = fn.rsplit('.',1)[-1].lower() if '.' in fn else ''
                if ext not in EXTENSIONS: continue
                fp = os.path.join(root, fn)
                key = fn.lower()
                if key in seen: continue
                seen.add(key)
                try:
                    st = os.stat(fp)
                    files.append({'n':fn,'ext':ext,'s':st.st_size,'mt':st.st_mtime,
                        'path':fp,'cat':get_cat(fp,fn),'src':get_src(fp),
                        'topics':get_topics(fn,fp)})
                except: pass
    return files

CAT_NAMES = {
    'ECOSYSTEM_REPORTS':'Ecosystem Reports (48 DOCX)','MIGRATIONS':'SQL Migrations',
    'ECO_CODE':'Ecosystem Backend Code','ECO_CODE_ROOT':'Ecosystem Code (Root)',
    'INTEGRATIONS':'Integration Layer','ENGINES':'AI/ML Engines',
    'BACKEND':'Backend (API/Control/Voice)','PIPELINE':'Data Pipeline',
    'SCRIPTS':'Operational Scripts','DOCS':'Documentation','SCRAPERS':'Scrapers',
    'FRONTEND':'Frontend UI','CORE':'Core Modules','RUNPOD':'RunPod GPU',
    'SQL':'SQL Misc','RAW_DATA':'Raw Data Files','SESSION':'Session State',
    'ROOT':'Project Root'
}
CAT_ORDER = ['ECOSYSTEM_REPORTS','MIGRATIONS','ECO_CODE','INTEGRATIONS','ENGINES','BACKEND',
    'PIPELINE','SCRIPTS','DOCS','ECO_CODE_ROOT','FRONTEND','CORE','SCRAPERS','RUNPOD',
    'SQL','RAW_DATA','SESSION','ROOT']

GDRIVE = [
    # === GOD FILE Root ===
    ("https://drive.google.com/drive/folders/1pI7jhCG2UwqncKHonObAlli1uJ5xLc4R","GOD FILE (Root)","Master folder — all project docs"),
    ("https://drive.google.com/drive/folders/16npbVLW33XtuGkLeyq4GTt9ccfJ5bEyA","MD FILES","Treasure trove — organized MD docs"),
    # === Organized-MD (18 topic folders) ===
    ("https://drive.google.com/drive/folders/1HoQ_bVPym-deQyp5CXmLcJnRwuS9Pe3w","Organized-MD","18 topic folders"),
    ("https://drive.google.com/drive/folders/1vrJ--uPZc8HwyFIlq4B40lzVZd4yWr9a","  Ecosystems","E01-E58 ecosystem docs"),
    ("https://drive.google.com/drive/folders/1pTgQ7gMqDPSY24sU1YOWyeiIDGRIt2hs","  Database","Schemas, migrations, DataTrust"),
    ("https://drive.google.com/drive/folders/1YHIR6lUa3XpRZveZcBYBB16nfG8etRdq","  Donors","Donor data, contact files, analysis"),
    ("https://drive.google.com/drive/folders/1rBL6oQtdFVDdTHY1ZXVanhQHQBdr5EYq","  Candidates","Candidate profiles, races, districts"),
    ("https://drive.google.com/drive/folders/1M9GOlZsKj86NOteZfMFI_4iTG27NIfjd","  AI-ML","Brain, NEXUS, intelligence, ML models"),
    ("https://drive.google.com/drive/folders/1L_HY6aoMwKrEvGJg6ccKcsW8c0E0zGUL","  Platform-Architecture","System design, architecture diagrams"),
    ("https://drive.google.com/drive/folders/1BqIXeSQ4yNrwjBGK5AOhKJi7z2DqMe2d","  Legal-Compliance","Agreements, licenses, MOUs"),
    ("https://drive.google.com/drive/folders/1kGXwmnQ7oBogq1FgPA5eNw-vN-IzNTUL","  Communications","Email, SMS, messaging templates"),
    ("https://drive.google.com/drive/folders/1mEcSuCa1EdIa4tuS_xrTcj441hjg6XqY","  Strategy","Political strategy, fundraising, outreach"),
    ("https://drive.google.com/drive/folders/1dkGnmWZl4CHSO6Wf1umEltwHRi3xfbTE","  Data-Analytics","Analytics, reports, data pipelines"),
    ("https://drive.google.com/drive/folders/1IutkGOOAkuaiY9x7B3mrrzOxI7pSeZRB","  NCGOP","Party org, affiliates, clubs"),
    ("https://drive.google.com/drive/folders/1p3p7rNfiQNKVOUO8rrpJQnUu83csOhTt","  Frontend-UI","UI wireframes, dashboards, portals"),
    ("https://drive.google.com/drive/folders/1AirrvlZ7SuUaxVDTgx54yNhWjZBGOeKF","  Deployment-Setup","Hosting, deploy scripts"),
    ("https://drive.google.com/drive/folders/1mbglUTlRjVzSGm6mFrvarKVN45Y4xk2f","  Session-Transcripts","Claude/ChatGPT session logs"),
    ("https://drive.google.com/drive/folders/1aSm3xxaJFEiCgIwsdkWYu8YFAqFZ3I74","  Microsegmentation","Donor microsegmentation docs"),
    ("https://drive.google.com/drive/folders/1xRFmxtrK80jJZuDBUmebrhhKudmA3UoF","  General","General project docs"),
    ("https://drive.google.com/drive/folders/1kPbMTQ93wS5MJBQILm71nGTO-tW4TR94","  README-Index","README and index files"),
    ("https://drive.google.com/drive/folders/11ilPx2NMV223X83diUsupoJUH8qxuYAQ","  Credentials-Sensitive","Sensitive credential docs"),
    # === Other GOD FILE folders ===
    ("https://drive.google.com/drive/folders/1CfEz-DijPT5HKeoVz7prUYqQyHoqEekS","NCRDC Legal Suite","Formation documents, legal suite"),
    ("https://drive.google.com/drive/folders/1t9ZPYmTnJ_QgiYt9pCEGigvBC_bS7yP8","NC BOE Data Uploads","NCBOE bulk data exports"),
    ("https://drive.google.com/drive/folders/1Nw6ilZm4DdShnPVPKoooWCPLdvVAOtdp","BroyhillGOP-main","Laravel codebase"),
    ("https://drive.google.com/drive/folders/1bApr3FDHJPfEuockSFjDaEgBQJUrSKKA","NEXUS Google DOCS","NEXUS system, CURSOR docs"),
    ("https://drive.google.com/drive/folders/1Gi8dkx0knipBsnevV_-bJiyT-SpNtvKp","Claude 4.6 Private","Claude session outputs"),
    ("https://drive.google.com/drive/folders/1HhCbejR80qvXWWFGfb4A5Mk-YUbRDsT9","AAA ChatGPT GOD","ChatGPT sessions and outputs"),
    ("https://drive.google.com/drive/folders/149ToZRdEYJ8BF1pYmFSRAGEuA4YPfUSm","AAA CLAUDE CHARGER","Claude charging documents"),
    ("https://drive.google.com/drive/folders/1fzL-Du1qRGFLwITO4Wcd6n0j6OGBt2zw","AAA EDDIE BEAR","Personal project files"),
    ("https://drive.google.com/drive/folders/1o1usCXmOdpRd0-jLoOH-U2lzBet5g5BE","SESSION-TRANSCRIPTS","All session transcripts"),
    ("https://drive.google.com/drive/folders/1LRugUGUDITh1kCjhk9nQPQ0hDKmy-DQK","DAILY-REPORTS","Daily progress reports"),
    ("https://drive.google.com/drive/folders/1yW6vda_ljlScXmNr_ChiHui8kK_0Qmvf","SQL Chunks","SQL migration chunks"),
    ("https://drive.google.com/drive/folders/19Senn2EGWDJ_ro0K0GlsvES77FKXtdy9","BroyhillGOP-NCGOP-Data-Committee","NCGOP data committee files"),
]

def build(files):
    now = datetime.now().strftime('%B %d, %Y at %I:%M %p')
    fj = json.dumps(files, separators=(',',':'))
    cnj = json.dumps(CAT_NAMES, separators=(',',':'))
    coj = json.dumps(CAT_ORDER, separators=(',',':'))
    total = len(files)
    ec = {}
    tc = {}
    for f in files:
        ec[f['ext']] = ec.get(f['ext'],0)+1
        for t in f['topics']:
            tc[t] = tc.get(t,0)+1
    top_ext = sorted(ec.items(), key=lambda x:-x[1])[:10]
    top_topics = sorted(tc.items(), key=lambda x:-x[1])

    gdrive_html = ''.join(f'<div class="gc"><a href="{u}" target="_blank">{n}</a><div class="gd">{d}</div></div>' for u,n,d in GDRIVE)
    topic_btns = ''.join(f'<span class="tbtn" data-t="{t}">{t} ({c})</span>' for t,c in top_topics)

    return f'''<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>GOD FILE v5 — BroyhillGOP Master Index</title>
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&family=DM+Sans:wght@400;500;700&display=swap" rel="stylesheet">
<style>
:root{{--bg:#0d1117;--s:#161b22;--s2:#21262d;--b:#30363d;--t:#e6edf3;--t2:#8b949e;--a:#58a6ff;--a2:#bc8cff;--g:#3fb950;--o:#d29922;--r:#f85149;--c:#39d2c0}}
*{{margin:0;padding:0;box-sizing:border-box}}body{{font-family:'DM Sans',sans-serif;background:var(--bg);color:var(--t);min-height:100vh}}a{{color:inherit;text-decoration:none}}
.hdr{{background:linear-gradient(135deg,#0d1117,#161b22 50%,#1a2332);border-bottom:1px solid var(--b);padding:28px 32px}}
.hdr h1{{font-family:'JetBrains Mono',monospace;font-size:28px;color:var(--a);text-shadow:0 0 20px rgba(88,166,255,.3)}}
.hdr .sub{{color:var(--t2);font-size:13px;margin-top:6px}}
.tag{{display:inline-block;padding:2px 8px;border-radius:10px;font-size:10px;font-weight:700;margin-left:4px}}
.tag.loc{{background:#1f3a1f;color:var(--g)}}.tag.gd{{background:#2a1f3a;color:var(--a2)}}.tag.gh{{background:#1a2a3f;color:var(--a)}}
.sbar{{display:flex;gap:10px;margin-top:16px;flex-wrap:wrap}}
.st{{background:var(--s);border:1px solid var(--b);border-radius:8px;padding:8px 14px}}
.st .n{{font-family:'JetBrains Mono',monospace;font-size:20px;font-weight:700;color:var(--a)}}.st .l{{font-size:9px;color:var(--t2);text-transform:uppercase;letter-spacing:.5px;margin-top:2px}}
.gdr{{padding:12px 32px;background:var(--s);border-bottom:1px solid var(--b)}}
.gdr h3{{font-family:'JetBrains Mono',monospace;font-size:13px;color:var(--a2);cursor:pointer}}.gdr h3:hover{{color:var(--a)}}
.gg{{display:none;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:6px;margin-top:8px}}.gg.open{{display:grid}}
.gc{{background:var(--s2);border:1px solid var(--b);border-radius:6px;padding:6px 10px}}.gc:hover{{border-color:var(--a2)}}
.gc a{{color:var(--a2);font-size:12px;font-weight:700}}.gd{{color:var(--t2);font-size:10px;margin-top:2px}}
.ctl{{padding:10px 32px;display:flex;gap:10px;flex-wrap:wrap;align-items:center;position:sticky;top:0;z-index:100;background:var(--bg);border-bottom:1px solid var(--b)}}
.sb{{flex:1;min-width:280px;position:relative}}.sb input{{width:100%;padding:10px 16px 10px 38px;background:var(--s);border:1px solid var(--b);border-radius:8px;color:var(--t);font-size:14px;outline:none;font-family:'DM Sans',sans-serif}}.sb input:focus{{border-color:var(--a)}}.sb::before{{content:'\\2315';position:absolute;left:14px;top:50%;transform:translateY(-50%);color:var(--t2);font-size:16px}}
.btn{{padding:7px 12px;background:var(--s);border:1px solid var(--b);border-radius:8px;color:var(--t2);font-size:12px;cursor:pointer;font-family:'DM Sans',sans-serif}}.btn:hover,.btn.on{{background:var(--a);color:#000;border-color:var(--a);font-weight:700}}
.trow{{padding:6px 32px;display:flex;gap:4px;flex-wrap:wrap}}
.tbtn{{padding:3px 8px;background:var(--s);border:1px solid var(--b);border-radius:12px;color:var(--t2);font-size:10px;cursor:pointer;font-family:'JetBrains Mono',monospace}}.tbtn:hover,.tbtn.on{{background:var(--a2);color:#fff;border-color:var(--a2)}}
.frow{{padding:4px 32px;display:flex;gap:4px;flex-wrap:wrap}}
.fbtn{{padding:3px 8px;background:var(--s);border:1px solid var(--b);border-radius:12px;color:var(--t2);font-size:10px;cursor:pointer;font-family:'JetBrains Mono',monospace}}.fbtn:hover,.fbtn.on{{background:var(--c);color:#000;border-color:var(--c)}}
.res{{padding:6px 32px;color:var(--t2);font-size:11px;font-family:'JetBrains Mono',monospace}}
.main{{padding:0 32px 60px}}
.cs{{margin-top:12px}}
.ch{{display:flex;align-items:center;gap:10px;padding:8px 14px;background:var(--s);border:1px solid var(--b);border-radius:8px;cursor:pointer;user-select:none}}.ch:hover{{background:var(--s2)}}
.ch .ci{{font-family:'JetBrains Mono',monospace;font-size:12px;font-weight:700;color:var(--a);min-width:90px}}.ch .cn{{font-size:13px;font-weight:700;flex:1}}.ch .cc{{font-family:'JetBrains Mono',monospace;font-size:11px;color:var(--t2);background:var(--s2);padding:2px 8px;border-radius:10px}}.ch .ar{{color:var(--t2);font-size:12px;transition:transform .2s}}.ch.open .ar{{transform:rotate(90deg)}}
.cf{{display:none;padding:4px 0 4px 14px;border-left:2px solid var(--b);margin-left:45px;margin-top:4px}}.cf.open{{display:block}}
.fr{{display:grid;grid-template-columns:22px 1fr 70px 44px 130px 90px 44px;gap:4px;align-items:center;padding:4px 8px;border-radius:4px;font-size:11px}}.fr:hover{{background:var(--s)}}
.fr .ic{{font-size:13px;text-align:center}}.fr .fn a{{color:var(--a);border-bottom:1px dotted transparent}}.fr .fn a:hover{{color:var(--g);border-bottom-color:var(--g)}}
.fr .fs{{font-family:'JetBrains Mono',monospace;font-size:10px;color:var(--t2);text-align:right}}
.badge{{display:inline-block;padding:1px 6px;border-radius:6px;font-size:9px;font-weight:700;text-transform:uppercase}}
.badge.py{{background:#1e3a5f;color:#58a6ff}}.badge.sql{{background:#2a1f3a;color:#bc8cff}}.badge.md{{background:#1f3a1f;color:#3fb950}}.badge.html{{background:#3a1f1f;color:#f85149}}.badge.docx{{background:#1e3a5f;color:#58a6ff}}.badge.csv{{background:#2a3a1f;color:#d29922}}.badge.xlsx{{background:#1f3a2a;color:#39d2c0}}.badge.json{{background:#1f3a3a;color:#39d2c0}}.badge.numbers{{background:#3a2a1f;color:#d29922}}.badge.pdf{{background:#3a1f2a;color:#f778ba}}.badge.js{{background:#3a3a1f;color:#d29922}}.badge.sh{{background:#1f3a1f;color:#3fb950}}
.fr .tp{{font-size:9px;color:var(--a2);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}}
.fr .cp{{padding:2px 6px;background:#1f3a1f;border:1px solid #2a4a2a;border-radius:4px;color:var(--g);font-size:8px;cursor:pointer;font-family:'JetBrains Mono',monospace;text-align:center}}.fr .cp:hover{{background:var(--g);color:#000}}
.toast{{position:fixed;bottom:20px;right:20px;background:var(--g);color:#000;padding:12px 20px;border-radius:8px;font-size:13px;font-weight:700;display:none;z-index:1000}}
.db-panel{{margin:16px 32px;padding:16px;background:var(--s);border:1px solid var(--b);border-radius:10px}}
.db-panel h3{{font-family:'JetBrains Mono',monospace;font-size:14px;color:var(--c);margin-bottom:8px}}
.db-row{{display:grid;grid-template-columns:1fr 120px 1fr;gap:8px;font-size:12px;padding:4px 0;border-bottom:1px solid var(--b)}}.db-row:last-child{{border:none}}
.db-row .v{{font-family:'JetBrains Mono',monospace;color:var(--a);text-align:right}}
@media(max-width:768px){{.fr{{grid-template-columns:18px 1fr 50px 36px}}.fr .tp,.fr .cp{{display:none}}}}
</style></head><body>
<div class="hdr">
<h1>GOD FILE v5 — BroyhillGOP Master Index</h1>
<div class="sub">Updated {now} <span class="tag loc">Local</span> <span class="tag gd">Google Drive</span> <span class="tag gh">GitHub</span> &bull; {total:,} files &bull; Fundraising Microsegmentation Platform &bull; 57 Campaign Ecosystems</div>
<div class="sub" style="margin-top:4px;color:var(--g);font-size:11px">Search by filename, topic tag, file type, or keyword. Click COPY for file path. GitHub: github.com/broyhill/BroyhillGOP</div>
<div class="sbar" id="stats"></div>
</div>

<div class="gdr"><h3 onclick="document.getElementById('gg').classList.toggle('open')">&#9729; Google Drive Folders (click to expand)</h3>
<div class="gg" id="gg">{gdrive_html}</div></div>

<div class="db-panel">
<h3>Database State — March 17, 2026</h3>
<div class="db-row"><span>core.person_spine</span><span class="v">298,159</span><span style="color:var(--t2)">active master records</span></div>
<div class="db-row"><span>FEC &rarr; Spine matched</span><span class="v">2,247,173</span><span style="color:var(--t2)">86.5% (3-tier matching)</span></div>
<div class="db-row"><span>Party &rarr; Spine matched</span><span class="v">1,264,467</span><span style="color:var(--t2)">72.9% linked</span></div>
<div class="db-row"><span>core.contribution_map</span><span class="v">3,109,705</span><span style="color:var(--t2)">FEC + Party + NC BOE</span></div>
<div class="db-row"><span>Linked donation $</span><span class="v">$217.7M</span><span style="color:var(--t2)">total matched amount</span></div>
</div>

<div class="ctl">
<div class="sb"><input type="text" id="search" placeholder="Search {total:,} files... donor, schema, brain, fec, matching, ecosystem" autocomplete="off"></div>
<button class="btn" onclick="toggleAll(true)">Expand All</button>
<button class="btn" onclick="toggleAll(false)">Collapse</button>
<select class="btn" id="srcF" onchange="render()" style="min-width:100px"><option value="">All Sources</option><option value="BroyhillGOP">BroyhillGOP</option><option value="NCBOE-FEC">NCBOE-FEC</option></select>
</div>
<div class="trow" id="topicFilters">{topic_btns}</div>
<div class="frow" id="typeFilters"></div>
<div class="res" id="results"></div>
<div class="main" id="main"></div>
<div class="toast" id="toast">Copied!</div>

<script>
const F={fj};
const CATS={cnj};
const PRIORITY={coj};
let activeType='';
let activeTopic='';

const icons={{py:'&#128013;',sql:'&#128451;',md:'&#128196;',html:'&#127760;',docx:'&#128196;',pdf:'&#128213;',csv:'&#128202;',xlsx:'&#128202;',json:'&#128204;',numbers:'&#128202;',sh:'&#9881;',js:'&#9889;',ts:'&#9889;',jsx:'&#9883;',txt:'&#128196;',log:'&#128196;',svg:'&#127912;',zip:'&#128230;',css:'&#127912;'}};

function fmtSize(b){{if(b<1024)return b+'B';if(b<1048576)return(b/1024).toFixed(1)+'K';return(b/1048576).toFixed(1)+'M'}}
function esc(s){{return s.replace(/'/g,"\\\\'")}}
function copyPath(p){{navigator.clipboard.writeText(p);const t=document.getElementById('toast');t.style.display='block';setTimeout(()=>t.style.display='none',1200)}}
function toggleAll(open){{document.querySelectorAll('.ch').forEach(h=>{{if(open){{h.classList.add('open');h.nextElementSibling.classList.add('open')}}else{{h.classList.remove('open');h.nextElementSibling.classList.remove('open')}}}})}}
function setType(t){{activeType=activeType===t?'':t;render()}}
function setTopic(t){{activeTopic=activeTopic===t?'':t;render()}}

document.querySelectorAll('.tbtn').forEach(b=>b.addEventListener('click',function(){{setTopic(this.dataset.t)}}));

function render(){{
  const rawQ=document.getElementById('search').value;
  const srcF=document.getElementById('srcF').value;
  const terms=rawQ.toLowerCase().split(/\\s+/).filter(Boolean);
  let filtered=F.slice();
  if(srcF)filtered=filtered.filter(f=>f.src===srcF);
  if(activeType)filtered=filtered.filter(f=>f.ext===activeType);
  if(activeTopic)filtered=filtered.filter(f=>f.topics&&f.topics.includes(activeTopic));
  if(terms.length){{
    filtered=filtered.filter(f=>{{
      const hay=(f.n+' '+f.cat+' '+f.ext+' '+(f.topics||[]).join(' ')+' '+f.path).toLowerCase();
      return terms.every(t=>hay.includes(t));
    }});
    filtered.forEach(f=>{{
      const hay=(f.n+' '+f.cat+' '+f.ext+' '+(f.topics||[]).join(' ')).toLowerCase();
      f._score=terms.reduce((s,t)=>s+(f.n.toLowerCase().includes(t)?10:0)+(f.cat.toLowerCase().includes(t)?5:0)+((f.topics||[]).some(tp=>tp.includes(t))?3:0),0);
    }});
    filtered.sort((a,b)=>b._score-a._score);
  }}
  const groups={{}};filtered.forEach(f=>{{if(!groups[f.cat])groups[f.cat]=[];groups[f.cat].push(f)}});
  const main=document.getElementById('main');main.innerHTML='';
  const catOrder=Object.keys(groups).sort((a,b)=>{{const ia=PRIORITY.indexOf(a),ib=PRIORITY.indexOf(b);if(ia>=0&&ib>=0)return ia-ib;if(ia>=0)return-1;if(ib>=0)return 1;return a.localeCompare(b)}});
  catOrder.forEach(cat=>{{
    const items=groups[cat];const sec=document.createElement('div');sec.className='cs';
    const isOpen=terms.length>0||activeTopic?' open':'';
    sec.innerHTML=`<div class="ch${{isOpen}}" onclick="this.classList.toggle('open');this.nextElementSibling.classList.toggle('open')"><span class="ci">${{cat}}</span><span class="cn">${{CATS[cat]||cat}}</span><span class="cc">${{items.length}}</span><span class="ar">&#9654;</span></div><div class="cf${{isOpen}}">${{items.map(f=>`<div class="fr"><span class="ic">${{icons[f.ext]||'&#128193;'}}</span><span class="fn"><a href="file://${{f.path}}" title="${{f.path}}">${{f.n}}</a></span><span class="fs">${{fmtSize(f.s)}}</span><span class="badge ${{f.ext}}">${{f.ext}}</span><span class="tp">${{(f.topics||[]).join(', ')}}</span><span class="tp" style="color:var(--t2)">${{f.src}}</span><span class="cp" onclick="copyPath('${{esc(f.path)}}')">COPY</span></div>`).join('')}}</div>`;
    main.appendChild(sec);
  }});
  document.getElementById('results').textContent=filtered.length+' files in '+catOrder.length+' categories'+(terms.length?' (search: '+rawQ+')':'')+(activeTopic?' [topic: '+activeTopic+']':'')+(activeType?' [type: .'+activeType+']':'');
  const stats=document.getElementById('stats');const tc={{}};filtered.forEach(f=>tc[f.ext]=(tc[f.ext]||0)+1);
  stats.innerHTML=`<div class="st"><div class="n">${{filtered.length}}</div><div class="l">Files</div></div><div class="st"><div class="n">${{catOrder.length}}</div><div class="l">Categories</div></div>`+Object.entries(tc).sort((a,b)=>b[1]-a[1]).slice(0,8).map(([t,c])=>`<div class="st"><div class="n">${{c}}</div><div class="l">.${{t}}</div></div>`).join('');
  const tf=document.getElementById('typeFilters');tf.innerHTML=Object.entries(tc).sort((a,b)=>b[1]-a[1]).map(([t,c])=>`<span class="fbtn ${{activeType===t?'on':''}}" onclick="setType('${{t}}')">.${t} (${{c}})</span>`).join('');
  document.querySelectorAll('.tbtn').forEach(b=>{{if(b.dataset.t===activeTopic)b.classList.add('on');else b.classList.remove('on')}});
}}
document.getElementById('search').addEventListener('input',render);
render();
</script></body></html>'''

if __name__ == '__main__':
    files = scan()
    html = build(files)
    out = '/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/docs/GOD_FILE_INDEX_V5.html'
    with open(out, 'w') as f:
        f.write(html)
    print(f"V5 built: {len(files)} files indexed -> {out}")
    # Also copy to NCBOE folder
    out2 = '/Users/Broyhill/Desktop/NCBOE-FEC- DONORS 2015-2026/GOD_FILE_INDEX_V5.html'
    with open(out2, 'w') as f:
        f.write(html)
    print(f"Copy saved: {out2}")
