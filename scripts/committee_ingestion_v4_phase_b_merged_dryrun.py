#!/usr/bin/env python3
"""
Committee Ingestion V4 — Phase B merged dry-run (authoritative).

READ-ONLY. No Hetzner writes, no rnc/match/apply. Identity-continuity QA only.

  BGOP_USE_SOCKET=1 sudo -u postgres env PYTHONPATH=  python3 scripts/committee_ingestion_v4_phase_b_merged_dryrun.py
  BGOP_PGPASSWORD=...  python3 scripts/committee_ingestion_v4_phase_b_merged_dryrun.py
  # Optional: set BGOP_OUT_DIR (default docs/runbooks) to stage outputs before copy.

Generates (fixed names under BGOP_OUT_DIR or docs/runbooks/):
  committee_ingestion_v4_phase_b_merged_review_20260426.md
  committee_ingestion_v4_phase_b_merged_proposals_20260426.csv
"""

from __future__ import annotations

import csv
import os
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

import psycopg2

def _out_dir() -> Path:
    p = Path(os.environ.get("BGOP_OUT_DIR", "docs/runbooks"))
    p.mkdir(parents=True, exist_ok=True)
    return p


def _out_paths() -> Tuple[Path, Path]:
    d = _out_dir()
    return (
        d / "committee_ingestion_v4_phase_b_merged_review_20260426.md",
        d / "committee_ingestion_v4_phase_b_merged_proposals_20260426.csv",
    )

T4_MAX_DISTINCT_RNC = 40
EXPECTED = dict(
    raw_r=321_348,
    raw_c=98_303,
    stg=293_396,
    spine=147,
    sum=Decimal("332631.30"),
    rnc="c45eeea9-663f-40e1-b0e7-a473baee794e",
)
ED, POPE = 5005999, 5037665

DSN = dict(
    host=os.environ.get("BGOP_PGHOST", "37.27.169.232"),
    port=int(os.environ.get("BGOP_PGPORT", "5432")),
    dbname=os.environ.get("BGOP_PGDATABASE", "postgres"),
    user=os.environ.get("BGOP_PGUSER", "postgres"),
    password=os.environ.get("BGOP_PGPASSWORD", ""),
)
_WS = re.compile(r"\s+")
_PX = re.compile(r"^[\*\.]+|[\*\.]+$")


def connect_ro():
    if os.environ.get("BGOP_USE_SOCKET"):
        c = psycopg2.connect("dbname=postgres user=postgres")
    elif DSN.get("password"):
        c = psycopg2.connect(**DSN)
    else:
        raise SystemExit("Set BGOP_PGPASSWORD or BGOP_USE_SOCKET=1 (run as postgres on server).")
    c.set_session(readonly=True, autocommit=True)
    return c


@dataclass
class ClusterRep:
    cluster_id_v2: int
    norm_first: str
    norm_middle: str
    norm_last: str
    norm_suffix: str
    norm_zip5: str


@dataclass
class DT:
    rnc: str
    sv: str
    first_name: str
    middle_name: str
    last_name: str
    name_suffix: str
    reg_zip5: Optional[str]
    mail_zip5: Optional[str]


@dataclass
class Row:
    cluster_id_v2: int
    tier: str
    line_reason: str
    cluster_rows: int
    cluster_total: Decimal
    rep: ClusterRep
    dt: DT
    cluster_observed_last_set: str = ""
    last_name_anchor_pass: bool = True
    rre: bool = False
    recipient_committee_ids: str = ""
    recipient_committee_names: str = ""
    recipient_candidate_names: str = ""
    reused_rnc_shared_committee_ids: str = ""
    reused_rnc_shared_candidate_names: str = ""
    reused_rnc_group_count: int = 0
    cross_cluster_reject: str = ""
    final_hold: str = ""
    apply_eligible: str = "NO"
    evidence_note: str = ""


def norm_up(s: Optional[str]) -> str:
    return (s or "").strip().upper()


