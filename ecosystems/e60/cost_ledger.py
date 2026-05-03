"""
E60.cost_ledger — universal CostEvent persistence + rollups.

Backed by core.cost_ledger. Every Brain module emits a CostEvent on every
spend event; this module persists them idempotently (UPSERT on event_id) and
provides per-ecosystem / per-donor / per-campaign / per-channel ROI rollups.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime
from typing import Optional

import psycopg2
from psycopg2.extras import RealDictCursor, Json

# Per Brain Pentad Rule P-1: imports ONLY from shared.
try:
    from shared.brain_pentad_contracts import CostEvent, CostType
except ImportError:  # pragma: no cover
    import sys, pathlib
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent.parent))
    from shared.brain_pentad_contracts import CostEvent, CostType


logger = logging.getLogger("ecosystem60.cost_ledger")


class CostLedger:
    """
    Cost ledger reader/writer.

    Schema (created by 200_e60_cost_ledger.sql):

        CREATE TABLE core.cost_ledger (
            event_id                  TEXT PRIMARY KEY,
            source_ecosystem          TEXT NOT NULL,
            donor_id                  TEXT,
            cost_type                 TEXT NOT NULL,
            vendor                    TEXT NOT NULL,
            unit_cost_cents           INTEGER NOT NULL CHECK (unit_cost_cents >= 0),
            quantity                  INTEGER NOT NULL CHECK (quantity >= 1),
            total_cost_cents          INTEGER NOT NULL CHECK (total_cost_cents >= 0),
            revenue_attributed_cents  INTEGER NOT NULL DEFAULT 0,
            occurred_at               TIMESTAMPTZ NOT NULL,
            created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        CREATE INDEX cost_ledger_source_ecosystem_idx ON core.cost_ledger(source_ecosystem);
        CREATE INDEX cost_ledger_donor_id_idx          ON core.cost_ledger(donor_id);
        CREATE INDEX cost_ledger_occurred_at_idx       ON core.cost_ledger(occurred_at);
    """

    def __init__(self, db_url: str):
        self.db_url = db_url

    def _get_db(self):
        return psycopg2.connect(self.db_url)

    def write(self, event: CostEvent) -> bool:
        """
        Persist a CostEvent. Idempotent: same event_id is a no-op.

        Returns True if a new row was created, False if the event_id already existed.
        """
        conn = self._get_db()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO core.cost_ledger "
                    "  (event_id, source_ecosystem, donor_id, cost_type, vendor, "
                    "   unit_cost_cents, quantity, total_cost_cents, "
                    "   revenue_attributed_cents, occurred_at) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s) "
                    "ON CONFLICT (event_id) DO NOTHING",
                    (
                        event.event_id, event.source_ecosystem, event.donor_id,
                        event.cost_type.value, event.vendor,
                        event.unit_cost_cents, event.quantity, event.total_cost_cents,
                        event.revenue_attributed_cents, event.occurred_at,
                    ),
                )
                created = cur.rowcount > 0
            conn.commit()
        finally:
            conn.close()
        if created:
            logger.info(
                f"cost_ledger.write {event.event_id} src={event.source_ecosystem} "
                f"type={event.cost_type.value} cents={event.total_cost_cents}"
            )
        else:
            logger.debug(f"cost_ledger.write IDEMPOTENT skip {event.event_id}")
        return created

    def rollup_per_ecosystem(self, since: Optional[datetime] = None) -> list:
        """Return per-source-ecosystem cost + revenue rollup."""
        sql = (
            "SELECT source_ecosystem, "
            "       SUM(total_cost_cents) AS total_cost_cents, "
            "       SUM(revenue_attributed_cents) AS total_revenue_cents, "
            "       COUNT(*) AS event_count "
            "FROM core.cost_ledger "
        )
        params = ()
        if since is not None:
            sql += "WHERE occurred_at >= %s "
            params = (since,)
        sql += "GROUP BY source_ecosystem ORDER BY total_cost_cents DESC"
        conn = self._get_db()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, params)
                return [dict(r) for r in cur.fetchall()]
        finally:
            conn.close()

    def daily_burn_cents(self, on_date: Optional[datetime] = None) -> int:
        """Total cost in cents for a single calendar day (default: today UTC)."""
        on_date = on_date or datetime.utcnow()
        conn = self._get_db()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT COALESCE(SUM(total_cost_cents), 0) FROM core.cost_ledger "
                    "WHERE DATE(occurred_at) = DATE(%s)",
                    (on_date,),
                )
                row = cur.fetchone()
                return int(row[0]) if row else 0
        finally:
            conn.close()


def log_cost(event: CostEvent, db_url: str) -> bool:
    """
    Convenience helper. Async-style fire-and-forget in real usage; here it's
    a thin synchronous wrapper. Other Brain modules import this directly:

        from ecosystems.e60.cost_ledger import log_cost
        log_cost(my_cost_event, db_url=DB_URL)

    Returns True on first persistence, False if already present (idempotent).
    """
    return CostLedger(db_url).write(event)


__all__ = ["CostLedger", "log_cost"]
