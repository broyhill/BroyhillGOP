"""
Ingestion orchestrator for the BroyhillGOP pipeline.

Accepts a source file path, source_system, and cycle label. Computes file hash,
creates manifest and job records, reads file in chunks, validates against
source_quality_rules, logs errors to ingestion_errors, and inserts clean rows
into the staging table. Supports dry_run (Master Plan §9), dollar reconciliation
(§4.2), and audit columns _job_id, _batch_number, _loaded_at, _file_hash (§4.7).
"""

from __future__ import annotations

import hashlib
import json
import logging
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import pandas as pd
import psycopg2
from psycopg2 import sql

from pipeline.db import get_connection, init_pool

logger = logging.getLogger(__name__)

DEFAULT_CHUNK_SIZE = 10_000

# Audit column names (Master Plan 4.7); only used if present on staging table
AUDIT_COLUMNS = ("_job_id", "_batch_number", "_loaded_at", "_file_hash")

# Default amount column for dollar reconciliation (FEC)
DEFAULT_AMOUNT_COLUMN = "contribution_receipt_amount"


def _compute_file_sha256(file_path: Path) -> str:
    """Compute SHA-256 hash of file contents."""
    sha = hashlib.sha256()
    with open(file_path, "rb") as f:
        for block in iter(lambda: f.read(65536), b""):
            sha.update(block)
    return sha.hexdigest()


def _get_staging_table_columns(conn: psycopg2.extensions.connection, schema: str, table: str) -> list[str]:
    """Return column names for staging table, in order."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = %s AND table_name = %s
            ORDER BY ordinal_position
            """,
            (schema, table),
        )
        return [r[0] for r in cur.fetchall()]


def _resolve_staging_table(source_system: str, cycle: str) -> tuple[str, str]:
    """Return (schema, table_name) for the staging table."""
    schema = "staging"
    # FEC: fec_2015_2016 -> fec_2015_2016_a_staging
    if source_system.lower() == "fec":
        table = f"fec_{cycle}_a_staging"
    else:
        table = f"{source_system}_{cycle}_staging"
    return schema, table


def _fetch_quality_rules(conn: psycopg2.extensions.connection, source_system: str) -> list[dict[str, Any]]:
    """Fetch source_quality_rules for the source system."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT rule_name, rule_sql_condition, severity, description
            FROM pipeline.source_quality_rules
            WHERE source_system = %s
            """,
            (source_system,),
        )
        return [
            {
                "rule_name": r[0],
                "rule_sql_condition": r[1],
                "severity": r[2],
                "description": r[3] or "",
            }
            for r in cur.fetchall()
        ]


def _run_quality_rule(
    conn: psycopg2.extensions.connection,
    rule: dict[str, Any],
    schema: str,
    table: str,
) -> int:
    """Run a quality rule query against the staging table. Returns count from query."""
    cond = rule.get("rule_sql_condition")
    if not cond:
        return 0
    try:
        if "{staging_table}" in cond:
            query = sql.SQL(cond).format(staging_table=sql.Identifier(schema, table))
        else:
            query = sql.SQL(cond)
        with conn.cursor() as cur:
            cur.execute(query)
            row = cur.fetchone()
            return int(row[0]) if row else 0
    except Exception as e:
        logger.warning("Quality rule %s failed to execute: %s", rule["rule_name"], e)
        return -1