def clean_field(s: str) -> str:
    s = norm_up(s)
    s = _WS.sub(" ", s)
    return " ".join(_PX.sub("", p) for p in s.split() if p).strip()


def same_fn(a: str, b: str) -> bool:
    a, b = clean_field(a), clean_field(b)
    if not a or not b:
        return True
    if a == b:
        return True
    if len(a) == 1 and a.isalpha() and b.startswith(a):
        return True
    if len(b) == 1 and b.isalpha() and a.startswith(b):
        return True
    fa, fb = (a.split() or [""])[0], (b.split() or [""])[0]
    if len(fa) == 1 and fa.isalpha() and fb.startswith(fa):
        return True
    if len(fb) == 1 and fb.isalpha() and fa.startswith(fb):
        return True
    return False


def _find(i: int, p: List[int]) -> int:
    while p[i] != i:
        p[i] = p[p[i]]
        i = p[i]
    return i


def _u(i: int, j: int, p: List[int]) -> None:
    ri, rj = _find(i, p), _find(j, p)
    if ri != rj:
        p[rj] = ri


def n_identity_classes(reps: List[ClusterRep]) -> int:
    n = len(reps)
    p = list(range(n))
    for i in range(n):
        for j in range(i + 1, n):
            a, b = reps[i], reps[j]
            if clean_field(a.norm_last) != clean_field(b.norm_last):
                continue
            if same_fn(a.norm_first, b.norm_first):
                _u(i, j, p)
    return len({_find(i, p) for i in range(n)})


def com_set(s: str) -> Set[str]:
    if not s:
        return set()
    return {x.strip() for x in s.split(" | ") if x and x.strip()}


def any_pair_share(sets: List[Set[str]]) -> Tuple[bool, List[str]]:
    s2 = [x for x in sets if x]
    for i, a in enumerate(s2):
        for b in s2[i + 1 :]:
            t = a & b
            if t:
                return True, sorted(t)[:20]
    return False, []


# --- T4+T6 engine (identical to stage-3) --------------------------------

def mcompat(a: str, b: str) -> bool:
    a, b = norm_up(a), norm_up(b)
    if not a or not b:
        return True
    if a == b or a[0] == b[0]:
        return True
    return False


def scompat(a: str, b: str) -> bool:
    a, b = norm_up(a), norm_up(b)
    if a and b and a != b:
        return False
    return True


