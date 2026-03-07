"""
BroyhillGOP FEC donor data ingestion pipeline.

Python-based ingestion pipeline for the BroyhillGOP political CRM platform.
Runs on local Mac with Supabase PostgreSQL as the database backend.

Modules:
    db: Shared database connection and pooling
    ingest: Ingestion orchestrator (file → staging)
"""

__version__ = "0.1.0"
