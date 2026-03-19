"""
NC BOE Norm ETL — Populate norm columns on nc_boe_donations_raw.

Per General Fund Ingestion and NC BOE pipeline:
- All transaction types stay in nc_boe_donations_raw (no routing to committee_transfers)
- Person types (Individual, General): name parse, address normalize, employer, dedup
- Org types (Non-Party Comm, Cont to Other Comm, Party Comm, Coord Party Exp):
  is_organization=true, donor_type=transaction_type, norm_last=donor_name
- Seed core.ncboe_committee_registry from distinct committees

Uses fn_normalize_donor_name() (DB function) for name parsing — NOT pipeline.parse_ncboe_name
(which only uppercases; does not parse first/last/canonical). Also: pipeline.employer_normalize(),
pipeline.content_hash_ncboe(), pipeline.dedup_key_ncboe(). Does NOT touch nc_voters (Phase 2).
"""

from __future__ import annotations

import logging

import psycopg2

from pipeline.db import get_connection, init_pool

logger = logging.getLogger(__name__)

# Person types: parse name, address, employer
PERSON_TYPES = ("Individual", "General")
# Org types: set is_organization=true, norm_last=donor_name
ORG_TYPES = (
    "Non-Party Comm",
    "Cont to Other Comm",
    "Party Comm",
    "Coord Party Exp",
)


