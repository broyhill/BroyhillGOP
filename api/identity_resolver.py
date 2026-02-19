"""
BroyhillGOP E56 Identity Resolution Engine v2
Waterfall: First-Party -> DataTrust -> Fingerprint -> GeoIP -> Anonymous

Correct Supabase schemas:
  visitor_identity_cache: cache_id, candidate_id, fingerprint_hash, ip_hash, email_hash,
    donor_id(uuid), voter_id(varchar), contact_id, household_id, match_type, confidence,
    contact_email, contact_phone, contact_name, contact_address, contact_zip,
    first_seen, last_seen, times_matched, is_valid
  visitors_high_intent_alerts: alert_id, session_id, candidate_id, visitor_id,
    intent_score, resolution_confidence, resolution_method, matched_donor_id,
    contact_name, contact_email, contact_phone, recommended_action, status, ...
  donors: id(int PK), email, first_name, last_name, phone, zip_code, ncid, ...
"""

import os
import json
import asyncio
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict
import httpx
from dotenv import load_dotenv

load_dotenv('/opt/broyhillgop/config/supabase.env')

logging.basicConfig(level=logging.INFO, format='%(asctime)s [E56-Resolver] %(message)s')
logger = logging.getLogger('e56_resolver')

SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://isbgjpnbocdkeslofota.supabase.co')
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_KEY')
DATATRUST_CLIENT_ID = os.getenv('DATATRUST_CLIENT_ID', '')
DATATRUST_CLIENT_SECRET = os.getenv('DATATRUST_CLIENT_SECRET', '')
DATATRUST_API_URL = os.getenv('DATATRUST_API_URL', 'https://rncdhapi.azurewebsites.net')

HEADERS = {
    'apikey': SUPABASE_KEY,
    'Authorization': f'Bearer {SUPABASE_KEY}',
    'Content-Type': 'application/json'
}

_dt_token = None
_dt_token_expires = None


async def sb_get(table, params):
    async with httpx.AsyncClient(timeout=15) as c:
        r = await c.get(f'{SUPABASE_URL}/rest/v1/{table}?{params}', headers=HEADERS)
        if r.status_code == 200:
            return r.json()
        logger.warning(f'sb_get {table} {r.status_code}: {r.text[:200]}')
        return []

async def sb_patch(table, match, data):
    async with httpx.AsyncClient(timeout=15) as c:
        r = await c.patch(
            f'{SUPABASE_URL}/rest/v1/{table}?{match}',
            json=data,
            headers={**HEADERS, 'Prefer': 'return=minimal'}
        )
        if r.status_code not in (200, 204):
            logger.warning(f'sb_patch {table} {r.status_code}: {r.text[:200]}')
        return r.status_code in (200, 204)

async def sb_upsert(table, data):
    async with httpx.AsyncClient(timeout=15) as c:
        r = await c.post(
            f'{SUPABASE_URL}/rest/v1/{table}',
            json=data,
            headers={**HEADERS, 'Prefer': 'resolution=merge-duplicates'}
        )
        if r.status_code not in (200, 201):
            logger.warning(f'sb_upsert {table} {r.status_code}: {r.text[:200]}')
        return r.status_code in (200, 201)

async def sb_insert(table, data):
    async with httpx.AsyncClient(timeout=15) as c:
        r = await c.post(
            f'{SUPABASE_URL}/rest/v1/{table}',
            json=data,
            headers={**HEADERS, 'Prefer': 'return=minimal'}
        )
        if r.status_code not in (200, 201):
            logger.warning(f'sb_insert {table} {r.status_code}: {r.text[:200]}')
        return r.status_code in (200, 201)


# ============================================
# STAGE 1: FIRST-PARTY (95%+)
# ============================================

async def stage1_first_party(session):
    # Check identity cache by fingerprint or IP hash
    fp = session.get('fingerprint_hash')
    ip = session.get('ip_hash')

    if fp:
        cache = await sb_get('visitor_identity_cache',
            f'fingerprint_hash=eq.{fp}&is_valid=eq.true&select=*&limit=1')
        if cache and cache[0].get('donor_id'):
            c = cache[0]
            logger.info(f'  Stage1 HIT: fingerprint cache -> {c.get(contact_email,?)}')
            return {
                'method': 'first_party_fp_cache', 'confidence': 0.95,
                'donor_id': c['donor_id'], 'voter_id': c.get('voter_id'),
                'email': c.get('contact_email'), 'phone': c.get('contact_phone'),
                'name': c.get('contact_name')
            }

    if ip:
        cache = await sb_get('visitor_identity_cache',
            f'ip_hash=eq.{ip}&is_valid=eq.true&select=*&limit=1')
        if cache and cache[0].get('donor_id'):
            c = cache[0]
            logger.info(f'  Stage1 HIT: IP cache -> {c.get(contact_email,?)}')
            return {
                'method': 'first_party_ip_cache', 'confidence': 0.90,
                'donor_id': c['donor_id'], 'voter_id': c.get('voter_id'),
                'email': c.get('contact_email'), 'phone': c.get('contact_phone'),
                'name': c.get('contact_name')
            }

    # Check email tracking ID
    eid = session.get('email_tracking_id')
    if eid:
        donors = await sb_get('donors',
            f'email=eq.{eid}&select=id,email,first_name,last_name,phone,ncid&limit=1')
        if donors:
            d = donors[0]
            name = f'{d.get(first_name,)} {d.get(last_name,)}'.strip()
            logger.info(f'  Stage1 HIT: email tracking -> {d.get(email)}')
            return {
                'method': 'first_party_email', 'confidence': 0.98,
                'donor_id': str(d['id']), 'voter_id': d.get('ncid'),
                'email': d.get('email'), 'phone': d.get('phone'), 'name': name
            }

    logger.info('  Stage1 MISS')
    return None


