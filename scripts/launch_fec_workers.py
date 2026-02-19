#!/usr/bin/env python3
"""Launch 10 parallel FEC import workers"""
import subprocess, json, os
from pathlib import Path

FEC_DIR = "/root/fec_downloads"
NUM_WORKERS = 10
LOG_DIR = "/opt/broyhillgop/logs"

os.makedirs(LOG_DIR, exist_ok=True)

# Gather all CSV files
all_files = []
for race in ["PRESIDENT", "NC_SENATE", "NC_HOUSE"]:
    d = Path(FEC_DIR) / race
    if d.exists():
        all_files.extend([str(f) for f in sorted(d.glob("*.csv"))])

print(f"Found {len(all_files)} CSV files")

# Split files across workers
chunks = [[] for _ in range(NUM_WORKERS)]
for i, f in enumerate(all_files):
    chunks[i % NUM_WORKERS].append(f)

# Launch workers
pids = []
for i in range(NUM_WORKERS):
    if not chunks[i]:
        continue
    files_json = json.dumps(chunks[i])
    log_file = f"{LOG_DIR}/fec_worker_{i}.log"
    cmd = f"nohup python3 /opt/broyhillgop/scripts/fec_worker.py {i} {repr(files_json)} > {log_file} 2>&1 &"
    subprocess.Popen(cmd, shell=True)
    print(f"Worker {i}: {len(chunks[i])} files -> {log_file}")

print(f"\n=== {NUM_WORKERS} WORKERS LAUNCHED ===")
print("Monitor: tail -f /opt/broyhillgop/logs/fec_worker_*.log")
print("Check DB: psql -c \"SELECT COUNT(*) FROM staging_fec_contributions\"")
