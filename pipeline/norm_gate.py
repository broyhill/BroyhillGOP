"""
Normalization gate for the BroyhillGOP pipeline.

Reads pipeline.norm_readiness_rules for a given source_system. Each rule specifies
a column and min_non_null_pct threshold. Runs a query against the staging table
(SELECT COUNT(*), COUNT(column) FROM staging_table) to compute the non-null
percentage. ALL rules must pass before data can move from staging to norm schema.
Uses parameterized identifiers for safe table/column substitution.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

import psycopg2
from psycopg2 import sql

from pipeline.db import get_connection, init_pool

logger = logging.getLogger(__name__)


@dataclass
class RuleResult:
    """Result of a single norm readiness rule check."""

    column_name: str
    min_non_null_pct: float
    actual_pct: float
    total_rows: int
    non_null_rows: int
    passed: bool
    notes: str = ""


@dataclass
class GateResult:
    """Result of the normalization gate check."""

    passed: bool
    source_system: str
    staging_schema: str
    staging_table: str
    rule_results: list[RuleResult] = field(default_factory=list)
    summary: str = ""

    def to_report(self) -> str:
        """Human-readable report."""
        lines = [
            f"Norm gate: {self.source_system} -> {self.staging_schema}.{self.staging_table}",
            f"Result: {'PASS' if self.passed else 'FAIL'}",
            self.summary,
            "",
        ]
        for r in self.rule_results:
            status = "PASS" if r.passed else "FAIL"
            lines.append(
                f"  {r.column_name}: {r.actual_pct:.1f}% non-null "
                f"(min {r.min_non_null_pct:.1f}%, {r.non_null_rows}/{r.total_rows} rows) [{status}]"
            )
        return "\n".join(lines)


def _resolve_staging_table(source_system: str, cycle: str) -> tuple[str, str]:
    """Return (schema, table_name) for the staging table. Matches ingest.py logic."""
    schema = "staging"
    if source_system.lower() == "fec":
        table = f"fec_{cycle}_a_staging"
    else:
        table = f"{source_system}_{cycle}_staging"
    return schema, table


def _fetch_rules(
    conn: psycopg2.extensions.connection,
    source_system: str,
) -> list[dict]:
    """Fetch norm_readiness_rules for the source system."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name, min_non_null_pct, notes
            FROM pipeline.norm_readiness_rules
            WHERE source_system = %s
            ORDER BY column_name
            """,
            (source_system,),
        )
        return [
            {"column_name": r[0], "min_non_null_pct": float(r[1]), "notes": r[2] or ""}
            for r in cur.fetchall()
        ]


def _run_column_readiness_query(
    conn: psycopg2.extensions.connection,
    schema: str,
    table: str,
    column_name: str,
) -> tuple[int, int]:
    """
    Run query to get total rows and non-null count for column.
    Returns (total_rows, non_null_rows).
    """
    query = sql.SQL("SELECT COUNT(*) AS total, COUNT({col}) AS non_null FROM {t}").format(
        col=sql.Identifier(column_name),
        t=sql.Identifier(schema, table),
    )
    with conn.cursor() as cur:
        cur.execute(query)
        row = cur.fetchone()
        return (row[0] or 0, row[1] or 0)


def run_norm_gate(
    source_system: str,
    *,
    staging_schema: str | None = None,
    staging_table: str | None = None,
    cycle: str | None = None,
) -> GateResult:
    """
    Run all norm readiness rules against the staging table.

    ALL rules must pass for the gate to pass. Each rule checks that the
    non-null percentage for a column is >= min_non_null_pct.

    Args:
        source_system: Source system name (e.g. fec, nc_boe).
        staging_schema: Staging schema. If None, uses cycle to resolve.
        staging_table: Staging table. If None, uses cycle to resolve.
        cycle: Cycle label (e.g. 2015_2016). Used when staging_schema/table not given.

    Returns:
        GateResult with passed/failed, list of RuleResult, and summary.
    """
    if staging_schema is not None and staging_table is not None:
        schema, table = staging_schema, staging_table
    elif cycle is not None:
        schema, table = _resolve_staging_table(source_system, cycle)
    else:
        raise ValueError("Must provide either (staging_schema, staging_table) or cycle")

    init_pool()
    result = GateResult(
        passed=True,
        source_system=source_system,
        staging_schema=schema,
        staging_table=table,
    )

    with get_connection() as conn:
        try:
            rules = _fetch_rules(conn, source_system)
            if not rules:
                result.summary = f"No norm_readiness_rules defined for {source_system}; gate passes by default."
                logger.info(result.summary)
                return result

            for rule in rules:
                column_name = rule["column_name"]
                min_pct = rule["min_non_null_pct"]
                notes = rule.get("notes", "")

                try:
                    total, non_null = _run_column_readiness_query(conn, schema, table, column_name)
                except psycopg2.Error as e:
                    rule_result = RuleResult(
                        column_name=column_name,
                        min_non_null_pct=min_pct,
                        actual_pct=0.0,
                        total_rows=0,
                        non_null_rows=0,
                        passed=False,
                        notes=f"Query failed: {e}",
                    )
                    result.rule_results.append(rule_result)
                    result.passed = False
                    logger.error("Rule %s failed: %s", column_name, e)
                    continue

                if total == 0:
                    actual_pct = 0.0
                    passed = min_pct == 0.0
                else:
                    actual_pct = 100.0 * non_null / total
                    passed = actual_pct >= min_pct

                rule_result = RuleResult(
                    column_name=column_name,
                    min_non_null_pct=min_pct,
                    actual_pct=actual_pct,
                    total_rows=total,
                    non_null_rows=non_null,
                    passed=passed,
                    notes=notes,
                )
                result.rule_results.append(rule_result)

                if passed:
                    logger.info(
                        "Rule PASS: %s %.1f%% >= %.1f%% (%s/%s)",
                        column_name,
                        actual_pct,
                        min_pct,
                        non_null,
                        total,
                    )
                else:
                    result.passed = False
                    logger.warning(
                        "Rule FAIL: %s %.1f%% < %.1f%% (%s/%s)",
                        column_name,
                        actual_pct,
                        min_pct,
                        non_null,
                        total,
                    )

            if result.rule_results:
                passed_count = sum(1 for r in result.rule_results if r.passed)
                total_count = len(result.rule_results)
                result.summary = (
                    f"{passed_count}/{total_count} rules passed. "
                    f"Norm load {'allowed' if result.passed else 'BLOCKED until all rules pass'}."
                )

        except psycopg2.Error as e:
            result.passed = False
            result.summary = str(e)
            logger.exception("Norm gate failed: %s", e)
            raise

    return result
