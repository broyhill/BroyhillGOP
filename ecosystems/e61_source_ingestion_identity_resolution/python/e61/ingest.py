"""
e61.ingest — orchestrator (Phase 2 stub).

The 12-step pipeline that takes a registered source CSV from raw → canonical:

    1. validate_source(source_id, file_sha256)      — registry lookup, dedup check
    2. snapshot_to_archive(file)                     — preserve raw forever
    3. parse_csv_to_rows(file) -> ingested_row[]     — preserve raw_payload verbatim
    4. normalize_rows(rows, rules)                   — see e61.normalize
    5. component_parse_addresses(rows)               — {number, predir, name, type, unit}
    6. assign_cluster_id(rows)                       — see e61.cluster_assign
    7. match_datatrust(rows) -> match_tier T1..T6    — see e61.datatrust_match
    8. dark_recovery(unmatched_rows)                 — Path B' (smart fallbacks) + C₂ (adjacency-merge)
    9. canary_verify(run)                            — Ed/Pope/Melanie unchanged
    10. publish_to_canonical(rows)                   — E15/E01/E03 with lineage_link rows
    11. emit_metrics(run)                            — E20/E27/E51 telemetry
    12. mark_run_done(run_id)                        — triggers Layer-5 notify

STATUS: stub. Phase 2 will fill in the real orchestration. The normalize step
(e61.normalize) is already complete.
"""

from __future__ import annotations

from typing import Any
from .normalize import normalize_row, NormalizationResult


def run_ingestion(source_id: str, file_path: str, submitter_user_id: str | None = None) -> dict[str, Any]:
    """Phase 2 entry point. Currently raises NotImplementedError until Phase 1 DDL lands."""
    raise NotImplementedError(
        "E61 ingest orchestrator is held until Phase 1 (DDL on Hetzner) completes "
        "and Ed authorizes Phase 2 implementation."
    )


def normalize_only(rows: list[dict[str, Any]], source_id: str = "default") -> list[NormalizationResult]:
    """
    Available NOW (Phase 0): normalize a list of raw rows. Returns NormalizationResult
    list with quarantine_reason populated for bad rows. No DB writes.
    Useful for offline pre-flight validation of a source CSV before Phase 1 lands.
    """
    return [normalize_row(r, source_id=source_id) for r in rows]