def run_norm_etl_ncboe() -> dict:
    """
    Run full NC BOE norm ETL on public.nc_boe_donations_raw.

    Returns:
        Dict with rows_updated, committees_seeded, errors.
    """
    init_pool()
    result = {
        "rows_updated": 0,
        "committees_seeded": 0,
        "errors": [],
    }

    with get_connection() as conn:
        conn.autocommit = False
        try:
            # 1. Set donor_type and is_organization for org types
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE public.nc_boe_donations_raw
                    SET donor_type = transaction_type,
                        is_organization = true,
                        norm_last = UPPER(TRIM(COALESCE(donor_name, '')))
                    WHERE transaction_type IN %s
                    """,
                    (ORG_TYPES,),
                )
                logger.info("Set is_organization for %s org rows", cur.rowcount)

            # 2. Person types: norm_last, norm_first, canonical_first from fn_normalize_donor_name
            # (NOT pipeline.parse_ncboe_name — it only uppercases, does not parse)
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE public.nc_boe_donations_raw d
                    SET
                      norm_last = n.last_name,
                      norm_first = n.first_name,
                      canonical_first = COALESCE(n.canonical_first_name, n.first_name),
                      name_suffix = n.suffix
                    FROM LATERAL (
                      SELECT fn_normalize_donor_name(d.donor_name) AS fn
                    ) f,
                    LATERAL (
                      SELECT (f.fn).last_name, (f.fn).first_name,
                             (f.fn).canonical_first_name, (f.fn).suffix
                    ) n(last_name, first_name, canonical_first_name, suffix)
                    WHERE d.transaction_type IN %s
                    """,
                    (PERSON_TYPES,),
                )
                result["rows_updated"] = cur.rowcount
            conn.commit()
            logger.info("Updated norm_last, norm_first, canonical_first for %s person rows", result["rows_updated"])

            # 3. Address normalize: norm_zip5, norm_addr, norm_city, norm_state, street_number, address_block_key (person + org)
            # street_number: PO Box number or leading digits from street_line_1 (Eddie's rule)
            # address_block_key: md5(street_number|norm_last|norm_zip5) for same-address blocks
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE public.nc_boe_donations_raw
                    SET
                        norm_zip5 = SUBSTRING(REGEXP_REPLACE(COALESCE(TRIM(zip_code), ''), '\\D', '', 'g') FROM 1 FOR 5),
                        norm_addr = UPPER(TRIM(REGEXP_REPLACE(COALESCE(street_line_1, ''), '\\s*(APT|SUITE|#|UNIT).*$', '', 'i'))),
                        norm_city = UPPER(TRIM(COALESCE(city, ''))),
                        norm_state = UPPER(TRIM(COALESCE(state, ''))),
                        street_number = COALESCE(
                            (regexp_match(UPPER(TRIM(COALESCE(street_line_1, ''))), 'P\\.?O\\.?\\s*BOX\\s*(\\d+)'))[1],
                            (regexp_match(TRIM(COALESCE(street_line_1, '')), '^(\\d+[A-Z]?)\\s'))[1]
                        ),
                        address_block_key = CASE
                            WHEN norm_last IS NOT NULL
                                 AND SUBSTRING(REGEXP_REPLACE(COALESCE(TRIM(zip_code), ''), '\\D', '', 'g') FROM 1 FOR 5) ~ '^[0-9]{5}$'
                                 AND (
                                    (regexp_match(UPPER(TRIM(COALESCE(street_line_1, ''))), 'P\\.?O\\.?\\s*BOX\\s*(\\d+)'))[1] IS NOT NULL
                                    OR (regexp_match(TRIM(COALESCE(street_line_1, '')), '^(\\d+[A-Z]?)\\s'))[1] IS NOT NULL
                                 )
                            THEN md5(
                                COALESCE(COALESCE(
                                    (regexp_match(UPPER(TRIM(COALESCE(street_line_1, ''))), 'P\\.?O\\.?\\s*BOX\\s*(\\d+)'))[1],
                                    (regexp_match(TRIM(COALESCE(street_line_1, '')), '^(\\d+[A-Z]?)\\s'))[1]
                                ), '') || '|' || COALESCE(norm_last, '') || '|' ||
                                SUBSTRING(REGEXP_REPLACE(COALESCE(TRIM(zip_code), ''), '\\D', '', 'g') FROM 1 FOR 5)
                            )
                            ELSE NULL
                        END
                    WHERE transaction_type IN %s OR transaction_type IN %s
                    """,
                    (PERSON_TYPES, ORG_TYPES),
                )
                logger.info("Address normalized for person and org rows")

            # 4. Employer normalize (person types only)
            with conn.cursor() as cur:
                cur.execute(
                    "ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS employer_normalized TEXT"
                )
                cur.execute(
                    """
                    UPDATE public.nc_boe_donations_raw
                    SET employer_normalized = pipeline.employer_normalize(employer_name)
                    WHERE transaction_type IN %s AND employer_name IS NOT NULL
                    """,
                    (PERSON_TYPES,),
                )
            conn.commit()

            # 5. Fallback canonical_first = norm_first where fn_normalize returned NULL
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE public.nc_boe_donations_raw
                    SET canonical_first = norm_first
                    WHERE transaction_type IN %s AND canonical_first IS NULL AND norm_first IS NOT NULL
                    """,
                    (PERSON_TYPES,),
                )
            conn.commit()

            # 6. Committee type from committee_sboe_id (all rows)
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE public.nc_boe_donations_raw
                    SET committee_type = SPLIT_PART(committee_sboe_id, '-', 3)
                    WHERE committee_sboe_id IS NOT NULL AND committee_sboe_id != ''
                    """
                )
            conn.commit()

            # 7. content_hash (person types: norm_last, canonical_first, norm_zip5; org: norm_last, '', norm_zip5)
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE public.nc_boe_donations_raw
                    SET content_hash = pipeline.content_hash_ncboe(
                        norm_last,
                        COALESCE(canonical_first, ''),
                        COALESCE(norm_zip5, ''),
                        date_occurred,
                        amount_numeric
                    )
                    WHERE content_hash IS NULL
                      AND norm_last IS NOT NULL
                      AND date_occurred IS NOT NULL
                      AND amount_numeric IS NOT NULL
                    """
                )
            conn.commit()

            # 8. Dedup key (content_hash || id)
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT column_name FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = 'nc_boe_donations_raw'
                    AND column_name = 'dedup_key'
                    """
                )
                has_dedup_key = cur.fetchone() is not None
            if not has_dedup_key:
                with conn.cursor() as cur:
                    cur.execute(
                        "ALTER TABLE public.nc_boe_donations_raw ADD COLUMN IF NOT EXISTS dedup_key TEXT"
                    )
                conn.commit()
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE public.nc_boe_donations_raw
                    SET dedup_key = pipeline.dedup_key_ncboe(content_hash, id::text)
                    WHERE dedup_key IS NULL AND content_hash IS NOT NULL
                    """
                )
            conn.commit()

            # 9. Seed core.ncboe_committee_registry (match DDL: first_seen_year, last_seen_year)
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO core.ncboe_committee_registry (
                        committee_sboe_id, committee_name, committee_type,
                        first_seen_year, last_seen_year
                    )
                    SELECT
                        committee_sboe_id,
                        (array_agg(committee_name ORDER BY date_occurred DESC NULLS LAST))[1],
                        (array_agg(committee_type ORDER BY date_occurred DESC NULLS LAST))[1],
                        MIN(EXTRACT(YEAR FROM date_occurred))::INT,
                        MAX(EXTRACT(YEAR FROM date_occurred))::INT
                    FROM public.nc_boe_donations_raw
                    WHERE committee_sboe_id IS NOT NULL AND committee_sboe_id != ''
                      AND date_occurred IS NOT NULL
                    GROUP BY committee_sboe_id
                    ON CONFLICT (committee_sboe_id) DO UPDATE SET
                        committee_name = COALESCE(EXCLUDED.committee_name, core.ncboe_committee_registry.committee_name),
                        last_seen_year = GREATEST(core.ncboe_committee_registry.last_seen_year, EXCLUDED.last_seen_year),
                        updated_at = now()
                    """
                )
                result["committees_seeded"] = cur.rowcount
            conn.commit()
            logger.info("Seeded %s committees into core.ncboe_committee_registry", result["committees_seeded"])

        except psycopg2.Error as e:
            result["errors"].append(str(e))
            conn.rollback()
            logger.exception("NC BOE norm ETL failed: %s", e)
            raise

    return result
