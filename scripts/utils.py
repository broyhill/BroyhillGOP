"""
Shared NCBOE/NCGOP pipeline utilities. Single source of truth for name parsing,
zip normalization, and amount parsing. Used by import_ncboe_raw, normalize_ncboe,
and other pipeline scripts.
"""
from __future__ import annotations

import re
from datetime import datetime


def parse_name_last_first(val: str) -> tuple[str, str]:
    """
    Split 'LAST, FIRST' on first comma only. Returns (last, first) as raw strings.
    Handles O'BRIEN, JAMES WILLIAM III correctly.
    """
    if not val or not str(val).strip():
        return ("", "")
    s = str(val).strip()
    idx = s.find(",")
    if idx >= 0:
        return (s[:idx].strip(), s[idx + 1 :].strip())
    return (s, "")


def norm_name(s: str) -> str:
    """Lowercase, strip, collapse multiple spaces. Does NOT strip punctuation."""
    if not s:
        return ""
    return re.sub(r"\s+", " ", str(s).lower().strip())


def norm_zip(val: str) -> str:
    """Extract 5-digit zip from any string."""
    if not val:
        return ""
    digits = re.sub(r"\D", "", str(val))
    return digits[:5] if digits else ""


def parse_name_last_first_normalized(val: str) -> tuple[str, str]:
    """
    Parse 'LAST, FIRST' and return (norm_last, norm_first) for dedup_key.
    Uses same logic as parse_name_last_first + norm_name.
    """
    last_raw, first_raw = parse_name_last_first(val)
    return (norm_name(last_raw), norm_name(first_raw))


def parse_amount(val: str) -> float | None:
    """Parse dollar amount. Handles $1,234.56 and 1234.56."""
    if not val or not str(val).strip():
        return None
    s = str(val).strip().replace(",", "").replace("$", "")
    try:
        return float(s)
    except ValueError:
        return None


def parse_date(val: str) -> datetime | None:
    """Parse date from common formats."""
    if not val or not str(val).strip():
        return None
    s = str(val).strip()
    for fmt in ("%m/%d/%Y", "%Y-%m-%d", "%m/%d/%y", "%Y-%m-%d"):
        try:
            return datetime.strptime(s[:10] if len(s) > 10 else s, fmt)
        except ValueError:
            continue
    m = re.match(r"(\d{1,2})/(\d{1,2})/(\d{2,4})", s)
    if m:
        mm, dd, yy = m.groups()
        y = int(yy) if len(yy) == 4 else (2000 + int(yy) if int(yy) < 100 else 1900 + int(yy))
        return datetime(y, int(mm), int(dd))
    return None
