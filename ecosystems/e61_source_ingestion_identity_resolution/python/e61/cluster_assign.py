"""
e61.cluster_assign — cluster_id_v2 assignment (Phase 2 stub).

Two passes:

    Pass A — Three-key gate
        cluster on (norm_last + norm_first + zip5)
        merge rows that agree on these three keys

    Pass B — Alphabetical adjacency (the 2026-04-27 lesson)
        on the alphabetically-sorted file, scan a sliding window of 50 rows
        for matching last+zip5 with compatible first names (initial-of, nickname-of)
        propose merges of clusters that should be one person

The Ed Broyhill case (7 name variants, 1 person, 7 different cluster_id_v2s in
today's Stage-2 output) is the validation fixture: after Pass A + Pass B, all
~120 BROYHILL rows at zip 27104 should land in one cluster.

STATUS: stub. Real implementation lands in Phase 2.
"""

from __future__ import annotations

from typing import Any


def assign_cluster_ids(normalized_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Phase 2 entry point. Returns rows with cluster_id_v2 populated."""
    raise NotImplementedError(
        "E61 cluster assignment is held until Phase 2 implementation. "
        "Use the existing Stage-2 logic in scripts/ for now."
    )