# ============================================
# STAGE 2: DATATRUST (80%+)
# ============================================

async def get_dt_token():
    global _dt_token, _dt_token_expires
    if _dt_token and _dt_token_expires and datetime.now(timezone.utc) < _dt_token_expires:
        return _dt_token
    if not DATATRUST_CLIENT_ID or not DATATRUST_CLIENT_SECRET:
        return None
    try:
        async with httpx.AsyncClient(timeout=15) as c:
            r = await c.post(f'{DATATRUST_API_URL}/api/Authenticate',
                json={'clientId': DATATRUST_CLIENT_ID, 'clientSecret': DATATRUST_CLIENT_SECRET})
            if r.status_code == 200:
                data = r.json()
                _dt_token = data.get('AccessToken')
                _dt_token_expires = datetime.now(timezone.utc) + timedelta(hours=1)
                logger.info('  DataTrust token acquired')
                return _dt_token
            else:
                logger.warning(f'  DataTrust auth failed: {r.text[:150]}')
    except Exception as e:
        logger.warning(f'  DataTrust error: {e}')
    return None

async def stage2_datatrust(session):
    token = await get_dt_token()
    if not token:
        logger.info('  Stage2 SKIP: DataTrust unavailable')
        return None
    # When API restored, query voters by geo/IP
    logger.info('  Stage2 MISS: DataTrust query not yet implemented')
    return None


# ============================================
# STAGE 3: FINGERPRINT CROSS-REF (75%+)
# ============================================

async def stage3_fingerprint(session):
    fp = session.get('fingerprint_hash')
    if not fp:
        logger.info('  Stage3 SKIP: no fingerprint')
        return None

    resolved = await sb_get('visitor_sessions',
        f'fingerprint_hash=eq.{fp}&resolution_status=eq.resolved&select=matched_donor_id,matched_voter_id,resolved_email,resolved_phone,resolved_name&limit=1')

    if resolved and resolved[0].get('matched_donor_id'):
        r = resolved[0]
        logger.info(f'  Stage3 HIT: fp crossref -> {r.get(resolved_email,?)}')
        return {
            'method': 'fingerprint_crossref', 'confidence': 0.75,
            'donor_id': r['matched_donor_id'], 'voter_id': r.get('matched_voter_id'),
            'email': r.get('resolved_email'), 'phone': r.get('resolved_phone'),
            'name': r.get('resolved_name')
        }

    logger.info('  Stage3 MISS')
    return None


# ============================================
# STAGE 4: GEO MATCH (60%+)
# ============================================

async def stage4_geo(session):
    geo_zip = session.get('geo_zip')
    geo_state = session.get('geo_state')

    if not geo_zip:
        logger.info('  Stage4 SKIP: no geo data')
        return None
    if geo_state and geo_state not in ('NC', 'North Carolina'):
        logger.info(f'  Stage4 SKIP: out of state ({geo_state})')
        return None

    donors = await sb_get('donors',
        f'zip_code=eq.{geo_zip}&email=neq.null&select=id,email,first_name,last_name,phone,ncid&limit=5')

    if donors:
        d = donors[0]
        name = f'{d.get(first_name,)} {d.get(last_name,)}'.strip()
        logger.info(f'  Stage4 HIT: geo zip {geo_zip} -> {d.get(email,?)}')
        return {
            'method': 'geo_probabilistic', 'confidence': 0.60,
            'donor_id': str(d['id']), 'voter_id': d.get('ncid'),
            'email': d.get('email'), 'phone': d.get('phone'), 'name': name
        }

    logger.info('  Stage4 MISS')
    return None


# ============================================
# STAGE 5: ANONYMOUS
# ============================================

async def stage5_anonymous(session):
    logger.info('  Stage5: anonymous')
    return {
        'method': 'anonymous', 'confidence': 0.0,
        'donor_id': None, 'voter_id': None,
        'email': None, 'phone': None, 'name': None
    }


