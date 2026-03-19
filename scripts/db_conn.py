"""Shared DB connection for scripts. Reads from .env."""
from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")


def get_connection_url() -> str:
    url = os.environ.get("SUPABASE_DB_URL") or os.environ.get("DATABASE_URL")
    if not url or not url.strip():
        raise ValueError("SUPABASE_DB_URL or DATABASE_URL must be set in .env")
    return url.strip()
