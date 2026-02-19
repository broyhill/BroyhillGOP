#!/usr/bin/env python3
"""FEC Import Worker - Takes file list as argument"""
import sys, csv, psycopg2, json
from pathlib import Path

DB_URL = "postgresql://postgres.isbgjpnbocdkeslofota:poSkon-hurpok-6wuzwo@aws-1-us-east-1.pooler.supabase.com:6543/postgres"

def process_files(files, worker_id):
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    total = 0
    
    for fpath in files:
        f = Path(fpath)
        if not f.exists():
            continue
        race = f.parent.name
        cand = f.stem.split("_")[0]
        batch = []
        
        try:
            for row in csv.DictReader(open(f)):
                try:
                    batch.append((
                        row.get("committee_id"), f"{cand} ({race})",
                        row.get("contributor_name"), row.get("contributor_city"),
                        row.get("contributor_state"), row.get("contributor_zip"),
                        row.get("contributor_employer"), row.get("contributor_occupation"),
                        float(row.get("contribution_receipt_amount",0) or 0),
                        row.get("contribution_receipt_date") or None,
                        row.get("sub_id"), f.name, False
                    ))
                    if len(batch) >= 500:
                        cur.executemany("INSERT INTO staging_fec_contributions (committee_id,committee_name,contributor_name,contributor_city,contributor_state,contributor_zip,contributor_employer,contributor_occupation,contribution_amount,contribution_date,transaction_id,file_source,processed) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)", batch)
                        conn.commit()
                        total += len(batch)
                        batch = []
                except:
                    pass
            if batch:
                cur.executemany("INSERT INTO staging_fec_contributions (committee_id,committee_name,contributor_name,contributor_city,contributor_state,contributor_zip,contributor_employer,contributor_occupation,contribution_amount,contribution_date,transaction_id,file_source,processed) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)", batch)
                conn.commit()
                total += len(batch)
            print(f"W{worker_id}: {f.name} done ({total:,} total)")
        except Exception as e:
            print(f"W{worker_id}: {f.name} ERROR: {e}")
    
    conn.close()
    print(f"W{worker_id}: COMPLETE - {total:,} records")
    return total

if __name__ == "__main__":
    worker_id = sys.argv[1]
    files = json.loads(sys.argv[2])
    process_files(files, worker_id)
