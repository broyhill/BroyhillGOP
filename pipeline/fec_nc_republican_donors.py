#!/usr/bin/env python3
"""
FEC NC Republican donor export via OpenFEC API (DataTrust-aligned).

Scope (Ed / Perplexity refinements):
  - All Republican federal candidates: NC House/Senate/President committees (types H, S, P) plus
    national Presidential (office=P, party=REP) principal committees — primaries and generals.
  - Principal-style committees only: committee_type in {'H','S','P'} (House, Senate, President).
  - Party REP only at candidate/committee discovery; Schedule A rows filtered to individual humans.
  - Exclude receipt types associated with committee transfers: 15E, 22Y, 11AI.
  - Adds normalization columns for DataTrust matching: norm_first, norm_last, norm_zip5,
    norm_street_num, employer_normalized, contributor_zip5.

API key (required):
  export OPENFEC_API_KEY="..."   # or FEC_API_KEY
  https://api.data.gov/signup/

Usage:
  python3 -m pipeline.fec_nc_republican_donors
  python3 -m pipeline.fec_nc_republican_donors --output ~/Downloads/NC_Republican_Donors_2015_2026.csv

See module docstring in-repo history for field mapping to DataTrust match keys.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

import pandas as pd
import requests

# ── Config ──────────────────────────────────────────────────────────
BASE_URL = "https://api.open.fec.gov/v1"
DEFAULT_CYCLES = [2016, 2018, 2020, 2022, 2024, 2026]
REQUEST_DELAY = 0.12
PER_PAGE = 100

ALLOWED_COMMITTEE_TYPES = frozenset({"H", "S", "P"})
EXCLUDED_RECEIPT_TYPES = frozenset({"15E", "22Y", "11AI"})

_STREET_NUM = re.compile(r"^[^\d]*(\d+)")


def _api_key() -> str:
    k = (os.environ.get("OPENFEC_API_KEY") or os.environ.get("FEC_API_KEY") or "").strip()
    if not k:
        print(
            "Set OPENFEC_API_KEY or FEC_API_KEY (https://api.data.gov/signup/)",
            file=sys.stderr,
        )
        sys.exit(1)
    return k


def _sleep_429(resp: requests.Response) -> bool:
    if resp.status_code == 429:
        print("    Rate limited (429) — sleeping 65s...")
        time.sleep(65)
        return True
    return False


def _get(path: str, params: dict[str, Any]) -> dict[str, Any]:
    params = {**params, "api_key": _api_key()}
    for _ in range(12):
        r = requests.get(f"{BASE_URL}{path}", params=params, timeout=120)
        if _sleep_429(r):
            continue
        r.raise_for_status()
        time.sleep(REQUEST_DELAY)
        return r.json()
    raise RuntimeError("Too many 429 responses")


def contributor_zip5(z: Any) -> str:
    if z is None or (isinstance(z, float) and pd.isna(z)):
        return ""
    s = re.sub(r"\D", "", str(z))
    return s[:5] if len(s) >= 5 else ""


def norm_street_num(street: Any) -> str:
    if street is None or not str(street).strip():
        return ""
    m = _STREET_NUM.search(str(street).strip())
    return m.group(1) if m else ""


def employer_normalized(emp: Any) -> str:
    if emp is None or (isinstance(emp, float) and pd.isna(emp)):
        return ""
    return str(emp).upper().strip()[:50]


def primary_or_general(desc: Any) -> str:
    if not desc:
        return ""
    u = str(desc).upper()
    if "PRIMARY" in u:
        return "PRIMARY"
    if "GENERAL" in u:
        return "GENERAL"
    if "RUNOFF" in u:
        return "RUNOFF"
    return "OTHER"


def is_individual_row(r: dict[str, Any]) -> bool:
    rt = (r.get("receipt_type") or "").strip().upper()
    if rt in EXCLUDED_RECEIPT_TYPES:
        return False
    et = (r.get("entity_type") or "").upper()
    ii = str(r.get("is_individual", "")).lower()
    if et == "IND" or ii in ("true", "t", "y", "yes", "1"):
        return True
    return False


def get_nc_hs_p_committees() -> list[dict[str, Any]]:
    """NC + REP + committee_type in H, S, P."""
    print("\n[Step 1a] NC Republican committees (types H/S/P only)...")
    out: list[dict[str, Any]] = []
    page = 1
    while True:
        data = _get(
            "/committees/",
            {"state": "NC", "party": "REP", "per_page": PER_PAGE, "page": page},
        )
        results = data.get("results") or []
        if not results:
            break
        for c in results:
            ct = (c.get("committee_type") or "").upper()
            if ct not in ALLOWED_COMMITTEE_TYPES:
                continue
            out.append(
                {
                    "committee_id": c["committee_id"],
                    "committee_name": c.get("name", ""),
                    "committee_type": ct,
                    "committee_type_full": c.get("committee_type_full", ""),
                    "designation_full": c.get("designation_full", ""),
                    "candidate_ids": c.get("candidate_ids") or [],
                }
            )
        pages = data.get("pagination", {}).get("pages") or 0
        if page >= pages:
            break
        page += 1
        print(f"  Page {page}/{pages} — {len(out)} H/S/P committees")
    print(f"  ✓ {len(out)} NC committees (H/S/P)\n")
    return out


def iter_presidential_rep_candidates(cycle: int):
    page = 1
    while True:
        data = _get(
            "/candidates/",
            {
                "office": "P",
                "party": "REP",
                "cycle": cycle,
                "per_page": PER_PAGE,
                "page": page,
                "sort": "name",
            },
        )
        rows = data.get("results") or []
        if not rows:
            break
        for c in rows:
            yield c
        pages = data.get("pagination", {}).get("pages") or 1
        if page >= pages:
            break
        page += 1


def principal_committees_for_candidate(candidate_id: str, cycle: int) -> list[dict[str, Any]]:
    """Principal campaign committees (designation P) for a presidential candidate."""
    found: list[dict[str, Any]] = []
    page = 1
    while True:
        data = _get(
            f"/candidate/{candidate_id}/committees/",
            {
                "cycle": cycle,
                "per_page": PER_PAGE,
                "page": page,
                "designation": "P",
            },
        )
        for c in data.get("results") or []:
            ct = (c.get("committee_type") or "").upper()
            if ct not in ALLOWED_COMMITTEE_TYPES:
                continue
            found.append(
                {
                    "committee_id": c["committee_id"],
                    "committee_name": c.get("name", ""),
                    "committee_type": ct,
                    "committee_type_full": c.get("committee_type_full", ""),
                    "designation_full": c.get("designation_full", ""),
                    "candidate_ids": c.get("candidate_ids") or [candidate_id],
                }
            )
        pages = data.get("pagination", {}).get("pages") or 0
        if page >= pages:
            break
        page += 1
    return found


def collect_all_committees(cycles: list[int]) -> dict[str, dict[str, Any]]:
    """Deduped committee_id -> meta."""
    by_id: dict[str, dict[str, Any]] = {}

    for cm in get_nc_hs_p_committees():
        by_id[cm["committee_id"]] = cm

    print("[Step 1b] National Republican Presidential committees (P), all cycles...")
    for cycle in cycles:
        n = 0
        for cand in iter_presidential_rep_candidates(cycle):
            cid = cand.get("candidate_id")
            if not cid:
                continue
            for cm in principal_committees_for_candidate(cid, cycle):
                if cm["committee_id"] not in by_id:
                    by_id[cm["committee_id"]] = cm
                    n += 1
            time.sleep(REQUEST_DELAY)
        print(f"  Cycle {cycle}: +{n} new presidential committees (running total {len(by_id)})")
    print(f"  ✓ Total unique committees: {len(by_id)}\n")
    return by_id


def get_candidate_details(candidate_id: str) -> dict[str, Any]:
    try:
        data = _get(f"/candidate/{candidate_id}/", {})
        results = data.get("results") or []
        if results:
            c = results[0]
            return {
                "candidate_office": (c.get("office") or "").upper(),
                "candidate_office_full": c.get("office_full", ""),
                "candidate_office_state": c.get("state", ""),
                "candidate_office_district": c.get("district", ""),
                "candidate_name": c.get("name", ""),
            }
    except Exception:
        pass
    return {
        "candidate_office": "",
        "candidate_office_full": "",
        "candidate_office_state": "",
        "candidate_office_district": "",
        "candidate_name": "",
    }


def pull_contributions_for_committee(committee_meta: dict[str, Any], cycle: int) -> list[dict[str, Any]]:
    committee_id = committee_meta["committee_id"]
    records: list[dict[str, Any]] = []
    last_index = None
    last_date = None
    guard = 0
    max_pages = 200_000

    while guard < max_pages:
        params: dict[str, Any] = {
            "committee_id": committee_id,
            "two_year_transaction_period": cycle,
            "is_individual": "true",
            "per_page": PER_PAGE,
            "sort": "contribution_receipt_date",
            "sort_hide_null": "true",
        }
        if last_index:
            params["last_index"] = last_index
        if last_date:
            params["last_contribution_receipt_date"] = last_date

        for _ in range(8):
            r = requests.get(f"{BASE_URL}/schedules/schedule_a/", params={**params, "api_key": _api_key()}, timeout=120)
            if _sleep_429(r):
                continue
            r.raise_for_status()
            time.sleep(REQUEST_DELAY)
            data = r.json()
            break
        else:
            raise RuntimeError("schedule_a fetch failed")

        results = data.get("results") or []
        if not results:
            break

        for row in results:
            if not is_individual_row(row):
                continue
            records.append(row)

        pag = data.get("pagination", {})
        li = pag.get("last_indexes") or {}
        last_index = li.get("last_index")
        last_date = li.get("last_contribution_receipt_date")
        if not last_index:
            break
        guard += 1

    return records


def flatten_record(
    result: dict[str, Any],
    committee_meta: dict[str, Any],
    candidate_meta: dict[str, Any],
    cycle: int,
) -> dict[str, Any]:
    cids = committee_meta.get("candidate_ids") or []
    candidate_id = result.get("candidate_id") or (cids[0] if cids else None)

    z = result.get("contributor_zip")
    z5 = contributor_zip5(z)
    fn = result.get("contributor_first_name") or ""
    ln = result.get("contributor_last_name") or ""

    return {
        "FEC_TransactionID": result.get("sub_id"),
        "FEC_CommitteeID": result.get("committee_id"),
        "FEC_CandidateID": candidate_id,
        "FEC_FilingTxnID": result.get("transaction_id"),
        "FEC_FileNumber": result.get("file_number"),
        "LastName": ln,
        "FirstName": fn,
        "MiddleName": result.get("contributor_middle_name"),
        "Suffix": result.get("contributor_suffix"),
        "FullName": result.get("contributor_name"),
        "AddressLine1": result.get("contributor_street_1"),
        "AddressLine2": result.get("contributor_street_2"),
        "City": result.get("contributor_city"),
        "State": result.get("contributor_state"),
        "Zip": z,
        "contributor_zip5": z5,
        "norm_first": str(fn).upper().strip(),
        "norm_last": str(ln).upper().strip(),
        "norm_zip5": z5,
        "norm_street_num": norm_street_num(result.get("contributor_street_1")),
        "employer_normalized": employer_normalized(result.get("contributor_employer")),
        "Employer": result.get("contributor_employer"),
        "Occupation": result.get("contributor_occupation"),
        "DonationAmount": result.get("contribution_receipt_amount"),
        "DonationDate": result.get("contribution_receipt_date"),
        "YTD_Total": result.get("contributor_aggregate_ytd"),
        "ElectionType": result.get("fec_election_type_desc"),
        "ElectionYear": result.get("fec_election_year"),
        "primary_or_general": primary_or_general(result.get("fec_election_type_desc")),
        "election_year": result.get("fec_election_year"),
        "Cycle": cycle,
        "CommitteeName": committee_meta["committee_name"],
        "committee_type": committee_meta.get("committee_type", ""),
        "CommitteeType": committee_meta.get("committee_type_full", ""),
        "CommitteeDesignation": committee_meta.get("designation_full", ""),
        "Party": "REP",
        "CandidateName": candidate_meta.get("candidate_name", ""),
        "candidate_office": candidate_meta.get("candidate_office", ""),
        "CandidateOffice": candidate_meta.get("candidate_office_full", ""),
        "candidate_office_state": candidate_meta.get("candidate_office_state", ""),
        "CandidateState": candidate_meta.get("candidate_office_state", ""),
        "CandidateDistrict": candidate_meta.get("candidate_office_district", ""),
        "receipt_type": result.get("receipt_type"),
        "EntityType": result.get("entity_type_desc"),
        "FEC_SourceDoc": result.get("pdf_url"),
        "FEC_ReportType": result.get("report_type"),
        "FEC_ReportYear": result.get("report_year"),
        "FEC_AmendmentIndicator": result.get("amendment_indicator"),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="FEC API — NC Republican donors + presidential REP")
    ap.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("NC_Republican_Donors_2015_2026.csv"),
        help="Output CSV path",
    )
    ap.add_argument(
        "--cycles",
        type=int,
        nargs="*",
        default=DEFAULT_CYCLES,
        help="Two-year transaction periods",
    )
    ap.add_argument("--checkpoint-every", type=int, default=50, help="Committees per checkpoint CSV")
    args = ap.parse_args()

    start = datetime.now()
    print(f"\nFEC NC Republican Donor Pull (API) — started {start:%Y-%m-%d %H:%M}")
    print("=" * 60)

    committees_by_id = collect_all_committees(args.cycles)
    committees = list(committees_by_id.values())
    if not committees:
        print("No committees found.")
        return 1

    print("[Step 2] Caching candidate details...")
    candidate_cache: dict[str, dict[str, Any]] = {}
    for c in committees:
        for cid in c.get("candidate_ids") or []:
            if cid not in candidate_cache:
                candidate_cache[cid] = get_candidate_details(cid)
                time.sleep(REQUEST_DELAY)
    print(f"  ✓ {len(candidate_cache)} candidates cached\n")

    all_rows: list[dict[str, Any]] = []
    total_cm = len(committees)

    for cycle in args.cycles:
        print(f"[Step 3] Cycle {cycle} — {total_cm} committees")
        cycle_count = 0
        for idx, committee_meta in enumerate(committees, 1):
            raw = pull_contributions_for_committee(committee_meta, cycle)
            cid_list = committee_meta.get("candidate_ids") or []
            cand_meta = candidate_cache.get(cid_list[0], {}) if cid_list else {}
            for r in raw:
                all_rows.append(flatten_record(r, committee_meta, cand_meta, cycle))
            cycle_count += len(raw)
            if raw:
                print(f"  [{idx}/{total_cm}] {committee_meta['committee_name'][:50]}: {len(raw):,}")
            if idx % args.checkpoint_every == 0 and all_rows:
                ck = Path(f"checkpoint_cycle{cycle}_cmte{idx}.csv")
                pd.DataFrame(all_rows).to_csv(ck, index=False)
                print(f"  💾 {ck} ({len(all_rows):,} rows)")
        print(f"  ✓ Cycle {cycle}: {cycle_count:,} raw contribution fetches\n")

    print(f"[Step 4] Finalizing {len(all_rows):,} rows...")
    df = pd.DataFrame(all_rows)
    before = len(df)
    df = df.drop_duplicates(subset=["FEC_TransactionID"])
    print(f"  Dropped {before - len(df):,} duplicate FEC_TransactionID")

    df["DonationDate"] = pd.to_datetime(df["DonationDate"], errors="coerce")
    df = df.sort_values("DonationDate", ascending=False)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(args.output, index=False)

    elapsed = datetime.now() - start
    print(f"\n{'=' * 60}")
    print("COMPLETE")
    print(f"  Records: {len(df):,}")
    print(f"  With AddressLine1: {df['AddressLine1'].notna().sum():,}")
    print(f"  Output: {args.output.resolve()}")
    print(f"  Elapsed: {str(elapsed).split('.')[0]}")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
