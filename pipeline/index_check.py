"""
Index verifier for the BroyhillGOP pipeline.

Reads pipeline.expected_indexes for all registered indexes. Checks pg_indexes
to see which exist and which are missing. Creates any missing indexes using
the stored index definition (index_definition column). Returns IndexCheckResult
with created/existing/failed counts.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

import psycopg2

from pipeline.db import get_connection, init_pool

logger = logging.getLogger(__name__)


@dataclass
class IndexCheckResult:
    """Result of index verification and creation."""

    existing_count: int = 0
    created_count: int = 0
    failed_count: int = 0
    missing_no_definition: int = 0
    details: list[str] = field(default_factory=list)
    summary: str = ""

    def to_report(self) -> str:
        """Human-readable report."""
        lines = [
            f"Index check: {self.existing_count} existing, {self.created_count} created, "
            f"{self.failed_count} failed, {self.missing_no_definition} missing (no definition)",
            self.summary,
        ]
        for d in self.details:
            lines.append(f"  {d}")
        return "\n".join(lines)


def _ensure_index_definition_column(conn: psycopg2.extensions.connection) -> None:
    """Add index_definition column to pipeline.expected_indexes if missing."""
    with conn.cursor() as cur:
        cur.execute(
            """
            ALTER TABLE pipeline.expected_indexes
            ADD COLUMN IF NOT EXISTS index_definition TEXT
            """
        )


def _parse_table_ref(table_name: str) -> tuple[str, str]:
    """Parse table_name as 'schema.tablename' or 'tablename'. Returns (schema, table)."""
    if "." in table_name:
        parts = table_name.split(".", 1)
        return (parts[0], parts[1])
    return ("public", table_name)


def _fetch_expected_indexes(conn: psycopg2.extensions.connection) -> list[dict]:
    """Fetch all rows from pipeline.expected_indexes."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT table_name, index_name, index_definition
            FROM pipeline.expected_indexes
            ORDER BY table_name, index_name
            """
        )
        return [
            {"table_name": r[0], "index_name": r[1], "index_definition": r[2]}
            for r in cur.fetchall()
        ]


def _index_exists(conn: psycopg2.extensions.connection, schema: str, table: str, index_name: str) -> bool:
    """Check if index exists in pg_indexes."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT 1 FROM pg_indexes
            WHERE schemaname = %s AND tablename = %s AND indexname = %s
            """,
            (schema, table, index_name),
        )
        return cur.fetchone() is not None


def _create_index(conn: psycopg2.extensions.connection, index_definition: str) -> bool:
    """Execute CREATE INDEX statement. Returns True on success, False on failure."""
    definition = (index_definition or "").strip()
    if not definition:
        return False
    if not definition.upper().startswith("CREATE"):
        logger.warning("Index definition does not start with CREATE: %s...", definition[:80])
        return False
    try:
        with conn.cursor() as cur:
            cur.execute(definition)
        return True
    except psycopg2.Error as e:
        logger.warning("Failed to create index: %s", e)
        return False


def run_index_check(*, create_missing: bool = True) -> IndexCheckResult:
    """
    Verify expected indexes exist; optionally create missing ones.

    Reads pipeline.expected_indexes. For each (table_name, index_name), checks
    pg_indexes. If missing and index_definition is set, executes it when
    create_missing=True. Table_name may be 'schema.table' or 'table' (default schema public).

    Args:
        create_missing: If True, create missing indexes using index_definition.
            Requires index_definition column to be populated for indexes to create.

    Returns:
        IndexCheckResult with existing_count, created_count, failed_count,
        missing_no_definition, details, summary.
    """
    init_pool()
    result = IndexCheckResult()

    with get_connection() as conn:
        try:
            _ensure_index_definition_column(conn)
            rows = _fetch_expected_indexes(conn)

            if not rows:
                result.summary = "No expected indexes registered in pipeline.expected_indexes."
                logger.info(result.summary)
                return result

            for row in rows:
                table_name = row["table_name"]
                index_name = row["index_name"]
                index_def = row.get("index_definition")

                schema, table = _parse_table_ref(table_name)

                try:
                    exists = _index_exists(conn, schema, table, index_name)
                except psycopg2.Error as e:
                    result.failed_count += 1
                    result.details.append(f"ERROR {schema}.{table}.{index_name}: {e}")
                    logger.warning("Could not check index %s: %s", index_name, e)
                    continue

                if exists:
                    result.existing_count += 1
                    result.details.append(f"OK {schema}.{table}.{index_name} (exists)")
                    continue

                if not index_def or not index_def.strip():
                    result.missing_no_definition += 1
                    result.details.append(f"MISSING {schema}.{table}.{index_name} (no index_definition)")
                    continue

                if not create_missing:
                    result.failed_count += 1
                    result.details.append(f"MISSING {schema}.{table}.{index_name} (create_missing=False)")
                    continue

                try:
                    success = _create_index(conn, index_def)
                    if success:
                        conn.commit()
                        result.created_count += 1
                        result.details.append(f"CREATED {schema}.{table}.{index_name}")
                        logger.info("Created index %s on %s.%s", index_name, schema, table)
                    else:
                        result.failed_count += 1
                        result.details.append(f"FAILED {schema}.{table}.{index_name} (create failed)")
                except psycopg2.Error as e:
                    result.failed_count += 1
                    result.details.append(f"FAILED {schema}.{table}.{index_name}: {e}")
                    logger.exception("Create index %s failed: %s", index_name, e)

            result.summary = (
                f"Total: {len(rows)} expected. "
                f"{result.existing_count} existing, {result.created_count} created, "
                f"{result.failed_count} failed, {result.missing_no_definition} missing (no definition)."
            )
            logger.info("Index check: %s", result.summary)

        except psycopg2.Error as e:
            result.summary = str(e)
            logger.exception("Index check failed: %s", e)
            raise

    return result
