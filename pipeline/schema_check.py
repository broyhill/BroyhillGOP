"""
Schema validator for the BroyhillGOP pipeline.

Reads pipeline.source_schemas for a given source_system and version, compares
expected columns vs actual columns in the target staging table (from
information_schema.columns), reports missing/extra columns and type mismatches,
returns pass/fail. Auto-populates pipeline.source_schemas when a new version
is detected by introspecting the staging table.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
import psycopg2

from pipeline.db import get_connection, init_pool

logger = logging.getLogger(__name__)

# PostgreSQL type aliases for comparison (normalize variants to canonical form)
_TYPE_ALIASES: dict[str, str] = {
    "character varying": "text",
    "varchar": "text",
    "timestamp with time zone": "timestamptz",
    "timestamp without time zone": "timestamp",
    "double precision": "float8",
    "real": "float4",
    "smallint": "int2",
    "integer": "int4",
    "bigint": "int8",
    "decimal": "numeric",
}


def _normalize_type(pg_type: str) -> str:
    """Normalize PostgreSQL type name for comparison."""
    t = (pg_type or "").strip().lower()
    return _TYPE_ALIASES.get(t, t)


@dataclass
class ColumnSpec:
    """Expected or actual column specification."""

    column_name: str
    position: int
    data_type: str
    nullable: bool

    def normalized_type(self) -> str:
        return _normalize_type(self.data_type)


@dataclass
class SchemaCheckResult:
    """Result of schema validation."""

    passed: bool
    source_system: str
    version: str
    staging_schema: str
    staging_table: str
    missing_columns: list[str] = field(default_factory=list)
    extra_columns: list[str] = field(default_factory=list)
    type_mismatches: list[tuple[str, str, str]] = field(default_factory=list)
    message: str = ""

    def to_report(self) -> str:
        """Human-readable report."""
        lines = [
            f"Schema check: {self.source_system} v{self.version} -> {self.staging_schema}.{self.staging_table}",
            f"Result: {'PASS' if self.passed else 'FAIL'}",
        ]
        if self.message:
            lines.append(self.message)
        if self.missing_columns:
            lines.append(f"Missing columns (expected, not in table): {self.missing_columns}")
        if self.extra_columns:
            lines.append(f"Extra columns (in table, not expected): {self.extra_columns}")
        if self.type_mismatches:
            for col, expected, actual in self.type_mismatches:
                lines.append(f"Type mismatch {col}: expected {expected}, actual {actual}")
        return "\n".join(lines)


def _resolve_staging_table(source_system: str, cycle: str) -> tuple[str, str]:
    """Return (schema, table_name) for the staging table. Matches ingest.py logic."""
    schema = "staging"
    if source_system.lower() == "fec":
        table = f"fec_{cycle}_a_staging"
    else:
        table = f"{source_system}_{cycle}_staging"
    return schema, table


def _fetch_expected_schema(
    conn: psycopg2.extensions.connection,
    source_system: str,
    version: str,
) -> list[ColumnSpec]:
    """Fetch expected schema with ordinal_position from table (source_schemas has no ordinal_position)."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name, position, data_type, nullable
            FROM pipeline.source_schemas
            WHERE source_system = %s AND version = %s
            ORDER BY COALESCE(position, id), id
            """,
            (source_system, version),
        )
        rows = cur.fetchall()
    return [
        ColumnSpec(
            column_name=r[0],
            position=r[1] or i + 1,
            data_type=r[2] or "text",
            nullable=bool(r[3]) if r[3] is not None else True,
        )
        for i, r in enumerate(rows)
    ]


def _fetch_actual_schema(
    conn: psycopg2.extensions.connection,
    schema: str,
    table: str,
) -> list[ColumnSpec]:
    """Fetch actual column specs from information_schema.columns."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name, ordinal_position, data_type,
                   is_nullable = 'YES'
            FROM information_schema.columns
            WHERE table_schema = %s AND table_name = %s
            ORDER BY ordinal_position
            """,
            (schema, table),
        )
        rows = cur.fetchall()
    return [
        ColumnSpec(
            column_name=r[0],
            position=r[1],
            data_type=r[2] or "text",
            nullable=bool(r[3]),
        )
        for r in rows
    ]


def _insert_source_schema_row(
    conn: psycopg2.extensions.connection,
    source_system: str,
    version: str,
    column_name: str,
    position: int,
    data_type: str,
    nullable: bool,
) -> None:
    """Insert one row into pipeline.source_schemas."""
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO pipeline.source_schemas
            (source_system, version, column_name, position, data_type, nullable)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (source_system, version, column_name, position, data_type, nullable),
        )


def _populate_source_schemas_from_table(
    conn: psycopg2.extensions.connection,
    source_system: str,
    version: str,
    schema: str,
    table: str,
) -> int:
    """Introspect staging table and populate pipeline.source_schemas. Returns rows inserted."""
    actual = _fetch_actual_schema(conn, schema, table)
    if not actual:
        return 0
    count = 0
    for col in actual:
        try:
            _insert_source_schema_row(
                conn,
                source_system,
                version,
                col.column_name,
                col.position,
                col.data_type,
                col.nullable,
            )
            count += 1
        except psycopg2.Error as e:
            logger.warning("Failed to insert schema row for %s: %s", col.column_name, e)
            raise
    logger.info("Populated pipeline.source_schemas with %s rows for %s v%s", count, source_system, version)
    return count


def run_schema_check(
    source_system: str,
    version: str,
    *,
    staging_schema: str | None = None,
    staging_table: str | None = None,
    cycle: str | None = None,
    auto_populate: bool = True,
) -> SchemaCheckResult:
    """
    Compare expected schema (pipeline.source_schemas) with actual staging table.

    Args:
        source_system: Source system name (e.g. fec, nc_boe).
        version: Schema version (e.g. v1, 2015_2016).
        staging_schema: Staging schema name. If None, uses cycle to resolve.
        staging_table: Staging table name. If None, uses cycle to resolve.
        cycle: Cycle label (e.g. 2015_2016). Used when staging_schema/table not given.
        auto_populate: If True and no expected schema exists, introspect staging table
            and populate pipeline.source_schemas.

    Returns:
        SchemaCheckResult with passed/failed, missing columns, extra columns, type mismatches.
    """
    if staging_schema is not None and staging_table is not None:
        schema, table = staging_schema, staging_table
    elif cycle is not None:
        schema, table = _resolve_staging_table(source_system, cycle)
    else:
        raise ValueError("Must provide either (staging_schema, staging_table) or cycle")

    init_pool()
    result = SchemaCheckResult(
        passed=True,
        source_system=source_system,
        version=version,
        staging_schema=schema,
        staging_table=table,
    )

    with get_connection() as conn:
        try:
            expected = _fetch_expected_schema(conn, source_system, version)
            actual = _fetch_actual_schema(conn, schema, table)

            if not actual:
                result.passed = False
                result.message = f"Staging table {schema}.{table} not found or has no columns."
                logger.error(result.message)
                return result

            if not expected:
                if auto_populate:
                    try:
                        _populate_source_schemas_from_table(conn, source_system, version, schema, table)
                        conn.commit()
                        expected = _fetch_expected_schema(conn, source_system, version)
                    except psycopg2.Error as e:
                        result.passed = False
                        result.message = f"Failed to auto-populate source_schemas: {e}"
                        logger.exception(result.message)
                        return result
                else:
                    result.passed = False
                    result.message = (
                        f"No expected schema for {source_system} v{version}. "
                        "Set auto_populate=True to introspect from staging table."
                    )
                    logger.warning(result.message)
                    return result

            expected_by_name = {c.column_name: c for c in expected}
            actual_by_name = {c.column_name: c for c in actual}

            for name, exp in expected_by_name.items():
                if name not in actual_by_name:
                    result.missing_columns.append(name)

            for name in actual_by_name:
                if name not in expected_by_name:
                    result.extra_columns.append(name)

            for name in set(expected_by_name) & set(actual_by_name):
                exp = expected_by_name[name]
                act = actual_by_name[name]
                if exp.normalized_type() != act.normalized_type():
                    result.type_mismatches.append((name, exp.data_type, act.data_type))

            if result.missing_columns or result.extra_columns or result.type_mismatches:
                result.passed = False
                result.message = (
                    f"Schema mismatch: {len(result.missing_columns)} missing, "
                    f"{len(result.extra_columns)} extra, {len(result.type_mismatches)} type mismatches"
                )
            else:
                result.message = "Schema matches expected."

            logger.info(
                "Schema check %s: %s v%s -> %s.%s",
                "PASS" if result.passed else "FAIL",
                source_system,
                version,
                schema,
                table,
            )

        except psycopg2.Error as e:
            result.passed = False
            result.message = str(e)
            logger.exception("Schema check failed: %s", e)
            raise

    return result
