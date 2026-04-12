"""
NCBOE GOLD name parser — FIRST MIDDLE LAST order (not FEC LAST, FIRST).

Rules per sessions/CURSOR_PHASE_D_ORDERS.md and SESSION_APRIL12_2026.md:
- Suffixes JR, SR, II, III, IV, V, ESQ (trailing)
- Prefixes DR, REV, MR, MRS, MS, HON (leading)
- Nicknames in single quotes: JAMES EDGAR 'ED' BROYHILL
- Blank name → unitemized (caller sets flag)
- ED must never become EDWARD (no EDWARD expansion anywhere in this module)
"""

from __future__ import annotations

import re
from dataclasses import dataclass

_SUFFIX_RE = re.compile(
    r"\s+(JR\.?|SR\.?|II|III|IV|V|ESQ\.?|MD|PHD|DDS|JD)\s*$",
    re.IGNORECASE,
)
_PREFIXES = frozenset({"DR", "REV", "MR", "MRS", "MS", "HON", "PROF", "RABBI", "BISHOP", "DEACON", "PASTOR"})


@dataclass(frozen=True)
class ParsedNCBOEName:
    prefix: str | None
    first: str | None
    middle: str | None
    nickname: str | None
    last: str | None
    suffix: str | None
    is_unitemized: bool


def _strip_quotes_nickname(s: str) -> tuple[str, str | None]:
    """Remove first ... 'NICK' ... span; return cleaned string and nickname."""
    m = re.search(r"'([^']+)'", s)
    if not m:
        return s, None
    nick = m.group(1).strip().upper()
    cleaned = (s[: m.start()] + s[m.end() :]).strip()
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned, nick


def _split_words(s: str) -> list[str]:
    return [w for w in re.split(r"\s+", s.strip()) if w]


def parse_ncboe_gold_name(raw: str | None) -> ParsedNCBOEName:
    """
    Parse NCBOE `Name` field (FIRST MIDDLE LAST, optional prefix/suffix, optional 'NICK').
    Never maps ED → EDWARD. Does not expand ED → EDGAR in output fields (first stays as filed).
    """
    if raw is None or not str(raw).strip():
        return ParsedNCBOEName(None, None, None, None, None, None, True)

    s = str(raw).strip().upper()
    s = re.sub(r"\s+", " ", s)

    suffix: str | None = None
    sm = _SUFFIX_RE.search(s)
    if sm:
        suffix = sm.group(1).upper().replace(".", "")
        s = s[: sm.start()].strip()

    nickname: str | None = None
    s, nickname = _strip_quotes_nickname(s)

    words = _split_words(s)
    if not words:
        return ParsedNCBOEName(None, None, None, None, None, suffix, True)

    prefix: str | None = None
    if words[0].rstrip(".").upper() in _PREFIXES:
        prefix = words[0].rstrip(".").upper()
        words = words[1:]
    if not words:
        return ParsedNCBOEName(prefix, None, None, nickname, None, suffix, True)

    if len(words) == 1:
        return ParsedNCBOEName(prefix, words[0], None, nickname, None, suffix, False)

    # Last token is almost always surname (NCBOE FIRST … LAST)
    last = words[-1]
    rest = words[:-1]
    first = rest[0]
    middle = " ".join(rest[1:]) if len(rest) > 1 else None
    if not middle:
        middle = None

    # Guard: never normalize nickname/first to EDWARD for ED
    if nickname == "EDWARD" and first == "ED":
        nickname = "ED"

    return ParsedNCBOEName(prefix, first, middle, nickname, last, suffix, False)


def _self_tests() -> None:
    def check(raw: str, exp: ParsedNCBOEName) -> None:
        got = parse_ncboe_gold_name(raw)
        assert got == exp, f"{raw!r}: got {got}, expected {exp}"

    check("ED BROYHILL", ParsedNCBOEName(None, "ED", None, None, "BROYHILL", None, False))
    check(
        "JAMES EDGAR BROYHILL",
        ParsedNCBOEName(None, "JAMES", "EDGAR", None, "BROYHILL", None, False),
    )
    check(
        "JAMES EDGAR 'ED' BROYHILL",
        ParsedNCBOEName(None, "JAMES", "EDGAR", "ED", "BROYHILL", None, False),
    )
    check("J BROYHILL", ParsedNCBOEName(None, "J", None, None, "BROYHILL", None, False))
    check(
        "JAMES T BROYHILL JR",
        ParsedNCBOEName(None, "JAMES", "T", None, "BROYHILL", "JR", False),
    )
    check(
        "DR JANE SMITH",
        ParsedNCBOEName("DR", "JANE", None, None, "SMITH", None, False),
    )
    check(
        "REV JOHN DOE III",
        ParsedNCBOEName("REV", "JOHN", None, None, "DOE", "III", False),
    )
    check("THOMAS L 'TOM' ADAMS", ParsedNCBOEName(None, "THOMAS", "L", "TOM", "ADAMS", None, False))
    check("T.JONATHAN ADAMS", ParsedNCBOEName(None, "T.JONATHAN", None, None, "ADAMS", None, False))
    assert "EDWARD" not in str(parse_ncboe_gold_name("ED BROYHILL"))
    print("ncboe_name_parser: all self-tests passed")


if __name__ == "__main__":
    _self_tests()
