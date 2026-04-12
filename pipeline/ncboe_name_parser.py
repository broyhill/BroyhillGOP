"""
NCBOE GOLD name parser — FIRST MIDDLE LAST order (not FEC LAST, FIRST).

Rules per sessions/CURSOR_PHASE_D_ORDERS.md and SESSION_APRIL12_2026.md:
- Suffixes JR, SR, II, III, IV, V, ESQ (trailing OR misplaced — scanned anywhere)
- Prefixes DR, REV, MR, MRS, MS, HON (leading)
- Nicknames in single quotes: JAMES EDGAR 'ED' BROYHILL
- Blank name → unitemized (caller sets flag)
- ED must never become EDWARD (no EDWARD expansion anywhere in this module)
- Middle initial periods are stripped: T. → T
- Suffix tokens in any position are extracted (not just trailing)
"""

from __future__ import annotations

import re
from dataclasses import dataclass

# Matches a trailing suffix — used first for clean cases
_SUFFIX_TRAILING_RE = re.compile(
    r"\s+(JR\.?|SR\.?|II|III|IV|V|ESQ\.?|MD\.?|PHD\.?|DDS\.?|JD\.?)\s*$",
    re.IGNORECASE,
)

# Full set of suffix tokens — used to scrub suffix from anywhere in token list
_SUFFIX_TOKENS = frozenset({
    "JR", "SR", "II", "III", "IV", "V", "ESQ", "MD", "PHD", "DDS", "JD"
})

_PREFIXES = frozenset({
    "DR", "REV", "MR", "MRS", "MS", "HON", "PROF",
    "RABBI", "BISHOP", "DEACON", "PASTOR"
})


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
    """Remove first 'NICK' span; return cleaned string and nickname."""
    m = re.search(r"'([^']+)'", s)
    if not m:
        return s, None
    nick = m.group(1).strip().upper()
    cleaned = (s[: m.start()] + s[m.end() :]).strip()
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned, nick


def _clean_token(token: str) -> str:
    """Strip trailing/leading periods from a token (handles T. → T, JR. → JR)."""
    return token.strip(".")


def _split_words(s: str) -> list[str]:
    return [w for w in re.split(r"\s+", s.strip()) if w]


def parse_ncboe_gold_name(raw: str | None) -> ParsedNCBOEName:
    """
    Parse NCBOE `Name` field (FIRST MIDDLE LAST, optional prefix/suffix, optional 'NICK').

    Fixes:
    - Middle initial periods stripped: T. → T
    - Suffix tokens extracted from ANY position in the token list, not just trailing
    - Never maps ED → EDWARD. Does not expand ED → EDGAR in output fields.
    """
    if raw is None or not str(raw).strip():
        return ParsedNCBOEName(None, None, None, None, None, None, True)

    s = str(raw).strip().upper()
    s = re.sub(r"\s+", " ", s)

    # Step 1: Strip trailing suffix first (clean case — no bleed)
    suffix: str | None = None
    sm = _SUFFIX_TRAILING_RE.search(s)
    if sm:
        suffix = _clean_token(sm.group(1).upper())
        s = s[: sm.start()].strip()

    # Step 2: Extract nickname in quotes
    nickname: str | None = None
    s, nickname = _strip_quotes_nickname(s)

    # Step 3: Split into tokens and clean periods off each
    words = [_clean_token(w) for w in _split_words(s) if _clean_token(w)]
    if not words:
        return ParsedNCBOEName(None, None, None, None, None, suffix, True)

    # Step 4: If suffix not found yet, scan tokens for misplaced suffix (e.g. BROYHILL JR JAMES)
    if suffix is None:
        cleaned_words = []
        for w in words:
            if w in _SUFFIX_TOKENS:
                suffix = w  # take first suffix token found
            else:
                cleaned_words.append(w)
        words = cleaned_words
    else:
        # Suffix already found — still scrub any stray suffix tokens from token list
        words = [w for w in words if w not in _SUFFIX_TOKENS]

    if not words:
        return ParsedNCBOEName(None, None, None, nickname, None, suffix, True)

    # Step 5: Strip leading prefix
    prefix: str | None = None
    if words[0] in _PREFIXES:
        prefix = words[0]
        words = words[1:]
    if not words:
        return ParsedNCBOEName(prefix, None, None, nickname, None, suffix, True)

    # Step 6: Single token
    if len(words) == 1:
        return ParsedNCBOEName(prefix, words[0], None, nickname, None, suffix, False)

    # Step 7: FIRST [MIDDLE...] LAST — last token is surname
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


# Alias for operator smoke tests and docs that use the shorter name
parse_ncboe_name = parse_ncboe_gold_name


def _self_tests() -> None:
    def check(raw: str, exp: ParsedNCBOEName) -> None:
        got = parse_ncboe_gold_name(raw)
        assert got == exp, f"{raw!r}:\n  got      {got}\n  expected {exp}"

    # Core cases
    check("ED BROYHILL",        ParsedNCBOEName(None, "ED",    None,    None,  "BROYHILL", None,  False))
    check("JAMES EDGAR BROYHILL", ParsedNCBOEName(None, "JAMES", "EDGAR", None, "BROYHILL", None, False))
    check("JAMES EDGAR 'ED' BROYHILL", ParsedNCBOEName(None, "JAMES", "EDGAR", "ED", "BROYHILL", None, False))
    check("J BROYHILL",         ParsedNCBOEName(None, "J",     None,    None,  "BROYHILL", None,  False))
    check("JAMES T BROYHILL JR",  ParsedNCBOEName(None, "JAMES", "T",    None,  "BROYHILL", "JR",  False))
    check("DR JANE SMITH",       ParsedNCBOEName("DR", "JANE",  None,    None,  "SMITH",    None,  False))
    check("REV JOHN DOE III",    ParsedNCBOEName("REV","JOHN",  None,    None,  "DOE",      "III", False))
    check("THOMAS L 'TOM' ADAMS", ParsedNCBOEName(None, "THOMAS","L",   "TOM", "ADAMS",    None,  False))
    check("T.JONATHAN ADAMS",    ParsedNCBOEName(None, "T.JONATHAN", None, None, "ADAMS",  None,  False))

    # Period-on-initial fixes
    check("JAMES T. BROYHILL JR",  ParsedNCBOEName(None, "JAMES", "T",   None,  "BROYHILL", "JR",  False))
    check("JAMES T. BROYHILL JR.", ParsedNCBOEName(None, "JAMES", "T",   None,  "BROYHILL", "JR",  False))
    check("WILLIAM C. POPE SR",    ParsedNCBOEName(None, "WILLIAM","C",  None,  "POPE",     "SR",  False))

    # Misplaced suffix scrub
    check("JAMES EDGAR BROYHILL SR", ParsedNCBOEName(None, "JAMES","EDGAR", None, "BROYHILL","SR", False))
    check("JAMES A SMITH III",     ParsedNCBOEName(None, "JAMES", "A",   None,  "SMITH",    "III", False))

    # Two middle names
    check("MARY JANE ANN SMITH",   ParsedNCBOEName(None, "MARY", "JANE ANN", None, "SMITH", None, False))

    # Double initial middle
    check("JOHN A B SMITH",        ParsedNCBOEName(None, "JOHN", "A B",  None,  "SMITH",    None,  False))

    # ED guard
    assert "EDWARD" not in str(parse_ncboe_gold_name("ED BROYHILL"))

    print("ncboe_name_parser: all self-tests passed")


if __name__ == "__main__":
    _self_tests()
