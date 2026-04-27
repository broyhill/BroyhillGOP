#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# nexus_prompt.sh — F-16 prompt builder for Claude / Perplexity sessions
# ──────────────────────────────────────────────────────────────────────
# Builds a structured task brief that auto-loads cross-agent context.
# Paste the output at the start of any new Claude or Perplexity session
# to skip the warm-up tax and trigger high-intensity engineering mode.
#
# USAGE
#   bash nexus_prompt.sh "<topic>"              # default brief
#   bash nexus_prompt.sh --startup              # full startup brief (NEXUS wake)
#   bash nexus_prompt.sh "<topic>" --task "<imperative>"     # add task line
#   bash nexus_prompt.sh "<topic>" --pbcopy     # also copy to clipboard
#
# EXAMPLES
#   bash nexus_prompt.sh "ecosystem 32 frontend"
#   bash nexus_prompt.sh "phase b rollup" --task "review the dryrun and write the apply script"
#   bash nexus_prompt.sh --startup --pbcopy
#
# OUTPUT
#   A pasteable text block with: topic, latest doc per agent, recent files,
#   open authorized TODO items, and the required-action ladder.
# ──────────────────────────────────────────────────────────────────────

REPO=/Users/Broyhill/Documents/GitHub/BroyhillGOP
CURSOR=/Users/Broyhill/Desktop/BroyhillGOP-CURSOR
SEARCH="$REPO/ai_search.py"
PYTHON=${PYTHON:-/usr/bin/python3}

# ── Parse args ────────────────────────────────────────────────────────
TOPIC=""
TASK=""
STARTUP=0
PBCOPY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --startup)  STARTUP=1; shift ;;
    --task)     TASK="$2"; shift 2 ;;
    --pbcopy)   PBCOPY=1; shift ;;
    -h|--help)  sed -n '4,22p' "$0"; exit 0 ;;
    *)          TOPIC="${TOPIC:+$TOPIC }$1"; shift ;;
  esac
done

if [[ -z "$TOPIC" && $STARTUP -eq 0 ]]; then
  echo "Usage: bash nexus_prompt.sh \"<topic>\" [--task \"...\"] [--pbcopy]" >&2
  echo "       bash nexus_prompt.sh --startup [--pbcopy]" >&2
  exit 1
fi

# Helper: top-1 filename + date for a query (uses JSON for reliable parsing)
top_one() {
  local q="$1"
  "$PYTHON" "$SEARCH" "$q" --type md --limit 1 --json 2>/dev/null | "$PYTHON" -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if d:
        f = d[0]
        print(f\"{f.get('d','????-??-??')}  {f.get('n','?')}\")
        print(f\"               {f.get('p','?')}\")
    else:
        print('(no recent file found)')
except Exception:
    print('(no recent file found)')
"
}

# Helper: top-N file rows (date + name + path)
top_n() {
  local q="$1"; local n="$2"
  "$PYTHON" "$SEARCH" "$q" --limit "$n" --json 2>/dev/null | "$PYTHON" -c "
import json, sys
try:
    d = json.load(sys.stdin)
    for f in d:
        flags = ''
        if f.get('central'): flags += '★'
        if f.get('dc'):      flags += '⊕'
        if f.get('x'):       flags += '§'
        flags = flags.ljust(3) if flags else '   '
        print(f\"  {f.get('d','????-??-??')} [{flags}] .{f.get('t','?'):<4}  {f.get('n','?')[:60]}\")
except Exception:
    pass
"
}

# ── Build output ──────────────────────────────────────────────────────
NOW=$(date '+%Y-%m-%d %H:%M %Z')
INDEX_AGE=$(stat -f "%Sm" "$REPO/ai_search_index.json" 2>/dev/null || echo "?")

OUT=$(cat <<EOF
═══════════════════════════════════════════════════════════════════
NEXUS — TASK BRIEF
═══════════════════════════════════════════════════════════════════
TOPIC:      ${TOPIC:-BroyhillGOP startup}
GENERATED:  $NOW
INDEX DATE: $INDEX_AGE

START-UP FILES (read first, in order):
  1. $REPO/CLAUDE.md                  (boot doctrine + hard stops)
  2. $REPO/WHERE.md                   (pinned paths)
  3. $REPO/NEXUS.md                   (wake/sleep protocol + trigger words)
  4. $REPO/CENTRAL_FOLDER.md          (where to save outputs)
  5. $REPO/AI_SEARCH_GATEWAY.md       (how to search)
  6. $REPO/NEXUS_TODO.md              (open authorized + blocked items)

LATEST AGENT CONTEXT (from search engine):
  • Perplexity: $(top_one "PERPLEXITY_HANDOFF" "")
  • Cursor:     $(top_one "CURSOR_HANDOFF" "")
  • Claude:     $(top_one "SESSION_TRANSCRIPT CLAUDE" "")

EOF
)

if [[ -n "$TOPIC" ]]; then
  OUT+=$'\n'"RECENT FILES MATCHING TOPIC (newest first, top 5):"$'\n'"$(top_n "$TOPIC" 5)"$'\n'
fi

OUT+=$'\n'"OPEN WORK FROM NEXUS_TODO (top 20 lines):"$'\n'"$(head -40 "$REPO/NEXUS_TODO.md" 2>/dev/null | tail -25)"$'\n'

if [[ -n "$TASK" ]]; then
  OUT+=$'\n'"REQUESTED TASK:"$'\n'"  $TASK"$'\n'
fi

OUT+=$(cat <<'EOF'

REQUIRED ACTION (in order):
  1. Run NEXUS wake — load the start-up files above + the three latest
     agent docs. Report cross-agent context block.
  2. State scope-lock: which schemas, tables, files, endpoints are in
     play; which are off-limits.
  3. Produce a dry-run plan first. No live execution until Ed types
     AUTHORIZE.
  4. If anything pivots mid-task, STOP and report — never silently
     change approach.
  5. End with NEXUS sleep — full transcript + NEXUS_TODO update.

DOCTRINE REMINDERS:
  • Hetzner DB is truth source. Supabase is legacy/limited.
  • raw.ncboe_donations = read-only canary only.
  • No writes to core.di_donor_attribution.
  • Ed = EDGAR (never EDWARD). rnc_regid is TEXT (never BIGINT).
  • DataTrust NC voter ID column is state_voter_id (not ncid).
  • Single-word triggers from Ed: NEXUS / NEXUS sleep / STOP / AUTHORIZE.

═══════════════════════════════════════════════════════════════════
EOF
)

# ── Emit ──────────────────────────────────────────────────────────────
echo "$OUT"

if [[ $PBCOPY -eq 1 && -x /usr/bin/pbcopy ]]; then
  echo "$OUT" | /usr/bin/pbcopy
  echo "" >&2
  echo "(also copied to clipboard via pbcopy)" >&2
fi
