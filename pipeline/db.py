"""
Shared database connection and connection pooling for the BroyhillGOP pipeline.

Uses psycopg2 with ThreadedConnectionPool. Reads SUPABASE_DB_URL from environment.
All database access should go through get_connection() or the pool.
"""

from __future__ import annotations

import logging
from pathlib import Path

from dotenv import load_dotenv

# Load .env from project root when pipeline is imported
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

import os
from contextlib import contextmanager
from typing import Generator

import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor

logger = logging.getLogger(__name__)

# Module-level pool; initialized on first use
_connection_pool: pool.ThreadedConnectionPool | None = None

# Pool configuration
_MIN_CONNECTIONS = 1
_MAX_CONNECTIONS = 5


def _get_connection_url() -> str:
    """Return database URL from environment. Raises if not set."""
    url = (
        os.environ.get("HETZNER_DB_URL")
        or os.environ.get("DATABASE_URL")
        or os.environ.get("SUPABASE_DB_URL")
    )
    if not url or not url.strip():
        raise ValueError(
            "HETZNER_DB_URL, DATABASE_URL, or SUPABASE_DB_URL must be set in environment. "
            "For the AX162 server use HETZNER_DB_URL (PostgreSQL 16 on 37.27.169.232)."
        )
    return url.strip()


def init_pool() -> pool.ThreadedConnectionPool:
    """Initialize the connection pool. Idempotent."""
    global _connection_pool
    if _connection_pool is not None:
        return _connection_pool
    try:
        url = _get_connection_url()
        _connection_pool = pool.ThreadedConnectionPool(
            _MIN_CONNECTIONS,
            _MAX_CONNECTIONS,
            url,
            options="-c statement_timeout=0 -c idle_in_transaction_session_timeout=0",
        )
        logger.info("Database connection pool initialized (%s–%s connections)", _MIN_CONNECTIONS, _MAX_CONNECTIONS)
        return _connection_pool
    except Exception as e:
        logger.exception("Failed to initialize connection pool: %s", e)
        raise


def close_pool() -> None:
    """Close all connections in the pool."""
    global _connection_pool
    if _connection_pool is not None:
        try:
            _connection_pool.closeall()
        except Exception as e:
            logger.warning("Error closing connection pool: %s", e)
        finally:
            _connection_pool = None
        logger.info("Connection pool closed")


@contextmanager
def get_connection() -> Generator[psycopg2.extensions.connection, None, None]:
    """
    Yield a connection from the pool. Automatically returns it on exit.
    Usage:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
    """
    p = init_pool()
    conn = None
    try:
        conn = p.getconn()
        yield conn
    except Exception as e:
        if conn is not None:
            conn.rollback()
        logger.exception("Database error: %s", e)
        raise
    finally:
        if conn is not None:
            conn.commit()
            p.putconn(conn)


@contextmanager
def get_cursor(
    dict_cursor: bool = False,
) -> Generator[psycopg2.extensions.cursor | RealDictCursor, None, None]:
    """
    Yield a cursor from a pooled connection. Dict cursor returns rows as dicts.
    """
    with get_connection() as conn:
        cursor_factory = RealDictCursor if dict_cursor else None
        cur = conn.cursor(cursor_factory=cursor_factory)
        try:
            yield cur
        finally:
            cur.close()
