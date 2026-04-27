"""
E61 — Source Ingestion & Identity Resolution Engine.

Single ingress point for every messy CSV/upload. Normalizes, clusters, matches,
quarantines, and publishes to canonical destinations (E15, E01, E03) with full
lineage.

STATUS: held artifact. Do not import in production until donor identity pipeline
completes and Ed authorizes Phase 1.
"""

__version__ = "0.1.0-spec"
__status__ = "spec"
