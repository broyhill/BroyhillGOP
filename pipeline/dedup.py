"""
Dedup engine for the BroyhillGOP pipeline.

Transaction-level dedup key is computed by Postgres (pipeline.dedup_key_fec_individual
and pipeline.dedup_key_ncboe). This module does donor-level identity clustering:
reads pipeline.dedup_rules, exact match on last_name + zip, fuzzy first_name via
dmetaphone, groups into pipeline.identity_clusters. Per Master Plan, this logic
will move into stored procedures and dedup.py will become a thin caller.
See docs/PIPELINE_DEDUP_ARCHITECTURE.md.
"""

from __future__ import annotations

import json
import logging
import uuid
from collections import defaultdict
from dataclasses import dataclass, field

import psycopg2
from psycopg2 import sql

from pipeline.db import get_connection, init_pool

logger = logging.getLogger(__name__)

DEFAULT_WEIGHTS = {"exact": 1.0, "fuzzy": 0.85}
DEFAULT_COLUMNS = {
    "fec": {"last_name": "contributor_last_name", "zip": "contributor_zip", "first_name": "contributor_first_name"},
    "nc_boe": {"last_name": "last_name", "zip": "zip_code", "first_name": "first_name"},
}


@dataclass
class DedupResult:
    """Result of dedup run."""

    passed: bool
    source_system: str
    staging_schema: str
    staging_table: str
    rows_total: int = 0
    rows_matched: int = 0
    rows_remaining: int = 0
    clusters_found: int = 0
    cluster_members_total: int = 0
    summary: str = ""

    def to_report(self) -> str:
        """Human-readable report."""
        return (
            f"Dedup: {self.source_system} -> {self.staging_schema}.{self.staging_table}\n"
            f"Total rows: {self.rows_total}, Matched: {self.rows_matched}, Remaining: {self.rows_remaining}\n"
            f"Clusters found: {self.clusters_found} ({self.cluster_members_total} members)\n"
            f"{self.summary}"
        )


def _resolve_staging_table(source_system: str, cycle: str) -> tuple[str, str]:
    """Return (schema, table_name) for the staging table. Matches ingest.py logic."""
    schema = "staging"
    if source_system.lower() == "fec":
        table = f"fec_{cycle}_a_staging"
    else:
        table = f"{source_system}_{cycle}_staging"
    return schema, table


