#!/usr/bin/env python3
"""
ai_search.py — AI-callable search gateway over GOD_FILE_INDEX_V8.html

For any AI agent (Claude, Cursor, Perplexity, etc.) working on BroyhillGOP.
Fast, deterministic, JSON-output search across the entire indexed universe.

USAGE
─────
  python3 ai_search.py "ecosystem 32"
  python3 ai_search.py "ecosystem 32" --limit 50
  python3 ai_search.py "donor cluster" --from 2026-04-01
  python3 ai_search.py "phase b" --central --type md
  python3 ai_search.py --ecosystem E32
  python3 ai_search.py --since 14    (last 14 days)

OUTPUT
──────
Default: human-readable text, one file per line, newest first
JSON:    --json (machine-readable; full record per file)
Counts:  --count (returns just the number of matches)

EXAMPLES (real queries)
───────────────────────
  python3 ai_search.py "rollup" --since 7              # last week's rollup work
  python3 ai_search.py "" --central --since 1          # everything new today
  python3 ai_search.py --ecosystem E20 --type py       # E20 Brain code
  python3 ai_search.py "session" --type md --limit 20  # latest 20 sessions
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timedelta

INDEX_PATH = "/Users/Broyhill/Documents/GitHub/BroyhillGOP/GOD_FILE_INDEX_V8.html"
JSON_PATH  = "/Users/Broyhill/Documents/GitHub/BroyhillGOP/ai_search_index.json"

def load_index(path=None):
    """Prefer ai_search_index.json (faster, written by morning_scrape.sh)
    and fall back to parsing GOD_FILE_INDEX_V8.html. The user can override
    with --index pointing at either format."""
    candidates = [path] if path else [JSON_PATH, INDEX_PATH]
    for p in candidates:
        if not p or not os.path.isfile(p): continue
        with open(p, encoding='utf-8') as f:
            c = f.read()
        if p.endswith('.json'):
            try:
                d = json.loads(c)
                return d.get('files', d) if isinstance(d, dict) else d
            except json.JSONDecodeError:
                continue
        m = re.search(r'const FILES\s*=\s*(\[.*?\])\s*;', c, re.DOTALL)
        if m:
            return json.loads(m.group(1))
    sys.stderr.write(f"ERROR: no usable index found. Tried: {candidates}\n")
    sys.exit(2)

def matches(f, terms, args):
    # Term match across name, path, topics, ecosystems, deep content
    if terms:
        hay = (f.get('n','') + ' ' + f.get('p','') + ' ' + f.get('q','') + ' ' +
               f.get('e','') + ' ' + f.get('c','') + ' ' + f.get('desc','')).lower()
        if not all(t in hay for t in terms):
            return False
    if args.ecosystem:
        eco = (f.get('e') or '').upper()
        if args.ecosystem.upper() not in eco.split(','):
            return False
    if args.type:
        if f.get('t','').lower() != args.type.lower().lstrip('.'):
            return False
    if args.category:
        if f.get('c','').lower() != args.category.lower():
            return False
    if args.central and not f.get('central'):
        return False
    if args.deep and not f.get('dc'):
        return False
    if args.session and not (f.get('x') or any(k in f.get('n','').lower() for k in ['session','transcript','handoff','briefing'])):
        return False
    if args.frm and (f.get('d','') < args.frm):
        return False
    if args.to and (f.get('d','') > args.to):
        return False
    return True

def format_text(results, limit, with_topics):
    if not results:
        return "(no matches)"
    out = [f"{len(results)} matches (showing {min(limit, len(results))}):", ""]
    for f in results[:limit]:
        flags = ""
        if f.get('central'): flags += "★"
        if f.get('dc'):      flags += "⊕"
        if f.get('x'):       flags += "§"
        flags = f"[{flags:<3}]" if flags else "[   ]"
        eco = f"E:{f['e']}" if f.get('e') else ""
        size = f.get('s', 0)
        sz = f"{size//1024}KB" if size > 1024 else f"{size}B"
        out.append(f"  {f.get('d','??????????')} {flags} .{f.get('t','?'):<5} {sz:>7}  {f.get('n','')[:70]} {eco}")
        out.append(f"            {f.get('p','')}")
        if with_topics and f.get('q'):
            topics = f['q'].split('||')[0].strip()[:140]
            if topics:
                out.append(f"            topics: {topics}")
        out.append("")
    return "\n".join(out)

def main():
    ap = argparse.ArgumentParser(description="AI search gateway for BroyhillGOP")
    ap.add_argument("query", nargs="*", help="Search terms (space-separated, all must match)")
    ap.add_argument("--ecosystem", "-e", help="Filter by ecosystem (E00..E58)")
    ap.add_argument("--type", "-t", help="Filter by file type (md, sql, py, etc.)")
    ap.add_argument("--category", "-c", help="Filter by category (BroyhillGOP, Downloads, Documents, etc.)")
    ap.add_argument("--central", action="store_true", help="★ CENTRAL files only")
    ap.add_argument("--deep", action="store_true", help="Deep-indexed files only (have HEADINGS / TECH / TABLES)")
    ap.add_argument("--session", "-s", action="store_true", help="Sessions / transcripts / handoffs / briefings only")
    ap.add_argument("--from", dest="frm", help="Date from (YYYY-MM-DD)")
    ap.add_argument("--to", help="Date to (YYYY-MM-DD)")
    ap.add_argument("--since", type=int, help="Last N days (overrides --from)")
    ap.add_argument("--limit", "-l", type=int, default=30, help="Max results to show (default 30)")
    ap.add_argument("--json", action="store_true", help="Output JSON instead of text")
    ap.add_argument("--count", action="store_true", help="Output only the count")
    ap.add_argument("--topics", action="store_true", help="Show topic chips per result (text mode)")
    ap.add_argument("--index", default=INDEX_PATH, help="Path to V8 HTML index")
    ap.add_argument("--pinned", action="store_true", help="Print pinned paths from WHERE.md and exit")
    args = ap.parse_args()

    if args.pinned:
        where = "/Users/Broyhill/Documents/GitHub/BroyhillGOP/WHERE.md"
        if os.path.isfile(where):
            with open(where, encoding='utf-8') as f: print(f.read())
        else:
            print("WHERE.md not found at " + where)
        return

    if args.since:
        args.frm = (datetime.now() - timedelta(days=args.since)).strftime("%Y-%m-%d")

    files = load_index(args.index)
    terms = [t.lower() for t in args.query if t.strip()]
    results = [f for f in files if matches(f, terms, args)]
    # Newest first; CENTRAL files float within same date
    results.sort(key=lambda f: (f.get('d',''), 1 if f.get('central') else 0, f.get('n','')), reverse=True)

    if args.count:
        print(len(results))
        return
    if args.json:
        out = results[:args.limit] if args.limit else results
        print(json.dumps(out, indent=2))
        return
    print(format_text(results, args.limit, with_topics=args.topics))

if __name__ == "__main__":
    main()
