# FEC Overnight Pull — Restart Playbook
**Written: April 3, 2026 11:48 PM | BroyhillGOP-Claude**

---

## Current PIDs (April 3 night)

| Pull | PID | Log | CSV written when |
|------|-----|-----|-----------------|
| Presidential | 22490 | `~/Downloads/fec_pres_nc.log` | COMPLETE only |
| Senate | 27638 | `~/Downloads/fec_senate_nc.log` | COMPLETE only |
| House | 27639 | `~/Downloads/fec_house_nc.log` | COMPLETE only |

> **Note:** Presidential (22490) is running OLD code. If it crashes with HTTP 422, restart with the commands below — the fixed code handles `last_contribution_receipt_date` fallback correctly.

---

## Morning Check (run in order)

```bash
# 1. Are they still alive?
ps aux | grep fec_nc_republican | grep -v grep

# 2. How many rows so far? (CSV only exists after COMPLETE)
wc -l ~/Downloads/FEC_NC_*.csv 2>/dev/null || echo "No CSVs yet — still running"

# 3. Check each log for COMPLETE or errors
tail -30 ~/Downloads/fec_pres_nc.log
tail -30 ~/Downloads/fec_senate_nc.log
tail -30 ~/Downloads/fec_house_nc.log
```

---

## Restart Commands (if a job died)

**ALWAYS kill the dead process first before restarting:**
```bash
pkill -f "fec_nc_republican_donors.*presidential"   # Presidential
pkill -f "fec_nc_republican_donors.*office S"       # Senate  
pkill -f "fec_nc_republican_donors.*office H"       # House
```

**Set environment (from your worktree):**
```bash
cd /Users/Broyhill/.cursor/worktrees/BroyhillGOP-CURSOR/yte
export OPENFEC_API_KEY="YOUR_NEW_ROTATED_KEY"
export OPENFEC_REQUEST_DELAY=1.0
```

**Restart Presidential:**
```bash
nohup env OPENFEC_API_KEY="$OPENFEC_API_KEY" OPENFEC_REQUEST_DELAY="$OPENFEC_REQUEST_DELAY" \
  python3 -u -m pipeline.fec_nc_republican_donors --presidential-nc-export-only \
  --output ~/Downloads/FEC_NC_Presidential.csv >> ~/Downloads/fec_pres_nc.log 2>&1 &
echo "Presidential PID: $!"
```

**Restart Senate:**
```bash
nohup env OPENFEC_API_KEY="$OPENFEC_API_KEY" OPENFEC_REQUEST_DELAY="$OPENFEC_REQUEST_DELAY" \
  python3 -u -m pipeline.fec_nc_republican_donors --skip-presidential --office S \
  --output ~/Downloads/FEC_NC_Senate.csv >> ~/Downloads/fec_senate_nc.log 2>&1 &
echo "Senate PID: $!"
```

**Restart House:**
```bash
nohup env OPENFEC_API_KEY="$OPENFEC_API_KEY" OPENFEC_REQUEST_DELAY="$OPENFEC_REQUEST_DELAY" \
  python3 -u -m pipeline.fec_nc_republican_donors --skip-presidential --office H \
  --output ~/Downloads/FEC_NC_House.csv >> ~/Downloads/fec_house_nc.log 2>&1 &
echo "House PID: $!"
```

---

## Pagination Fix (already applied to Senate/House)

**The bug:** HTTP 422 on Schedule A pagination when `last_index` was present but `last_contribution_receipt_date` was missing from `last_indexes`.

**The fix** (in `pull_contributions_for_committee`): If API omits the date in `last_indexes`, fall back to taking it from the last row on the page. Don't paginate further without a valid date.

Presidential (22490) was started before the fix. If it crashes with 422, restarting it picks up the fixed code.

---

## Security

**ROTATE the FEC API key immediately on wake:**
1. Go to [https://api.data.gov/signup/](https://api.data.gov/signup/)
2. Request a new key for the same email
3. Update `OPENFEC_API_KEY` in your environment before any restart
4. The old key `M7JqKy1IYd23ajGAGrR5WYR3jOrhWB1luqGIX95Y` has appeared in multiple chat messages — treat as compromised

---

## After Pulls Complete — Load Sequence

### Step 1: Verify FEC CSVs
```bash
wc -l ~/Downloads/FEC_NC_House.csv ~/Downloads/FEC_NC_Senate.csv ~/Downloads/FEC_NC_Presidential.csv
```

### Step 2: Load NCSBE queue (needs "I authorize this action")
Files in `/home/user/workspace/` ready to load into `nc_boe_donations_raw`:
- NC-House-Gop-2015-2026.csv — 407,499 rows, $280M
- NC-Senate-Gop-2015-2026-2.csv — 321,585 rows, $313M
- County-Municipal-100-counties-GOP-2015-2026.csv — 451,483 rows
- 2ndary-counties-muni-cty-gop-2015-2026.csv — 96,273 rows
- shiff-only-gop-100-counties.csv — 272,481 rows
- 2ndary-sheriff-gop-2015-2026.csv — 75,550 rows
- Judicial-gop-100-counties-2015-2026.csv — 170,002 rows
- Test-county-commissioners.csv — 7,484 rows
- District-Att-gop-100-counties-2015-2026.csv — 46,069 rows
- District-ct-judge-gop-100-counties-2015-2026.csv — 64,708 rows
- clerk-court-gop-2015-2026.csv — 5,651 rows
- Council-commissioners-gop-2015-2026.csv — 55,965 rows
- school-board-gop-2015-2026.csv — 25,834 rows
- **SKIP:** alderman-gop-100-counties-2015-2026.csv (78 rows, trivial)

**Total queued: ~2,000,584 rows**

### Step 3: Danny's dim_election CSV
Still pending — email Danny Gustafson (dgustafson@gop.com) if not received by end of day Saturday.

### Step 4: FEC → Supabase load
After CSV verification, load FEC_NC_House/Senate/Presidential into `public.fec_donations` via Hetzner pipeline.

---

## If You're Confused — Just Paste the Log

Send the last 30 lines of any `fec_*_nc.log` and say "status" — Perplexity will diagnose and give exact restart commands.

---
*Saved by BroyhillGOP-Claude | April 3, 2026*
