#!/usr/bin/env python3
import os, csv, zipfile, requests, sys
sys.stdout.reconfigure(line_buffering=True)

SUPABASE_URL = 'https://isbgjpnbocdkeslofota.supabase.co'
SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlzYmdqcG5ib2Nka2VzbG9mb3RhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NDcwNzcwNywiZXhwIjoyMDgwMjgzNzA3fQ.DUIkApJpqTSv02ZRU4OQ0nK4iElq_Om6SLAmDSqkvF0'
HEADERS = {'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + SUPABASE_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal'}

def insert_batch(records):
    if not records: return 0
    resp = requests.post(SUPABASE_URL + '/rest/v1/donations_raw', headers=HEADERS, json=records)
    if resp.status_code in [200,201]:
        return len(records)
    print('ERR:', resp.status_code, resp.text[:100])
    return 0

def load_ncsbe(fp):
    print('NCSBE:', fp)
    total, batch = 0, []
    with open(fp, 'r', encoding='utf-8', errors='ignore') as f:
        for row in csv.DictReader(f):
            nm = row.get('Name', '').split()
            try: amt = float(row.get('Amount', '0').replace(',', ''))
            except: amt = 0
            batch.append({
                'first_name': nm[0][:100] if nm else '',
                'last_name': ' '.join(nm[1:])[:100] if len(nm)>1 else '',
                'amount': amt,
                'date_occured': row.get('Date Occured', ''),
                'candidate': row.get('Candidate/Referendum Name', '') or row.get('Committee Name', ''),
                'employer': row.get("Employer's Name/Specific Field", '')[:200],
                'occupation': row.get('Profession/Job Title', '')[:200],
                'city': row.get('City', ''),
                'state': row.get('State', ''),
                'zip_code': row.get('Zip Code', ''),
                'match_method': 'ncsbe'
            })
            if len(batch) >= 500:
                total += insert_batch(batch)
                batch = []
                if total % 5000 == 0: print('  ncsbe:', total)
    total += insert_batch(batch)
    print('NCSBE done:', total)
    return total

def load_fec(zp, cyc):
    print('FEC', cyc)
    total, batch = 0, []
    with zipfile.ZipFile(zp, 'r') as zf:
        for n in zf.namelist():
            if 'itcont' in n.lower() and n.endswith('.txt'):
                print('  file:', n)
                with zf.open(n) as f:
                    for line in f:
                        try:
                            fld = line.decode('utf-8','ignore').strip().split('|')
                            if len(fld)<15 or fld[9]!='NC': continue
                            nm = fld[7].split(', ')
                            try: amt = float(fld[14])
                            except: amt = 0
                            batch.append({
                                'first_name': (nm[1].split()[0] if len(nm)>1 and nm[1] else '')[:100],
                                'last_name': nm[0][:100] if nm else '',
                                'amount': amt,
                                'date_occured': fld[13] if len(fld)>13 else '',
                                'committee': fld[0],
                                'employer': fld[11][:200] if len(fld)>11 else '',
                                'occupation': fld[12][:200] if len(fld)>12 else '',
                                'city': fld[8] if len(fld)>8 else '',
                                'state': 'NC',
                                'zip_code': fld[10] if len(fld)>10 else '',
                                'match_method': 'fec_' + cyc
                            })
                            if len(batch)>=500:
                                total += insert_batch(batch)
                                batch = []
                                if total % 10000 == 0: print('  fec', cyc, ':', total)
                        except: continue
    total += insert_batch(batch)
    print('FEC', cyc, 'done:', total)
    return total

if __name__ == '__main__':
    grand = load_ncsbe('/opt/broyhillgop/data/nc-sboe/NC-Donors-2015-2026.csv')
    for f in sorted(os.listdir('/opt/broyhillgop/data/fec')):
        if f.startswith('FEC-Individual') and f.endswith('.zip'):
            cyc = f.replace('FEC-Individual-Donors-','').replace('.zip','')
            grand += load_fec('/opt/broyhillgop/data/fec/'+f, cyc)
    print('TOTAL:', grand)
