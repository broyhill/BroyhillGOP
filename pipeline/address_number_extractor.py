"""
Extract ALL numeric tokens from NCBOE street lines (house, PO Box, HWY, suite, RR, etc.).
"""

from __future__ import annotations

import re
from typing import Iterable

# Sequences of digits, optionally with internal dots (rare); prefer full number tokens
_TOKEN_RE = re.compile(r"\d+(?:\.\d+)?")


def extract_address_numbers(*lines: str | None) -> list[str]:
    """
    Return unique-ish ordered list of numeric strings found across lines.
    Examples:
      "525 N HAWTHORNE RD", "APT 3224" -> ["525", "3224"]
      "PO BOX 1247" -> ["1247"]
      "4721 HWY 421 S" -> ["4721", "421"]
    """
    found: list[str] = []
    seen: set[str] = set()
    for line in lines:
        if not line or not str(line).strip():
            continue
        for m in _TOKEN_RE.finditer(str(line)):
            t = m.group(0)
            # Normalize "525.0" -> "525" for integers
            if "." in t and t.replace(".", "").isdigit():
                try:
                    if float(t) == int(float(t)):
                        t = str(int(float(t)))
                except ValueError:
                    pass
            if t not in seen:
                seen.add(t)
                found.append(t)
    return found


def _self_tests() -> None:
    assert extract_address_numbers("525 N HAWTHORNE RD", "APT 3224") == ["525", "3224"]
    assert extract_address_numbers("PO BOX 1247") == ["1247"]
    assert extract_address_numbers("4721 HWY 421 S") == ["4721", "421"]
    assert extract_address_numbers("STE 300 100 MAIN ST") == ["300", "100"]
    assert extract_address_numbers("RR 3 BOX 45") == ["3", "45"]
    print("address_number_extractor: all self-tests passed")


if __name__ == "__main__":
    _self_tests()
