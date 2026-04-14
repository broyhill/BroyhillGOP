#!/usr/bin/env python3
"""
Enrich ecosystem_search_results.json with mtime + ctime + ecosystem refs.
Fast pass — reads file stats + regex on path/name, no content re-scan.
Outputs enriched JSON ready for GOD FILE V7.

v3 Changes:
- Captures both mtime (modified) and birthtime (created) per file
- Infers missing dates from sibling files in same folder
  (e.g. if a .sql has no date but a .py from same folder does, use that date)
"""
import json, os, re
from datetime import datetime
from pathlib import Path
from collections import defaultdict

INPUT  = "/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/ecosystem_search_results.json"
OUTPUT = "/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/ecosystem_search_results_v7.json"

ECOSYSTEM_NAMES = {
    "E00":"DataHub/Master DB","E01":"Donor Intelligence","E02":"Donation Processing",
    "E03":"Candidate Profiles","E04":"Activist Network","E05":"Volunteer Mgmt",
    "E06":"Analytics Engine","E07":"Issue Tracking","E08":"Communications Library",
    "E09":"Content Creation AI","E10":"Compliance Manager","E11":"Budget/Training LMS",
    "E12":"Campaign Operations","E13":"AI Hub","E14":"Print Production",
    "E15":"Contact Directory","E16":"TV/Radio AI","E17":"RVM",
    "E18":"VDP/Print Advertising","E19":"Social Media Manager","E20":"Intelligence Brain",
    "E21":"ML Clustering","E22":"A/B Testing","E23":"Creative/3D Engine",
    "E24":"Candidate Portal","E25":"Donor Portal","E26":"Volunteer Portal",
    "E27":"Realtime Dashboard","E28":"Financial Dashboard","E29":"Analytics Dashboard",
    "E30":"Email Engine","E31":"SMS/MMS Engine","E32":"Phone Banking",
    "E33":"Direct Mail","E34":"Events","E35":"Interactive Comm Hub",
    "E36":"Messenger Integration","E37":"Event Management","E38":"Volunteer Coordination",
    "E39":"P2P Fundraising","E40":"Automation Control","E41":"Campaign Builder",
    "E42":"News Intelligence","E43":"Advocacy Tools","E44":"Vendor Compliance",
    "E45":"Video Studio","E46":"Broadcast Hub","E47":"AI Script Generator",
    "E48":"Communication DNA","E49":"Interview System","E50":"GPU Orchestrator",
    "E51":"Nexus Dashboard","E52":"Contact Intelligence","E53":"Document Generation",
    "E54":"Calendar/Scheduling","E55":"API Gateway","E56":"Visitor Deanon",
    "E57":"Messaging Center","E58":"Business Model",
}

ECO_PATTERN = re.compile(r'\bE(\d{2})\b')

SESSION_KEYWORDS = [
    'session', 'transcript', 'briefing', 'comet', 'repair_guide',
    'gap_analysis', 'master_directory', 'claude_rules', 'session_state',
    'handoff', 'summary', 'recap', 'notes', 'log_', '_log',
]

def get_ecosystems(path_str, name_str):
    found = set()
    for m in ECO_PATTERN.finditer(path_str + ' ' + name_str):
        eid = f"E{int(m.group(1)):02d}"
        if eid in ECOSYSTEM_NAMES:
            found.add(eid)
    return ','.join(sorted(found))

def is_session_transcript(name_str, type_str):
    name_lower = name_str.lower()
    if type_str not in ('md', 'docx', 'txt', 'gdoc'):
        return False
    return any(kw in name_lower for kw in SESSION_KEYWORDS)

def get_category(path_str):
    p = path_str.lower()
    if 'googledrive' in p or 'cloudstorage' in p or 'my drive' in p.replace(' ',''):
        return 'Google Drive'
    if '/downloads/' in p: return 'Downloads'
    if '/documents/' in p: return 'Documents'
    if 'broyhillgop-cursor' in p or 'cursor' in p.lower(): return 'BroyhillGOP'
    if 'ncboe' in p or 'donors' in p or 'fec' in p: return 'Donors/FEC'
    return 'Other'

