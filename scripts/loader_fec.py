#!/usr/bin/env python3
import os, csv, zipfile, requests, sys
sys.stdout.reconfigure(line_buffering=True)

SUPABASE_URL = 'https://isbgjpnbocdkeslofota.supabase.co'
SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlzYmdqcG5ib2Nka2VzbG9mb3RhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NDcwNzcwNywiZXhwIjoyMDgwMjgzNzA3fQ.DUIkApJpqTSv02ZRU4OQ0nK4iElq_Om6SLAmDSqkvF0'
HEADERS = {'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + SUPABASE_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal'}

def fmt_date(d):
    if d and len(d)==8 and d.isdigit():
        return d[4:8]+'-'+d[0:2]+'-'+d[2:4]
    return None

def insert_batch(records):
    if not records: return 0
    resp = requests.post(SUPABASE_URL + '/rest/v1/donations_raw', headers=HEADERS, json=records)
    if resp.status_code in [200,201]:
        return len(records)
    print('ERR:', resp.text[:150])
    return 0

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
                                'date_occured': fmt_date(fld[13]) if len(fld)>13 else None,
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
    grand = 0
    for f in sorted(os.listdir('/opt/broyhillgop/data/fec')):
        if f.startswith('FEC-Individual') and f.endswith('.zip'):
            cyc = f.replace('FEC-Individual-Donors-','').replace('.zip','')
            grand += load_fec('/opt/broyhillgop/data/fec/'+f, cyc)
    print('TOTAL FEC:', grand)
