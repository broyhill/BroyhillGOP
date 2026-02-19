#!/usr/bin/env python3
"""FEC Filtered Extract - Republican NC donors only"""

import zipfile
import csv
import os

# Step 1: Load candidate master (party, office, state)
def load_candidates(zip_path):
    """Returns dict: candidate_id -> {party, office, state}"""
    candidates = {}
    with zipfile.ZipFile(zip_path, 'r') as zf:
        for name in zf.namelist():
            with zf.open(name) as f:
                for line in f:
                    try:
                        fields = line.decode('utf-8', 'ignore').strip().split('|')
                        if len(fields) >= 5:
                            cand_id = fields[0]  # H0AL01055
                            party = fields[2]     # REP, DEM, etc
                            office = fields[5] if len(fields) > 5 else ''  # H, S, P
                            cand_state = fields[4]  # AL, NC, etc
                            candidates[cand_id] = {
                                'party': party,
                                'office': office,
                                'state': cand_state
                            }
                    except:
                        continue
    print(f'Loaded {len(candidates)} candidates')
    return candidates

# Step 2: Load committee -> candidate linkage
def load_linkage(zip_path):
    """Returns dict: committee_id -> candidate_id"""
    linkage = {}
    with zipfile.ZipFile(zip_path, 'r') as zf:
        for name in zf.namelist():
            with zf.open(name) as f:
                for line in f:
                    try:
                        fields = line.decode('utf-8', 'ignore').strip().split('|')
                        if len(fields) >= 4:
                            cand_id = fields[0]   # H0AL01055
                            cmte_id = fields[3]   # C00697789
                            linkage[cmte_id] = cand_id
                    except:
                        continue
    print(f'Loaded {len(linkage)} committee linkages')
    return linkage

# Step 3: Filter FEC contributions
def filter_fec(zip_path, candidates, linkage, cycle):
    """Filter FEC file, return list of valid records"""
    records = []
    skipped_non_nc_donor = 0
    skipped_non_rep = 0
    skipped_non_nc_non_pres = 0
    skipped_excluded_cmte = 0
    
    excluded_terms = ['WINRED', 'ACTBLUE', 'REPUBLICAN NATIONAL COMMITTEE', 
                      'DEMOCRATIC NATIONAL', 'NRSC', 'NRCC', 'DCCC', 'DSCC',
                      'JOINT FUNDRAISING', ' JFC', 'VICTORY FUND']
    
    with zipfile.ZipFile(zip_path, 'r') as zf:
        for name in zf.namelist():
            if 'itcont' not in name.lower():
                continue
            print(f'  Processing: {name}')
            with zf.open(name) as f:
                for line in f:
                    try:
                        fields = line.decode('utf-8', 'ignore').strip().split('|')
                        if len(fields) < 15:
                            continue
                        
                        # Field positions in FEC individual contributions:
                        # 0=CMTE_ID, 7=NAME, 8=CITY, 9=STATE, 10=ZIP, 11=EMPLOYER, 
                        # 12=OCCUPATION, 13=DATE, 14=AMOUNT
                        
                        cmte_id = fields[0]
                        donor_state = fields[9]
                        
                        # Filter 1: NC donors only
                        if donor_state != 'NC':
                            skipped_non_nc_donor += 1
                            continue
                        
                        # Check for excluded committee names
                        cmte_upper = cmte_id.upper()
                        skip_cmte = False
                        for term in excluded_terms:
                            if term in cmte_upper:
                                skip_cmte = True
                                break
                        if skip_cmte:
                            skipped_excluded_cmte += 1
                            continue
                        
                        # Get candidate info via linkage
                        cand_id = linkage.get(cmte_id)
                        if cand_id:
                            cand_info = candidates.get(cand_id, {})
                            party = cand_info.get('party', '')
                            office = cand_info.get('office', '')
                            cand_state = cand_info.get('state', '')
                            
                            # Filter 2: Republican only
                            if party != 'REP':
                                skipped_non_rep += 1
                                continue
                            
                            # Filter 3: Presidential OR NC candidate
                            is_presidential = office == 'P'
                            is_nc_candidate = cand_state == 'NC'
                            
                            if not is_presidential and not is_nc_candidate:
                                skipped_non_nc_non_pres += 1
                                continue
                        else:
                            # No linkage found - skip unknown committees
                            skipped_non_rep += 1
                            continue
                        
                        # Parse donor name
                        name_full = fields[7]
                        name_parts = name_full.split(', ')
                        last_name = name_parts[0] if name_parts else ''
                        first_name = name_parts[1].split()[0] if len(name_parts) > 1 else ''
                        
                        # Build record
                        record = {
                            'first_name': first_name[:100],
                            'last_name': last_name[:100],
                            'amount': float(fields[14]) if fields[14] else 0,
                            'date': fields[13],
                            'committee_id': cmte_id,
                            'candidate': cand_id,
                            'candidate_party': party,
                            'candidate_office': office,
                            'candidate_state': cand_state,
                            'employer': fields[11][:200] if len(fields) > 11 else '',
                            'occupation': fields[12][:200] if len(fields) > 12 else '',
                            'address_core_3': f"{fields[8]} {fields[9]} {fields[10]}",
                            'match_method': f'fec_{cycle}'
                        }
                        records.append(record)
                        
                    except Exception as e:
                        continue
    
    print(f'  Skipped non-NC donor: {skipped_non_nc_donor}')
    print(f'  Skipped non-REP: {skipped_non_rep}')
    print(f'  Skipped non-NC non-Pres: {skipped_non_nc_non_pres}')
    print(f'  Skipped excluded cmte: {skipped_excluded_cmte}')
    print(f'  KEPT: {len(records)}')
    return records

if __name__ == '__main__':
    base = '/opt/broyhillgop/data/fec'
    
    # Load reference data
    print('Loading candidate master...')
    candidates = load_candidates(f'{base}/candidate_master.zip')
    
    print('Loading committee linkage...')
    linkage = load_linkage(f'{base}/candidate_committee_linkage.zip')
    
    all_records = []
    
    # Process 2023-2024
    print('\nProcessing FEC 2023-2024...')
    records = filter_fec(f'{base}/FEC-Individual-Donors-2023-2024.zip', candidates, linkage, '2023-2024')
    all_records.extend(records)
    
    # Process 2025-2026
    print('\nProcessing FEC 2025-2026...')
    records = filter_fec(f'{base}/FEC-Individual-Donors-2025-2026.zip', candidates, linkage, '2025-2026')
    all_records.extend(records)
    
    print(f'\n========================================')
    print(f'TOTAL FILTERED RECORDS: {len(all_records)}')
    print(f'========================================')
    
    # Show 10 samples
    print('\nSAMPLE RECORDS (first 10):')
    print('-' * 80)
    for i, r in enumerate(all_records[:10]):
        print(f"{i+1}. {r['first_name']} {r['last_name']} | ${r['amount']} | {r['candidate']} ({r['candidate_party']}) | Office: {r['candidate_office']} | State: {r['candidate_state']}")
    
    # Save to CSV for review
    with open('/opt/broyhillgop/data/fec/filtered_preview.csv', 'w', newline='') as f:
        if all_records:
            writer = csv.DictWriter(f, fieldnames=all_records[0].keys())
            writer.writeheader()
            writer.writerows(all_records[:100])  # Save first 100 for review
    
    print('\nPreview saved to /opt/broyhillgop/data/fec/filtered_preview.csv')
    print('\nWaiting for approval before inserting to database...')