def _ensure_identity_clusters_table(conn: psycopg2.extensions.connection) -> None:
    """Create pipeline.identity_clusters if it does not exist."""
    with conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS pipeline.identity_clusters (
                cluster_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                source_system TEXT NOT NULL,
                staging_schema TEXT NOT NULL,
                staging_table TEXT NOT NULL,
                cluster_key TEXT NOT NULL,
                member_count INT NOT NULL,
                member_refs JSONB,
                match_score_avg NUMERIC,
                status TEXT DEFAULT 'pending_review',
                created_at TIMESTAMPTZ DEFAULT NOW()
            )
            """
        )


def _fetch_dedup_rule(
    conn: psycopg2.extensions.connection,
    source_system: str,
) -> dict | None:
    """Fetch dedup rule for source system."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT dedup_function_name, notes
            FROM pipeline.dedup_rules
            WHERE source_system = %s
            """,
            (source_system,),
        )
        row = cur.fetchone()
        if not row:
            return None
        notes = row[1] or "{}"
        try:
            config = json.loads(notes) if notes.strip() else {}
        except json.JSONDecodeError:
            config = {}
        return {
            "dedup_function_name": row[0],
            "weights": config.get("weights", DEFAULT_WEIGHTS),
            "columns": config.get("columns") or DEFAULT_COLUMNS.get(source_system.lower(), DEFAULT_COLUMNS["fec"]),
        }


def _fetch_matching_pairs(
    conn: psycopg2.extensions.connection,
    schema: str,
    table: str,
    col_last: str,
    col_zip: str,
    col_first: str,
) -> list[tuple[str, str, float]]:
    """
    Find pairs of rows that match: exact last_name+zip5, fuzzy first_name (dmetaphone).
    Returns list of (ctid_a, ctid_b, score).
    """
    query = sql.SQL("""
        WITH t AS (
            SELECT ctid, {col_last}, {col_zip}, {col_first}
            FROM {tbl}
            WHERE TRIM(COALESCE({col_last}, '')) != ''
              AND TRIM(COALESCE({col_zip}, '')) != ''
        ),
        pairs AS (
            SELECT
                a.ctid::text AS ctid_a,
                b.ctid::text AS ctid_b,
                1.0 AS score
            FROM t a
            JOIN t b ON a.ctid < b.ctid
            WHERE UPPER(TRIM(a.{col_last})) = UPPER(TRIM(b.{col_last}))
              AND COALESCE(SUBSTRING(REGEXP_REPLACE(TRIM(a.{col_zip}), '\\D', '', 'g') FROM 1 FOR 5), '')
                = COALESCE(SUBSTRING(REGEXP_REPLACE(TRIM(b.{col_zip}), '\\D', '', 'g') FROM 1 FOR 5), '')
              AND dmetaphone(COALESCE(TRIM(a.{col_first}), '')) IS NOT NULL
              AND dmetaphone(COALESCE(TRIM(a.{col_first}), '')) != ''
              AND dmetaphone(COALESCE(TRIM(a.{col_first}), ''))
                = dmetaphone(COALESCE(TRIM(b.{col_first}), ''))
        )
        SELECT ctid_a, ctid_b, score FROM pairs
    """).format(
        col_last=sql.Identifier(col_last),
        col_zip=sql.Identifier(col_zip),
        col_first=sql.Identifier(col_first),
        tbl=sql.Identifier(schema, table),
    )
    with conn.cursor() as cur:
        cur.execute(query)
        return [(r[0], r[1], float(r[2])) for r in cur.fetchall()]


def _connected_components(pairs: list[tuple[str, str, float]]) -> list[set[str]]:
    """Build graph from pairs and return connected components (each is a set of ctids)."""
    parent: dict[str, str] = {}

    def find(x: str) -> str:
        if x not in parent:
            parent[x] = x
        if parent[x] != x:
            parent[x] = find(parent[x])
        return parent[x]

    def union(x: str, y: str) -> None:
        px, py = find(x), find(y)
        if px != py:
            parent[px] = py

    for ctid_a, ctid_b, _ in pairs:
        union(ctid_a, ctid_b)

    groups: dict[str, set[str]] = defaultdict(set)
    for node in parent:
        root = find(node)
        groups[root].add(node)

    return list(groups.values())


def _insert_cluster(
    conn: psycopg2.extensions.connection,
    source_system: str,
    schema: str,
    table: str,
    cluster_key: str,
    member_refs: list[str],
    score_avg: float,
) -> uuid.UUID:
    """Insert one cluster into pipeline.identity_clusters. Returns cluster_id."""
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO pipeline.identity_clusters
            (cluster_id, source_system, staging_schema, staging_table, cluster_key, member_count, member_refs, match_score_avg, status)
            VALUES (gen_random_uuid(), %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING cluster_id
            """,
            (source_system, schema, table, cluster_key, len(member_refs), json.dumps(member_refs), score_avg, "pending_review"),
        )
        return cur.fetchone()[0]