# ============================================
# WATERFALL
# ============================================

async def resolve_visitor(session):
    sid = session['session_id']
    logger.info(f'Resolving {sid[:8]}...')

    result = await stage1_first_party(session)
    if result and result['confidence'] >= 0.90:
        return result

    result = await stage2_datatrust(session)
    if result and result['confidence'] >= 0.75:
        return result

    result = await stage3_fingerprint(session)
    if result and result['confidence'] >= 0.70:
        return result

    result = await stage4_geo(session)
    if result and result['confidence'] >= 0.50:
        return result

    return await stage5_anonymous(session)


# ============================================
# WORKER
# ============================================

def get_action(score, confidence):
    if score >= 80 and confidence >= 0.90:
        return 'immediate_outreach'
    if score >= 80 and confidence >= 0.70:
        return 'same_day_outreach'
    if score >= 60 and confidence >= 0.80:
        return 'same_day_outreach'
    if score >= 60:
        return 'add_to_nurture'
    if score >= 40:
        return 'monitor'
    return 'ignore'

async def process_pending():
    sessions = await sb_get('visitor_sessions',
        'resolution_status=eq.pending&order=created_at.desc&limit=50&select=*')
    if not sessions:
        return 0

    logger.info(f'Processing {len(sessions)} pending...')
    count = 0

    for s in sessions:
        try:
            sid = s['session_id']
            result = await resolve_visitor(s)

            now = datetime.now(timezone.utc).isoformat()
            status = 'resolved' if result['confidence'] > 0 else 'anonymous'

            ok = await sb_patch('visitor_sessions', f'session_id=eq.{sid}', {
                'resolution_status': status,
                'resolution_method': result['method'],
                'resolution_confidence': result['confidence'],
                'matched_donor_id': result.get('donor_id'),
                'matched_voter_id': result.get('voter_id'),
                'resolved_email': result.get('email'),
                'resolved_phone': result.get('phone'),
                'resolved_name': result.get('name'),
                'updated_at': now
            })

            if not ok:
                logger.error(f'  Failed to update session {sid[:8]}')
                continue

            # Update identity cache (keyed on fingerprint_hash or ip_hash)
            if result['confidence'] > 0:
                cache_data = {
                    'candidate_id': s.get('candidate_id'),
                    'fingerprint_hash': s.get('fingerprint_hash'),
                    'ip_hash': s.get('ip_hash'),
                    'donor_id': result.get('donor_id'),
                    'voter_id': result.get('voter_id'),
                    'match_type': result['method'],
                    'confidence': result['confidence'],
                    'contact_email': result.get('email'),
                    'contact_phone': result.get('phone'),
                    'contact_name': result.get('name'),
                    'last_seen': now,
                    'is_valid': True
                }
                await sb_insert('visitor_identity_cache', cache_data)

            # High intent alert
            intent = s.get('adjusted_intent_score', 0)
            if intent >= 60 and result['confidence'] >= 0.60 and result.get('donor_id'):
                alert = {
                    'session_id': sid,
                    'candidate_id': s.get('candidate_id'),
                    'visitor_id': s.get('visitor_id'),
                    'intent_score': intent,
                    'resolution_confidence': result['confidence'],
                    'resolution_method': result['method'],
                    'matched_donor_id': result.get('donor_id'),
                    'contact_name': result.get('name'),
                    'contact_email': result.get('email'),
                    'contact_phone': result.get('phone'),
                    'high_intent_pages': s.get('high_intent_pages_visited'),
                    'session_duration_seconds': s.get('time_on_site_seconds', 0),
                    'page_views': s.get('page_views', 0),
                    'recommended_action': get_action(intent, result['confidence']),
                    'status': 'pending'
                }
                await sb_insert('visitor_high_intent_alerts', alert)
                logger.info(f'  ALERT fired for {sid[:8]} -> {result.get(email,?)}')

            count += 1
        except Exception as e:
            logger.error(f'  Error on {s.get(session_id,?)[:8]}: {e}')

    logger.info(f'Resolved {count}/{len(sessions)}')
    return count


async def main():
    logger.info('E56 Identity Resolution Engine v2 starting...')
    logger.info(f'Supabase: {SUPABASE_URL}')
    logger.info(f'DataTrust configured: {bool(DATATRUST_CLIENT_ID)}')
    logger.info(f'Donors table: 1.2M+ records available for matching')

    while True:
        try:
            n = await process_pending()
            if n > 0:
                logger.info(f'Cycle: {n} resolved')
            await asyncio.sleep(10)
        except KeyboardInterrupt:
            break
        except Exception as e:
            logger.error(f'Worker error: {e}')
            await asyncio.sleep(30)


if __name__ == '__main__':
    asyncio.run(main())
