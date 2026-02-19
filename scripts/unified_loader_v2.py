#!/usr/bin/env python3
import os, csv, zipfile, requests

SUPABASE_URL = 'https://isbgjpnbocdkeslofota.supabase.co'
SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlzYmdqcG5ib2Nka2VzbG9mb3RhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NDcwNzcwNywiZXhwIjoyMDgwMjgzNzA3fQ.DUIkApJpqTSv02ZRU4OQ0nK4iElq_Om6SLAmDSqkvF0'
HEADERS = {'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + SUPABASE_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal'}

def insert_batch(records):
    if not records: return 0
    resp = requests.post(SUPABASE_URL + '/rest/v1/donations_raw', headers=HEADERS, json=records)
    if resp.status_code in [200,201]:
        return len(records)
    else:
        print('ERROR:', resp.status_code, resp.text[:200])
        return 0

def load_ncsbe(filepath):
    print('Loading NCSBE:', filepath)
    total, batch = 0, []
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = row.get('Name', '')
            parts = name.split()
            first = parts[0] if parts else ''
            last = ' '.join(parts[1:]) if len(parts) > 1 else name
            
            try:
                amt = float(row.get('Amount', '0').replace(',', ''))
            except:
                amt = 0
                
            addr = ' '.join(filter(None, [
                row.get('Street Line 1', ''),
                row.get('City', ''),
                row.get('State', ''),
                row.get('Zip Code', '')
            ]))
            
            record = {
                'first_name': first[:100],
                'last_name': last[:100],
                'amount': amt,
                'date': row.get('Date Occured', ''),
                'candidate': row.get('Candidate/Referendum Name', '') or row.get('Committee Name', ''),
                'employer': row.get("Employer's Name/Specific Field", '')[:200],
                'occupation': row.get('Profession/Job Title', '')[:200],
                'address_core_3': addr[:300],
                'match_method': 'ncsbe'
            }
            batch.append(record)
            
            if len(batch) >= 500:
                inserted = insert_batch(batch)
                total += inserted
                batch = []
                if total % 5000 == 0:
                    print('  NCSBE:', total)
    
    total += insert_batch(batch)
    print('NCSBE done:', total)
    return total

def load_fec(zippath, cycle):
    print('Loading FEC', cycle, ':', zippath)
    total, batch = 0, []
    with zipfile.ZipFile(zippath, 'r') as zf:
        for name in zf.namelist():
            if 'itcont' in name.lower() and name.endswith('.txt'):
                print('  Processing:', name)
                with zf.open(name) as f:
                    for line in f:
                        try:
                            fields = line.decode('utf-8', 'ignore').strip().split('|')
                            if len(fields) < 15:
                                continue
                            state = fields[9] if len(fields) > 9 else ''
                            if state != 'NC':
                                continue
                            
                            nm = fields[7].split(', ')
                            first = nm[1].split()[0] if len(nm) > 1 and nm[1] else ''
                            last = nm[0] if nm else ''
                            
                            try:
                                amt = float(fields[14])
                            except:
                                amt = 0
                            
                            record = {
                                'first_name': first[:100],
                                'last_name': last[:100],
                                'amount': amt,
                                'date': fields[13] if len(fields) > 13 else '',
                                'committee_id': fields[0],
                                'employer': (fields[11] if len(fields) > 11 else '')[:200],
                                'occupation': (fields[12] if len(fields) > 12 else '')[:200],
                                'address_core_3': ' '.join([fields[8], fields[9], fields[10]]) if len(fields) > 10 else '',
                                'match_method': 'fec_' + cycle
                            }
                            batch.append(record)
                            
                            if len(batch) >= 500:
                                inserted = insert_batch(batch)
                                total += inserted
                                batch = []
                                if total % 10000 == 0:
                                    print('  FEC', cycle, ':', total)
                        except Exception as e:
                            continue
    
    total += insert_batch(batch)
    print('FEC', cycle, 'done:', total)
    return total

if __name__ == '__main__':
    import sys
    sys.stdout.reconfigure(line_buffering=True)
    
    grand = 0
    grand += load_ncsbe('/opt/broyhillgop/data/nc-sboe/NC-Donors-2015-2026.csv')
    
    fec_dir = '/opt/broyhillgop/data/fec'
    for f in sorted(os.listdir(fec_dir)):
        if f.startswith('FEC-Individual') and f.endswith('.zip'):
            cycle = f.replace('FEC-Individual-Donors-', '').replace('.zip', '')
            grand += load_fec(os.path.join(fec_dir, f), cycle)
    
    print('TOTAL LOADED:', grand)
