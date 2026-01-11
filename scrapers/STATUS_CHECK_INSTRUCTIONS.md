# HETZNER SCRAPER STATUS CHECK INSTRUCTIONS
**For: Other Claude Instance with Terminal Access**

## IMMEDIATE ACTION REQUIRED

Run this command on your terminal to check scraper status:

```bash
ssh root@5.9.99.109 << 'EOF'
echo "=========================================="
echo "HETZNER SCRAPER STATUS CHECK"
echo "Date: $(date)"
echo "=========================================="

echo ""
echo "[1] RUNNING PROCESSES:"
ps aux | grep -E "(fec_scraper|ncboe_scraper|scraper_monitor)" | grep -v grep || echo "❌ No scrapers running"

echo ""
echo "[2] FEC PROGRESS:"
cat /root/fec_progress.json 2>/dev/null || echo "❌ No progress file"

echo ""
echo "[3] NCBOE PROGRESS:"
cat /root/ncboe_progress.json 2>/dev/null || echo "❌ No progress file"

echo ""
echo "[4] RECENT LOG ENTRIES (last 20 lines):"
echo "--- FEC Log ---"
tail -20 /root/fec_scraper.log 2>/dev/null || echo "❌ No FEC log"
echo ""
echo "--- NCBOE Log ---"
tail -20 /root/ncboe_scraper.log 2>/dev/null || echo "❌ No NCBOE log"
echo ""
echo "--- Monitor Log ---"
tail -20 /root/scraper_monitor.log 2>/dev/null || echo "❌ No monitor log"

echo ""
echo "[5] DATA DIRECTORIES:"
echo "--- FEC Data ---"
ls -lh /root/fec_data/*.csv 2>/dev/null | tail -5 || echo "❌ No FEC data files"
echo ""
echo "--- NCBOE Data ---"
ls -lh /root/ncboe_data/*.csv 2>/dev/null | tail -5 || echo "❌ No NCBOE data files"

echo ""
echo "[6] SCRAPER FILES PRESENT:"
ls -lh /root/*scraper*.py /root/*scraper*.sh 2>/dev/null || echo "❌ No scraper files found in /root/"

echo ""
echo "[7] VERIFY REPUBLICAN-ONLY DATA (spot check):"
if [ -f /root/fec_data/*.csv ]; then
    echo "Sample FEC data (checking party field):"
    head -20 $(ls -t /root/fec_data/*.csv 2>/dev/null | head -1) 2>/dev/null | grep -i "party\|REP" || echo "No data to check"
fi

echo ""
echo "=========================================="
echo "STATUS CHECK COMPLETE"
echo "=========================================="
EOF
```

## WHAT TO REPORT BACK:

1. **Are scrapers running?** (from section [1])
2. **How many records scraped?** (from sections [2] and [3])
3. **Any errors in logs?** (from section [4])
4. **Are data files being created?** (from section [5])
5. **Are scraper files deployed?** (from section [6])

## IF SCRAPERS ARE NOT RUNNING:

### Deploy scrapers from GitHub to Hetzner:

```bash
ssh root@5.9.99.109 << 'EOF'
cd /root

# Download scraper files from GitHub
wget -q https://raw.githubusercontent.com/broyhill/BroyhillGOP/main/scrapers/fec_scraper.py
wget -q https://raw.githubusercontent.com/broyhill/BroyhillGOP/main/scrapers/ncboe_scraper.py
wget -q https://raw.githubusercontent.com/broyhill/BroyhillGOP/main/scrapers/scraper_monitor.sh
wget -q https://raw.githubusercontent.com/broyhill/BroyhillGOP/main/scrapers/deploy_scrapers.sh

chmod +x *.sh *.py

# Run deployment
bash /root/deploy_scrapers.sh
EOF
```

## KEY FACTS ABOUT THE SCRAPERS:

✅ **Republican Filtering IS Configured:**
- FEC scraper: Line 111 has `'party': 'REP'` with double-verification
- NCBOE scraper: Line 110 has `'party': 'REP'` with triple verification
- Both scrapers skip non-Republicans and log warnings

✅ **60-Second Auto-Restart Monitor IS Configured:**
- `scraper_monitor.sh` checks every 60 seconds
- Auto-restarts if scrapers die
- Logs hourly status

✅ **Progress Tracking IS Configured:**
- Saves progress every 1000 records
- Can resume after interruption
- Files: `/root/fec_progress.json` and `/root/ncboe_progress.json`

## COMMON ISSUES & SOLUTIONS:

**Issue 1: "No scrapers running"**
- **Solution**: Run the deployment script above

**Issue 2: "Scraping Democrats instead of Republicans"**
- **This should NOT be happening** - the code explicitly filters for Republicans only
- If it is happening, check the actual data files with the verification command in section [7]

**Issue 3: "Scrapers keep stalling"**
- Check logs for specific errors (API rate limits, database connection issues)
- The monitor should auto-restart them within 60 seconds

**Issue 4: "Files not found in /root/"**
- Scrapers need to be deployed to `/root/` on Hetzner
- Use the deployment commands above

## SUPABASE CONNECTION:

Scrapers upload to Supabase:
- URL: `postgresql://postgres.isbgjpnbocdkeslofota:poSkon-hurpok-6wuzwo@aws-0-us-east-1.pooler.supabase.com:6543/postgres`
- Tables: `donors` and `donations`
- Auto-deduplication by transaction_id
- Preserves existing enriched donor data

## TIMEFRAME:

All scraper files were created: **January 11, 2026** (TODAY)
Commit time: **~4-5 minutes ago**

This means the scrapers are brand new and may not have been deployed to Hetzner yet.