def _insert_file_manifest(
    conn: psycopg2.extensions.connection,
    source_system: str,
    file_path: str,
    file_hash: str,
    row_count: int,
    amount_total: float | None = None,
    *,
    status: str = "loading",
) -> uuid.UUID:
    """Insert file_manifest row and return manifest_id. status='draft' for dry_run."""
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO pipeline.file_manifest
            (manifest_id, source_system, file_pattern, expected_row_count, expected_amount_total, status)
            VALUES (gen_random_uuid(), %s, %s, %s, %s, %s)
            RETURNING manifest_id
            """,
            (source_system, file_path, row_count, amount_total, status),
        )
        return cur.fetchone()[0]


def _insert_ingestion_job(
    conn: psycopg2.extensions.connection,
    manifest_id: uuid.UUID,
    source_system: str,
    file_path: str,
    file_hash: str,
    file_size: int,
    row_count: int,
    *,
    status: str = "running",
) -> uuid.UUID:
    """Insert ingestion_jobs row and return job_id. status='dry_run' for dry_run."""
    job_type = f"ingest_{source_system}"
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO pipeline.ingestion_jobs
            (job_id, job_type, source_system, file_path, file_hash_sha256,
             file_size_bytes, row_count_estimate, status, manifest_id, started_at)
            VALUES (gen_random_uuid(), %s, %s, %s, %s, %s, %s, %s, %s, NOW())
            RETURNING job_id
            """,
            (job_type, source_system, file_path, file_hash, file_size, row_count, status, manifest_id),
        )
        return cur.fetchone()[0]