def run() -> int:
    out_md, out_csv = _out_paths()
    conn = connect_ro()
    cur = conn.cursor()

    cur.execute("SELECT COUNT(*)::bigint, COALESCE(SUM(norm_amount),0) FROM raw.ncboe_donations WHERE cluster_id=372171;")
    sn, sm = cur.fetchone()
    sn, sm = int(sn), Decimal(str(sm))
    cur.execute("select max(rnc_regid) from raw.ncboe_donations where cluster_id=372171")
    mrn = cur.fetchone()[0]
    cur.execute("select count(*)::bigint from staging.ncboe_party_committee_donations;")
    (st2,) = cur.fetchone()
    st2 = int(st2)
    cur.execute("select count(*)::bigint from staging.ncboe_party_committee_donations where cluster_id_v2 is null;")
    (nv2,) = cur.fetchone()
    nv2 = int(nv2)
    cur.execute(
        """select count(*) from (select cluster_id_v2 from staging.ncboe_party_committee_donations
    where cluster_id_v2 is not null and rnc_regid_v2 is not null group by 1 having count(distinct rnc_regid_v2)>1) z"""
    )
    (mc,) = cur.fetchone()
    mc = int(mc)
    cur.execute("select count(*)::bigint, count(distinct cluster_id)::bigint from raw.ncboe_donations where cluster_id is not null;")
    raw_n, raw_c = [int(x) for x in cur.fetchone()]

    ed_mel = 0
    for cid, ex, bname in ((ED, 40, "MELANIE"), (POPE, 22, "KATHERINE")):
        cur.execute("select count(*)::bigint, coalesce(sum(norm_amount),0) from staging.ncboe_party_committee_donations where cluster_id_v2=%s", (cid,))
        er, es = cur.fetchone()
        cur.execute("select count(*) from staging.ncboe_party_committee_donations where cluster_id_v2=%s and upper(trim(coalesce(norm_first,'')))=%s", (cid, bname))
        (b,) = cur.fetchone()
        if cid == ED:
            ed_row, ed_sum, ed_mel = int(er), Decimal(str(es)), int(b)
        else:
            pope_row, pope_sum, pope_b = int(er), Decimal(str(es)), int(b)

    cur.execute(
        """select cluster_id_v2, count(*)::bigint, coalesce(sum(norm_amount),0)::numeric,
      count(*) filter (where rnc_regid_v2 is not null)::bigint
      from staging.ncboe_party_committee_donations where cluster_id_v2 is not null group by 1"""
    )
    stats: Dict[int, Tuple[int, Decimal, int]] = {}
    matched, unmatched = set(), set()
    for c, n, t, m in cur.fetchall():
        c = int(c)
        stats[c] = (int(n), Decimal(str(t)), int(m))
        (matched if m >= 1 else unmatched).add(c)

    cur.execute(
        """select distinct on (s.cluster_id_v2) s.cluster_id_v2,
   coalesce(upper(trim(s.norm_first::text)),''),
   coalesce(upper(trim(s.norm_middle::text)),''),
   coalesce(upper(trim(s.norm_last::text)),''),
   coalesce(upper(trim(s.norm_suffix::text)),''),
   coalesce(trim(s.norm_zip5::text), '')
   from staging.ncboe_party_committee_donations s
   where s.cluster_id_v2 is not null
   order by s.cluster_id_v2, s.norm_amount desc nulls last, s.norm_date desc nulls last, s.id"""
    )
    repm: Dict[int, ClusterRep] = {}
    for c, a, b, d, e, f in cur.fetchall():
        repm[int(c)] = ClusterRep(int(c), a, b, d, e, f)

    U = [repm[c] for c in sorted(unmatched) if c in repm and repm[c].norm_last and repm[c].norm_first]
    uids = sorted({x.cluster_id_v2 for x in U})

    cur.execute(
        """with uc as (select unnest(%s::bigint[]) as id),
  pairs as (select distinct upper(trim(d.norm_last)) as ln, upper(trim(d.norm_first)) as fn
    from staging.ncboe_party_committee_donations d where d.cluster_id_v2 in (select id from uc)
    and trim(d.norm_last)<>'' and trim(d.norm_first)<>'')
  select p.ln, p.fn, count(distinct dt.rnc_regid)::bigint
  from pairs p left join core.datatrust_voter_nc dt
    on upper(trim(dt.last_name))=p.ln and upper(trim(dt.first_name))=p.fn
  group by 1,2;""",
        (uids,),
    )
    dcnt = {(a, b): int(t) for a, b, t in cur.fetchall()}

    byp: Dict[Tuple[str, str], List[ClusterRep]] = {}
    for r in U:
        byp.setdefault((r.norm_last, r.norm_first), []).append(r)

    def _load_datatrust_cache(pairs: Set[Tuple[str, str]]) -> Dict[Tuple[str, str], List[DT]]:
        if not pairs:
            return {}
        lns, fns = zip(*sorted(pairs))
        cur.execute(
            """select
  upper(trim(last_name)), upper(trim(first_name)),
  rnc_regid::text, coalesce(state_voter_id::text,''),
  upper(trim(coalesce(first_name,''))), upper(trim(coalesce(middle_name,''))), upper(trim(coalesce(last_name,''))),
  upper(trim(coalesce(name_suffix,''))), reg_zip5::text, mail_zip5::text
  from core.datatrust_voter_nc
  where (upper(trim(last_name)), upper(trim(first_name)))
    in (select a, b from unnest(%s::text[], %s::text[]) as t(a, b))
  order by upper(trim(last_name)), upper(trim(first_name)), rnc_regid;""",
            (list(lns), list(fns)),
        )
        rnc_by_pair: Dict[Tuple[str, str], Dict[str, DT]] = defaultdict(dict)
        for t in cur.fetchall():
            ln, fn, rnc = t[0], t[1], t[2]
            k = (ln, fn)
            if rnc in rnc_by_pair[k]:
                continue
            rnc_by_pair[k][rnc] = DT(
                t[2], t[3], t[4], t[5], t[6], t[7], t[8], t[9]
            )
        out: Dict[Tuple[str, str], List[DT]] = {}
        for p in sorted(pairs):
            dct = rnc_by_pair.get(p) or {}
            out[p] = [dct[k] for k in sorted(dct)]
        return out

    t4_pair_keys: Set[Tuple[str, str]] = {
        (a, b)
        for a, b in byp
        if 1 <= dcnt.get((a, b), 0) <= T4_MAX_DISTINCT_RNC
    }
    cache: Dict[Tuple[str, str], List[DT]] = _load_datatrust_cache(t4_pair_keys)
    rows: List[Row] = []
    t4a: Dict[int, Row] = {}
    t4d = t4s = 0
    t6d = t6s = 0
    for (ln, fn), rlist in byp.items():
        d = dcnt.get((ln, fn), 0)
        raw: List[DT] = []
        if 1 <= d <= T4_MAX_DISTINCT_RNC:
            raw = cache.get((ln, fn), [])
        for rp in rlist:
            if d > T4_MAX_DISTINCT_RNC:
                t4d += 1
                continue
            flt = [x for x in raw if mcompat(rp.norm_middle, x.middle_name) and scompat(rp.norm_suffix, x.name_suffix)]
            u = {x.rnc for x in flt}
            if len(u) == 1 and flt:
                x0 = flt[0]
                n, t, _ = stats[rp.cluster_id_v2]
                rw = Row(
                    rp.cluster_id_v2, "T4", "T4;merged", n, t, rp, x0
                )
                rows.append(rw)
                t4a[rp.cluster_id_v2] = rw
            elif len(u) > 1:
                t4d += 1
            elif d > 0 and not flt:
                t4s += 1
    t4c = set(t4a.keys())
    for rp in U:
        if rp.cluster_id_v2 in t4c:
            continue
        d = dcnt.get((rp.norm_last, rp.norm_first), 0)
        if d != 1:
            if d > 1:
                t6d += 1
            continue
        raw = cache.get((rp.norm_last, rp.norm_first), [])
        if len(raw) != 1:
            continue
        b0 = raw[0]
        if not mcompat(rp.norm_middle, b0.middle_name) or not scompat(rp.norm_suffix, b0.name_suffix):
            t6s += 1
            continue
        n, t, _ = stats[rp.cluster_id_v2]
        w = Row(rp.cluster_id_v2, "T6", "T6;merged", n, t, rp, b0)
        rows.append(w)

    n_base = len(rows)
    cids = [r.cluster_id_v2 for r in rows]

    cur.execute(
        """select cluster_id_v2,
  string_agg(distinct upper(trim(coalesce(norm_last,''))), ' | ') as obs
  from staging.ncboe_party_committee_donations where cluster_id_v2=any(%s) and trim(coalesce(norm_last,''))<>''
  group by 1;""",
        (cids,),
    )
    lobs: Dict[int, str] = {int(a): b for a, b in cur.fetchall()}

    cur.execute(
        """select cluster_id_v2,
  string_agg(distinct nullif(trim(committee_sboe_id::text),''), ' | ') as cids
  from staging.ncboe_party_committee_donations where cluster_id_v2=any(%s) group by 1;""",
        (cids,),
    )
    rcid = {int(a): b or "" for a, b in cur.fetchall()}
    cur.execute(
        """select cluster_id_v2,
  string_agg(distinct substring(trim(coalesce(committee_name,'')) from 1 for 80), ' | ') as cnames
  from staging.ncboe_party_committee_donations where cluster_id_v2=any(%s) group by 1;""",
        (cids,),
    )
    rnm = {int(a): b or "" for a, b in cur.fetchall()}

    cur.execute(
        """select cluster_id_v2, string_agg(distinct trim(coalesce(candidate_referendum_name::text,'')),' | ')
  from staging.ncboe_party_committee_donations where cluster_id_v2=any(%s) group by 1;""",
        (cids,),
    )
    cnd: Dict[int, str] = {}
    for a, b in cur.fetchall():
        cnd[int(a)] = b or ""

    cur.execute(
        """with t as (
  select cluster_id_v2, nullif(trim(committee_sboe_id::text),'') c, count(*) c2
  from staging.ncboe_party_committee_donations
  where cluster_id_v2=any(%s) group by 1,2
)
  select cluster_id_v2, bool_or(c2>1) from t group by 1;""",
        (cids,),
    )
    rre_m = {int(a): bool(b) for a, b in cur.fetchall()}

    for r in rows:
        s = lobs.get(r.cluster_id_v2, "")
        r.cluster_observed_last_set = s[:2000]
        oset = {t.strip() for t in s.split(" | ") if t.strip()} if s else set()
        dtln = norm_up(r.dt.last_name)
        r.last_name_anchor_pass = (not dtln) or (dtln in oset) if oset else False
        r.recipient_committee_ids = (rcid.get(r.cluster_id_v2) or "")[:2000]
        r.recipient_committee_names = (rnm.get(r.cluster_id_v2) or "")[:2000]
        r.recipient_candidate_names = (cnd.get(r.cluster_id_v2) or "")[:2000]
        r.rre = rre_m.get(r.cluster_id_v2, False)

    anchor_reject_n = sum(1 for r in rows if not r.last_name_anchor_pass)
    lee_rej = sum(1 for r in rows if (not r.last_name_anchor_pass) and norm_up(r.dt.last_name) == "LEE")
    lee_kep = sum(1 for r in rows if r.last_name_anchor_pass and norm_up(r.dt.last_name) == "LEE")

    by_r: Dict[str, List[Row]] = {}
    for r in rows:
        if r.last_name_anchor_pass:
            by_r.setdefault(r.dt.rnc.lower().strip(), []).append(r)

    pat_a_rec = pat_a_rej = pat_b_rej = 0
    pat_b_allow = 0
    for r in rows:
        r.cross_cluster_reject = ""

    for rnc, plist in by_r.items():
        g = [p for p in plist if p.last_name_anchor_pass]
        cids_ = [p.cluster_id_v2 for p in g]
        for p in g:
            p.reused_rnc_group_count = max(1, len(g))
        if len(g) < 2:
            continue
        rr2 = [repm[c] for c in cids_ if c in repm]
        if not rr2:
            continue
        raw_p = len({(x.norm_first, x.norm_last) for x in rr2})
        ncl = n_identity_classes(rr2)
        if raw_p > 1 and ncl == 1:
            pat_a_rec += 1
        if ncl > 1:
            for p in g:
                p.cross_cluster_reject = "PatternA_mixed_norm_identity_after_parse"
            pat_a_rej += len(g)
            continue
        csets = [com_set(rcid.get(c) or "") for c in cids_]
        cand_sets = [
            {x.strip() for x in (cnd.get(c) or "").split(" | ") if (x or "").strip()}
            for c in cids_
        ]
        c_nonempty = [x for x in csets if x]
        cinter = (
            set.intersection(*c_nonempty)
            if c_nonempty
            else set()
        )
        cn_nonempty = [x for x in cand_sets if x]
        cndinter = set.intersection(*cn_nonempty) if cn_nonempty else set()
        shc = " | ".join(sorted(cinter)[:30])[:2000]
        shcand = " | ".join(sorted(cndinter)[:30])[:2000]
        for p in g:
            p.reused_rnc_shared_committee_ids = shc
            p.reused_rnc_shared_candidate_names = shcand
        ne2 = {(repm[c].norm_zip5 or "").strip() for c in cids_ if c in repm and (repm[c].norm_zip5 or "").strip()}
        com_ov, com_sh = any_pair_share(csets)
        pair_cand_ovl = any(
            bool((a) & (b)) for i, a in enumerate(cand_sets) for b in cand_sets[i + 1 :]
        )
        recipient_ok = com_ov or pair_cand_ovl
        if len(ne2) > 1 and (not recipient_ok):
            for p in g:
                p.cross_cluster_reject = "PatternB_multi_rep_zip_no_recipient_pair_overlap"
            pat_b_rej += len(g)
        elif len(ne2) > 1 and recipient_ok:
            pat_b_allow += 1
            for p in g:
                if com_sh:
                    p.reused_rnc_shared_committee_ids = " | ".join(com_sh)[:2000]

    t4_thin = 0
    for r in rows:
        r.final_hold = ""
        if not r.last_name_anchor_pass:
            r.final_hold = "DT_LAST_NOT_IN_OBSERVED_CLUSTER_LAST_SET"
        elif r.cross_cluster_reject:
            r.final_hold = r.cross_cluster_reject
        r.apply_eligible = "NO" if r.final_hold else "YES"
        r.evidence_note = ";".join(
            [_f for _f in [r.final_hold or "ok", f"rre={r.rre}"] if _f]
        )[:500]  # noqa: E501

    for r in rows:
        if r.apply_eligible == "NO":
            continue
        if r.tier == "T4" and not (r.rep.norm_middle or "").strip() and not (r.rep.norm_suffix or "").strip() and (not r.rre):  # noqa: E501
            t4_thin += 1
            r.final_hold = "T4_THIN_NO_RECIPIENT_EVIDENCE"
            r.apply_eligible = "NO"
            r.evidence_note = r.final_hold
    eli = [r for r in rows if r.apply_eligible == "YES"]
    hld = [r for r in rows if r.apply_eligible == "NO"]
    eli_rows, held_rows = sum(x.cluster_rows for x in eli), sum(x.cluster_rows for x in hld)

    wolf_held = sum(
        1
        for r in hld
        if r.cluster_id_v2 in repm and "WOLF" in norm_up(repm[r.cluster_id_v2].norm_last) and "PatternA" in (r.final_hold or "")
    )
    eliz_held = sum(
        1
        for r in hld
        if r.cluster_id_v2 in repm and "SMITH" in norm_up(repm[r.cluster_id_v2].norm_last) and "ELI" in norm_up(repm[r.cluster_id_v2].norm_first)  # noqa: E501
        and "PatternB" in (r.final_hold or "")
    )
    WOLF_ST = f"{wolf_held} WOLF-surname rows held (PatternA), review CSV"
    ELI_ST = f"{eliz_held} ELIZ*+SMITH rows held (PatternB)"
    if pat_a_rej + pat_b_rej + anchor_reject_n > 800:
        recmd = "needs more rule tightening"
    elif len(hld) > 0 and len(eli) < 800:
        recmd = "hold Phase B"
    else:
        recmd = "apply_eligible subset looks safe for later authorization"
    for r in rows:
        if not r.last_name_anchor_pass:
            r.reused_rnc_group_count = 0

    with out_csv.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(
            [
                "apply_eligible",
                "cross_cluster_reject",
                "hold_reason",
                "evidence_note",
                "last_name_anchor_pass",
                "repeated_recipient_evidence",
                "reused_rnc_group_count",
                "proposed_match_tier_v2",
                "cluster_id_v2",
                "proposed_rnc_regid_v2",
                "proposed_state_voter_id_v2",
                "cluster_observed_last_set",
                "dt_last_name",
                "recipient_committee_ids",
                "recipient_committee_names",
                "recipient_candidate_names",
                "reused_rnc_shared_committee_ids",
                "reused_rnc_shared_candidate_names",
            ]
        )
        for r in sorted(rows, key=lambda x: x.cluster_id_v2):
            w.writerow(
                [
                    r.apply_eligible,
                    r.cross_cluster_reject,
                    r.final_hold if r.apply_eligible == "NO" else "",
                    r.evidence_note,
                    r.last_name_anchor_pass,
                    r.rre,
                    r.reused_rnc_group_count,
                    r.tier,
                    r.cluster_id_v2,
                    r.dt.rnc,
                    r.dt.sv,
                    r.cluster_observed_last_set,
                    r.dt.last_name or "",
                    r.recipient_committee_ids,
                    r.recipient_committee_names,
                    r.recipient_candidate_names,
                    r.reused_rnc_shared_committee_ids,
                    r.reused_rnc_shared_candidate_names,
                ]
            )  # noqa: E501

    with out_md.open("w") as f:
        f.write(f"# Committee Ingestion V4 — merged Phase B dry-run\n\nGenerated: {datetime.now().isoformat(timespec='seconds')}\n\n")
        f.write("READ-ONLY identity QA. No Hetzner writes, no rnc/apply, no model/score.\n\n## Canaries / preflight\n\n")
        f.write(f"| raw rows / clusters | {raw_n} / {raw_c} (expect {EXPECTED['raw_r']} / {EXPECTED['raw_c']}) |\n")
        f.write(f"| staging | {st2} (exp {EXPECTED['stg']}) v2_nulls {nv2} |\n")
        f.write(f"| spine 372171 rows / sum / rnc | {sn} / {sm} / {mrn} |\n")
        f.write(f"| Ed {ED} / Pope {POPE} | {ed_row}/{ed_sum} mel={ed_mel} ; {pope_row}/{pope_sum} kat={pope_b} |\n")
        f.write(f"| multi_rnc >1 / cluster | {mc} (expect 0) |\n\n## Counts (merged rules)\n\n")
        f.write(f"| T4+T6 proposals (before last anchor) | {n_base} |\n")
        f.write(f"| rejected by observed-last anchor | {anchor_reject_n} |\n")
        f.write(f"| LEE-lookup anomaly (not anchor, DT last=LEE) | {lee_rej} rejected; {lee_kep} keep with DT LEE+anchor | \n")  # noqa: E501
        f.write(f"| Pattern A recovered by parse (groups raw>1, norm classes=1) | {pat_a_rec} |\n")
        f.write(f"| rejected Pattern A (norm classes>1) clusters | {pat_a_rej} |\n")
        f.write(f"| Pattern B no recipient pair overlap clusters | {pat_b_rej} |\n")
        f.write(f"| allowed reused-rnc (recipient overlap) groups | {pat_b_allow} |\n")
        f.write(f"| T4_THIN_NO_RECIPIENT_EVIDENCE | {t4_thin} |\n")
        f.write(f"| final apply_eligible **clusters** | {len(eli)} |\n")
        f.write(f"| final apply_eligible **row coverage** | {eli_rows} |\n")
        f.write(f"| held **clusters** | {len(hld)} |\n")
        f.write(f"| held **rows** | {held_rows} |\n\n## Spot checks\n\n* **WOLF:** {WOLF_ST}\n* **ELIZABETH SMITH line:** {ELI_ST}\n\n")
        f.write(
            f"## Recommendation\n\n**{recmd}** (tune threshold after review)\n\n---\n*CSV:* `{out_csv.name}`\n"
        )

    cur.close()
    conn.close()
    print(out_csv, out_md)
    return 0


if __name__ == "__main__":
    sys.exit(run())