def _upsert_identity_pass_log(
    conn: psycopg2.extensions.connection,
    pass_name: str,
    status: str,
    rows_matched: int,
    rows_remaining: int,
) -> None:
    """Insert or update pipeline.identity_pass_log."""
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO pipeline.identity_pass_log (pass_name, status, rows_matched, rows_remaining, last_run_at)
            VALUES (%s, %s, %s, %s, NOW())
            ON CONFLICT (pass_name) DO UPDATE SET
                status = EXCLUDED.status,
                rows_matched = EXCLUDED.rows_matched,
                rows_remaining = EXCLUDED.rows_remaining,
                last_run_at = NOW()
            """,
            (pass_name, status, rows_matched, rows_remaining),
        )


def run_dedup(
    source_system: str,
    *,
    staging_schema: str | None = None,
    staging_table: str | None = None,
    cycle: str | None = None,
    pass_name: str | None = None,
) -> DedupResult:
    """
    Run dedup matching on staging table. Does NOT auto-merge; flags clusters for review.

    Matching: exact on last_name + zip5, fuzzy on first_name via dmetaphone.
    Groups matches into pipeline.identity_clusters with status 'pending_review'.

    Args:
        source_system: Source system (e.g. fec, nc_boe).
        staging_schema: Staging schema. If None, uses cycle.
        staging_table: Staging table. If None, uses cycle.
        cycle: Cycle label. Used when staging_schema/table not given.
        pass_name: Name for identity_pass_log. Default: dedup_{source_system}.

    Returns:
        DedupResult with match counts, clusters found, summary.
    """
    if staging_schema is not None and staging_table is not None:
        schema, table = staging_schema, staging_table
    elif cycle is not None:
        schema, table = _resolve_staging_table(source_system, cycle)
    else:
        raise ValueError("Must provide either (staging_schema, staging_table) or cycle")

    pass_name = pass_name or f"dedup_{source_system}"
    init_pool()
    result = DedupResult(passed=True, source_system=source_system, staging_schema=schema, staging_table=table)

    with get_connection() as conn:
        try:
            _ensure_identity_clusters_table(conn)

            rule = _fetch_dedup_rule(conn, source_system)
            if not rule:
                result.summary = f"No dedup_rules for {source_system}; skipping."
                logger.warning(result.summary)
                _upsert_identity_pass_log(conn, pass_name, "skipped", 0, 0)
                return result

            cols = rule["columns"]
            if isinstance(cols, dict):
                col_last = cols.get("last_name", "contributor_last_name")
                col_zip = cols.get("zip", "contributor_zip")
                col_first = cols.get("first_name", "contributor_first_name")
            else:
                col_last, col_zip, col_first = "contributor_last_name", "contributor_zip", "contributor_first_name"

            with conn.cursor() as cur:
                cur.execute(
                    sql.SQL("SELECT COUNT(*) FROM {t}").format(t=sql.Identifier(schema, table)),
                )
                result.rows_total = cur.fetchone()[0] or 0

            if result.rows_total == 0:
                result.summary = "Staging table is empty."
                _upsert_identity_pass_log(conn, pass_name, "completed", 0, 0)
                return result

            pairs = _fetch_matching_pairs(conn, schema, table, col_last, col_zip, col_first)
            components = _connected_components(pairs)

            all_matched_ctids: set[str] = set()
            for comp in components:
                all_matched_ctids.update(comp)

            result.rows_matched = len(all_matched_ctids)
            result.rows_remaining = result.rows_total - result.rows_matched
            result.clusters_found = len(components)
            result.cluster_members_total = sum(len(c) for c in components)

            weights = rule.get("weights", DEFAULT_WEIGHTS)
            score_avg = weights.get("fuzzy", 0.85)

            for comp in components:
                if len(comp) < 2:
                    continue
                refs = list(comp)
                cluster_key = f"last_zip_{hash(frozenset(refs)) % 10**10}"
                _insert_cluster(conn, source_system, schema, table, cluster_key, refs, score_avg)

            status = "completed"
            result.summary = (
                f"Dedup completed. {result.clusters_found} clusters flagged for review. "
                f"Run pipeline.vw_identity_status to monitor."
            )

            _upsert_identity_pass_log(conn, pass_name, status, result.rows_matched, result.rows_remaining)

            logger.info(
                "Dedup %s: %s rows, %s matched, %s clusters",
                source_system,
                result.rows_total,
                result.rows_matched,
                result.clusters_found,
            )

        except psycopg2.Error as e:
            result.passed = False
            result.summary = str(e)
            logger.exception("Dedup failed: %s", e)
            try:
                _upsert_identity_pass_log(conn, pass_name, "failed", 0, result.rows_total)
            except psycopg2.Error:
                pass
            raise

    return result
