#!/usr/bin/env python3
import os, csv, zipfile, requests

SUPABASE_URL = 'https://isbgjpnbocdkeslofota.supabase.co'
SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlzYmdqcG5ib2Nka2VzbG9mb3RhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NDcwNzcwNywiZXhwIjoyMDgwMjgzNzA3fQ.DUIkApJpqTSv02ZRU4OQ0nK4iElq_Om6SLAmDSqkvF0'
HEADERS = {'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + SUPABASE_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal'}

def insert_batch(records):
    if not records: return 0
    resp = requests.post(SUPABASE_URL + '/rest/v1/donations_raw', headers=HEADERS, json=records)
    return len(records) if resp.status_code in [200,201] else 0

def load_ncsbe(filepath):
    print('Loading NCSBE:', filepath)
    total, batch = 0, []
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = row.get('name','') or row.get('contributor_name','') or ''
            parts = name.split()
            addr = ' '.join([row.get('street_address',''), row.get('city',''), row.get('state',''), row.get('zip','')]).strip()
            record = {
                'first_name': parts[0] if parts else '',
                'last_name': ' '.join(parts[1:]) if len(parts)>1 else '',
                'amount': float(row.get('amount',0) or 0),
                'date': row.get('date') or row.get('date_received'),
                'candidate': row.get('candidate') or row.get('committee_name'),
                'employer': row.get('employer',''),
                'occupation': row.get('occupation',''),
                'address_core_3': addr,
                'match_method': 'ncsbe'
            }
            batch.append(record)
            if len(batch) >= 500:
                total += insert_batch(batch)
                batch = []
                print('  NCSBE:', total)
    total += insert_batch(batch)
    print('NCSBE done:', total)
    return total

def load_fec(zippath, cycle):
    print('Loading FEC', cycle, ':', zippath)
    total, batch = 0, []
    with zipfile.ZipFile(zippath, 'r') as zf:
        for name in zf.namelist():
            if 'itcont' in name.lower():
                with zf.open(name) as f:
                    for line in f:
                        try:
                            fields = line.decode('utf-8','ignore').strip().split('|')
                            if len(fields)<15 or fields[9]!='NC': continue
                            nm = fields[7].split(', ')
                            first = nm[1].split()[0] if len(nm)>1 else ''
                            last = nm[0]
                            amt = float(fields[14]) if fields[14] else 0
                            addr = ' '.join([fields[8], fields[9], fields[10]])
                            record = {
                                'first_name': first[:100],
                                'last_name': last[:100],
                                'amount': amt,
                                'date': fields[13],
                                'committee_id': fields[0],
                                'employer': fields[11][:200] if len(fields)>11 else '',
                                'occupation': fields[12][:200] if len(fields)>12 else '',
                                'address_core_3': addr,
                                'match_method': 'fec_' + cycle
                            }
                            batch.append(record)
                            if len(batch)>=500:
                                total += insert_batch(batch)
                                batch = []
                                if total % 10000 == 0: print('  FEC', cycle, ':', total)
                        except: continue
    total += insert_batch(batch)
    print('FEC', cycle, 'done:', total)
    return total

if __name__ == '__main__':
    grand = 0
    grand += load_ncsbe('/opt/broyhillgop/data/nc-sboe/NC-Donors-2015-2026.csv')
    fec_dir = '/opt/broyhillgop/data/fec'
    for f in sorted(os.listdir(fec_dir)):
        if f.startswith('FEC-Individual') and f.endswith('.zip'):
            cycle = f.split('-')[-1].replace('.zip','')
            grand += load_fec(os.path.join(fec_dir,f), cycle)
    print('TOTAL LOADED:', grand)