print("Loading JSON...")
with open(INPUT) as f:
    data = json.load(f)

fi = data['file_index']
print(f"Enriching {len(fi)} records...")

# ── Pass 1: Get real dates from disk, build folder date index ──────────────────
# folder_dates[folder_path] = best known date in that folder
# Used to infer dates for files that have no mtime (e.g. SQL with no stat)
folder_dates = defaultdict(list)
missing_files = 0

for r in fi:
    path = r.get('path', '')
    name = r.get('name', '')
    ftype = r.get('type', '')
    folder = str(Path(path).parent)

    try:
        stat = os.stat(path)
        mtime   = datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d')
        created = datetime.fromtimestamp(stat.st_birthtime).strftime('%Y-%m-%d')
        r['mtime']   = mtime
        r['created'] = created
        r['size']    = stat.st_size
        r['date_inferred'] = False
        # Add this date to the folder pool for inference
        folder_dates[folder].append(mtime)
    except Exception:
        r['mtime']   = ''
        r['created'] = ''
        r['date_inferred'] = False
        missing_files += 1

    r['ecosystems'] = get_ecosystems(path, name)
    r['is_session'] = is_session_transcript(name, ftype)
    r['category']   = get_category(path)

# ── Pass 2: Infer missing dates from sibling files in same folder ──────────────
# If a file has no date but other files in the same folder do, use the most
# recent date from that folder as the inferred date.
inferred_count = 0
for r in fi:
    if r.get('mtime'):
        continue  # Already has a real date, skip
    folder = str(Path(r.get('path', '')).parent)
    siblings = folder_dates.get(folder, [])
    if siblings:
        best_date = max(siblings)  # Most recent sibling date
        r['mtime']         = best_date
        r['created']       = best_date
        r['date_inferred'] = True
        inferred_count += 1
        folder_dates[folder].append(best_date)

# ── Pass 3: Dedup — when same filename exists multiple times, mark older ones ──
# Groups by base filename. The newest version gets is_latest=True.
# Older versions get is_latest=False so they sort lower in results.
name_groups = defaultdict(list)
for r in fi:
    name_groups[r.get('name','').lower()].append(r)

dupe_count = 0
for name_key, group in name_groups.items():
    if len(group) < 2:
        group[0]['is_latest'] = True
        continue
    # Sort by mtime descending — newest first
    group.sort(key=lambda x: x.get('mtime',''), reverse=True)
    for i, r in enumerate(group):
        r['is_latest'] = (i == 0)   # Only the first (newest) is latest
        if i > 0:
            dupe_count += 1

data['enriched']  = datetime.now().isoformat()
data['v7']        = True

print(f"Writing enriched JSON to {OUTPUT}...")
with open(OUTPUT, 'w') as f:
    json.dump(data, f, separators=(',',':'))

size_mb = os.path.getsize(OUTPUT) / 1024 / 1024
print(f"\nDone.")
print(f"  Records enriched:       {len(fi)}")
print(f"  Files not on disk:      {missing_files}")
print(f"  Dates inferred:         {inferred_count}")
print(f"  Older dupes flagged:    {dupe_count}")
print(f"  Output size:            {size_mb:.1f} MB")

from collections import Counter
cats = Counter(r['category'] for r in fi)
with_eco  = sum(1 for r in fi if r['ecosystems'])
sessions  = sum(1 for r in fi if r['is_session'])
with_date = sum(1 for r in fi if r.get('mtime'))
inferred  = sum(1 for r in fi if r.get('date_inferred'))
print(f"\nCategories:              {dict(cats)}")
print(f"Files with ecosystem refs: {with_eco}")
print(f"Session/transcript files:  {sessions}")
print(f"Files with date:           {with_date} ({inferred} inferred from siblings)")