def _insert_ingestion_batch(
    conn: psycopg2.extensions.connection,
    job_id: uuid.UUID,
    batch_number: int,
    offset_start: int,
    offset_end: int,
) -> uuid.UUID:
    """Insert ingestion_batches row and return batch_id."""
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO pipeline.ingestion_batches
            (batch_id, job_id, batch_number, offset_start, offset_end, status, started_at)
            VALUES (gen_random_uuid(), %s, %s, %s, %s, %s, NOW())
            RETURNING batch_id
            """,
            (job_id, batch_number, offset_start, offset_end, "running"),
        )
        return cur.fetchone()[0]


def _log_ingestion_error(
    conn: psycopg2.extensions.connection,
    job_id: uuid.UUID,
    batch_id: uuid.UUID,
    row_offset: int,
    error_type: str,
    error_message: str,
    sample_data: dict | None = None,
) -> None:
    """Insert row into ingestion_errors."""
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO pipeline.ingestion_errors
            (job_id, batch_id, row_offset, error_type, error_message, sample_data)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (job_id, batch_id, row_offset, error_type, error_message, json.dumps(sample_data) if sample_data else None),
        )


def _insert_chunk_into_staging(
    conn: psycopg2.extensions.connection,
    schema: str,
    table: str,
    columns: list[str],
    df: pd.DataFrame,
    *,
    job_id: uuid.UUID | None = None,
    batch_number: int | None = None,
    loaded_at: datetime | None = None,
    file_hash: str | None = None,
) -> int:
    """Insert DataFrame chunk into staging table. Returns rows inserted.
    If staging table has audit columns (_job_id, _batch_number, _loaded_at, _file_hash),
    only those present in columns are populated (Master Plan 4.7).
    """
    if df.empty:
        return 0
    file_cols = [c for c in columns if c in df.columns and c not in AUDIT_COLUMNS]
    audit_cols = [c for c in AUDIT_COLUMNS if c in columns]
    insert_cols = file_cols + audit_cols
    if not insert_cols:
        insert_cols = [c for c in columns if c in df.columns]
    aligned = df.reindex(columns=file_cols if file_cols else list(df.columns), fill_value=None)
    rows: list[tuple[Any, ...]] = []
    for _, row in aligned.iterrows():
        tup: list[Any] = list(row.values)
        for ac in audit_cols:
            if ac == "_job_id":
                tup.append(str(job_id) if job_id else None)
            elif ac == "_batch_number":
                tup.append(batch_number)
            elif ac == "_loaded_at":
                tup.append(loaded_at)
            elif ac == "_file_hash":
                tup.append(file_hash)
        rows.append(tuple(tup))
    if not rows:
        return 0
    query = sql.SQL("INSERT INTO {t} ({c}) VALUES ({p})").format(
        t=sql.Identifier(schema, table),
        c=sql.SQL(", ").join(sql.Identifier(col) for col in insert_cols),
        p=sql.SQL(", ").join(sql.Placeholder() for _ in insert_cols),
    )
    with conn.cursor() as cur:
        cur.executemany(query, rows)
        return cur.rowcount


def _sum_amount_in_batch(
    conn: psycopg2.extensions.connection,
    schema: str,
    table: str,
    amount_column: str,
    job_id: uuid.UUID,
    batch_number: int,
) -> float:
    """Sum amount_column for rows with _job_id and _batch_number. Returns 0 if no such columns."""
    with conn.cursor() as cur:
        cur.execute(
            sql.SQL("SELECT COALESCE(SUM({ac}), 0) FROM {t} WHERE _job_id = %s AND _batch_number = %s").format(
                ac=sql.Identifier(amount_column),
                t=sql.Identifier(schema, table),
            ),
            (str(job_id), batch_number),
        )
        row = cur.fetchone()
        return float(row[0] or 0)


def _sum_amount_for_job(
    conn: psycopg2.extensions.connection,
    schema: str,
    table: str,
    amount_column: str,
    job_id: uuid.UUID,
) -> float:
    """Sum amount_column for rows with _job_id. Returns 0 if _job_id not present."""
    with conn.cursor() as cur:
        cur.execute(
            sql.SQL("SELECT COALESCE(SUM({ac}), 0) FROM {t} WHERE _job_id = %s").format(
                ac=sql.Identifier(amount_column),
                t=sql.Identifier(schema, table),
            ),
            (str(job_id),),
        )
        row = cur.fetchone()
        return float(row[0] or 0)


def run_ingest(
    file_path: str | Path,
    source_system: str,
    cycle: str,
    chunk_size: int = DEFAULT_CHUNK_SIZE,
    *,
    dry_run: bool = False,
    staging_schema: str | None = None,
    staging_table: str | None = None,
    amount_column: str = DEFAULT_AMOUNT_COLUMN,
) -> dict[str, Any]:
    """
    Run the full ingestion workflow (Master Plan §4.2, §9).

    Args:
        file_path: Path to source CSV file
        source_system: Source system name (e.g. fec, nc_boe)
        cycle: Cycle label (e.g. 2015_2016)
        chunk_size: Rows per chunk (default 10,000)
        dry_run: If True, validate file, compute row count and dollar total,
            write file_manifest with status=draft, commit nothing to staging (§9).
        staging_schema: Override staging schema (default from source_system/cycle).
        staging_table: Override staging table name.
        amount_column: Column name for dollar reconciliation (default contribution_receipt_amount).

    Returns:
        Dict with job_id, manifest_id, rows_inserted, batches_completed, errors_count,
        amount_total (from file), dry_run (bool).
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"Source file not found: {path}")

    init_pool()
    schema = staging_schema if staging_schema is not None else _resolve_staging_table(source_system, cycle)[0]
    table = staging_table if staging_table is not None else _resolve_staging_table(source_system, cycle)[1]

    result: dict[str, Any] = {
        "job_id": None,
        "manifest_id": None,
        "rows_inserted": 0,
        "batches_completed": 0,
        "errors_count": 0,
        "amount_total": None,
        "dry_run": dry_run,
    }

    with get_connection() as conn:
        try:
            file_hash = _compute_file_sha256(path)
            file_size = path.stat().st_size

            if not dry_run:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        SELECT job_id FROM pipeline.ingestion_jobs
                        WHERE file_hash_sha256 = %s AND status = 'completed'
                        """,
                        (file_hash,),
                    )
                    if cur.fetchone():
                        raise ValueError(f"File already loaded (hash {file_hash[:16]}...)")

            # Compute row count and amount total from file (one pass)
            row_count = 0
            amount_total_file = 0.0
            for chunk in pd.read_csv(path, chunksize=chunk_size):
                row_count += len(chunk)
                if amount_column in chunk.columns:
                    try:
                        amount_total_file += chunk[amount_column].fillna(0).astype(float).sum()
                    except (TypeError, ValueError):
                        pass
            result["amount_total"] = amount_total_file

            if dry_run:
                manifest_id = _insert_file_manifest(
                    conn, source_system, str(path), file_hash, row_count, amount_total_file, status="draft"
                )
                job_id = _insert_ingestion_job(
                    conn, manifest_id, source_system, str(path), file_hash, file_size, row_count, status="dry_run"
                )
                conn.commit()
                result["job_id"] = str(job_id)
                result["manifest_id"] = str(manifest_id)
                result["expected_row_count"] = row_count
                logger.info("Dry run: rows=%s, amount_total=%s, manifest_id=%s", row_count, amount_total_file, manifest_id)
                return result

            manifest_id = _insert_file_manifest(
                conn, source_system, str(path), file_hash, row_count, amount_total_file
            )
            job_id = _insert_ingestion_job(conn, manifest_id, source_system, str(path), file_hash, file_size, row_count)
            result["manifest_id"] = str(manifest_id)
            result["job_id"] = str(job_id)

            columns = _get_staging_table_columns(conn, schema, table)
            if not columns:
                raise ValueError(f"Staging table {schema}.{table} not found or has no columns")
            has_audit = "_job_id" in columns and "_batch_number" in columns
            if not has_audit:
                logger.warning("Staging table has no _job_id/_batch_number; skipping per-batch and full-file dollar reconciliation")

            quality_rules = _fetch_quality_rules(conn, source_system)
            loaded_at = datetime.now(timezone.utc)

            offset_start = 0
            batch_number = 0
            amount_sum_db_total = 0.0

            for chunk in pd.read_csv(path, chunksize=chunk_size):
                batch_number += 1
                offset_end = offset_start + len(chunk)
                chunk_amount = 0.0
                if amount_column in chunk.columns:
                    try:
                        chunk_amount = float(chunk[amount_column].fillna(0).astype(float).sum())
                    except (TypeError, ValueError):
                        pass

                batch_id = _insert_ingestion_batch(conn, job_id, batch_number, offset_start, offset_end)

                try:
                    rows_inserted = _insert_chunk_into_staging(
                        conn,
                        schema,
                        table,
                        columns,
                        chunk,
                        job_id=job_id,
                        batch_number=batch_number,
                        loaded_at=loaded_at,
                        file_hash=file_hash,
                    )

                    fatal_failed = False
                    for rule in quality_rules:
                        cnt = _run_quality_rule(conn, rule, schema, table)
                        if cnt < 0:
                            continue
                        if cnt > 0:
                            _log_ingestion_error(
                                conn,
                                job_id,
                                batch_id,
                                offset_start,
                                "quality_rule_failed",
                                f"Rule {rule['rule_name']}: {cnt} rows violated. {rule['description']}",
                                {"rule_name": rule["rule_name"], "count": cnt},
                            )
                            result["errors_count"] += 1
                            if rule.get("severity") == "fatal":
                                conn.rollback()
                                fatal_failed = True
                                break

                    if fatal_failed:
                        logger.warning("Fatal quality rule failed for batch %s; batch rolled back", batch_number)
                        with conn.cursor() as cur:
                            cur.execute(
                                """
                                UPDATE pipeline.ingestion_batches
                                SET status = %s, error_message = %s, finished_at = NOW()
                                WHERE batch_id = %s
                                """,
                                ("failed", "Fatal quality rule violated", batch_id),
                            )
                        conn.commit()
                        continue

                    # Dollar reconciliation per batch (Master Plan 4.2)
                    batch_amount_db = chunk_amount  # used for batch row and total
                    if has_audit and amount_column in columns:
                        batch_amount_db = _sum_amount_in_batch(conn, schema, table, amount_column, job_id, batch_number)
                        if round(batch_amount_db, 2) != round(chunk_amount, 2):
                            _log_ingestion_error(
                                conn, job_id, batch_id, offset_start, "amount_mismatch",
                                f"Batch sum file={chunk_amount} db={batch_amount_db}",
                                {"chunk_amount": chunk_amount, "batch_amount_db": batch_amount_db},
                            )
                            result["errors_count"] += 1
                            conn.rollback()
                            with conn.cursor() as cur:
                                cur.execute(
                                    """
                                    UPDATE pipeline.ingestion_batches
                                    SET status = %s, error_message = %s, amount_sum_file = %s, amount_sum_db = %s, finished_at = NOW()
                                    WHERE batch_id = %s
                                    """,
                                    ("failed", "Dollar reconciliation failed", chunk_amount, batch_amount_db, batch_id),
                                )
                            conn.commit()
                            continue
                        amount_sum_db_total += batch_amount_db
                    else:
                        amount_sum_db_total += chunk_amount

                    conn.commit()

                    with conn.cursor() as cur:
                        cur.execute(
                            """
                            UPDATE pipeline.ingestion_batches
                            SET status = %s, rows_read = %s, rows_inserted = %s, amount_sum_file = %s, amount_sum_db = %s, finished_at = NOW()
                            WHERE batch_id = %s
                            """,
                            ("completed", len(chunk), rows_inserted, chunk_amount, batch_amount_db, batch_id),
                        )
                    conn.commit()
                    result["rows_inserted"] += rows_inserted
                    result["batches_completed"] += 1

                except Exception as e:
                    _log_ingestion_error(conn, job_id, batch_id, offset_start, "insert_error", str(e))
                    result["errors_count"] += 1
                    with conn.cursor() as cur:
                        cur.execute(
                            """
                            UPDATE pipeline.ingestion_batches
                            SET status = %s, error_message = %s, finished_at = NOW()
                            WHERE batch_id = %s
                            """,
                            ("failed", str(e), batch_id),
                        )
                    conn.commit()
                    logger.exception("Batch %s failed: %s", batch_number, e)

                offset_start = offset_end

            # Full-file dollar reconciliation (Master Plan 4.2)
            if has_audit and amount_column in columns and result["errors_count"] == 0:
                job_amount_db = _sum_amount_for_job(conn, schema, table, amount_column, job_id)
                if round(job_amount_db, 2) != round(amount_total_file, 2):
                    with conn.cursor() as cur:
                        cur.execute(
                            """
                            UPDATE pipeline.ingestion_jobs
                            SET status = %s, last_error = %s, finished_at = NOW()
                            WHERE job_id = %s
                            """,
                            ("failed", f"Full-file dollar mismatch: file={amount_total_file} db={job_amount_db}", job_id),
                        )
                    conn.commit()
                    raise ValueError(f"Full-file dollar reconciliation failed: file={amount_total_file} db={job_amount_db}")

            # Final job status
            status = "completed" if result["errors_count"] == 0 else "completed_with_warnings"
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE pipeline.ingestion_jobs
                    SET status = %s, finished_at = NOW(), row_count_estimate = %s
                    WHERE job_id = %s
                    """,
                    (status, result["rows_inserted"], job_id),
                )
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE pipeline.file_manifest
                    SET status = %s, expected_row_count = %s, expected_amount_total = %s
                    WHERE manifest_id = %s
                    """,
                    ("completed", result["rows_inserted"], amount_sum_db_total, manifest_id),
                )

        except Exception as e:
            logger.exception("Ingestion failed: %s", e)
            if result.get("job_id"):
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        UPDATE pipeline.ingestion_jobs
                        SET status = %s, last_error = %s, finished_at = NOW()
                        WHERE job_id = %s
                        """,
                        ("failed", str(e), result["job_id"]),
                    )
            raise

    logger.info(
        "Ingestion complete: job_id=%s, rows=%s, batches=%s, errors=%s",
        result["job_id"],
        result["rows_inserted"],
        result["batches_completed"],
        result["errors_count"],
    )
    return result
