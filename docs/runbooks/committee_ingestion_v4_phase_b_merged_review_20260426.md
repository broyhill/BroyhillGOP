# Committee Ingestion V4 — merged Phase B dry-run

Generated: 2026-04-27T00:18:34

READ-ONLY identity QA. No Hetzner writes, no rnc/apply, no model/score.

## Canaries / preflight

| raw rows / clusters | 321348 / 98303 (expect 321348 / 98303) |
| staging | 293396 (exp 293396) v2_nulls 0 |
| spine 372171 rows / sum / rnc | 147 / 332631.30 / c45eeea9-663f-40e1-b0e7-a473baee794e |
| Ed 5005999 / Pope 5037665 | 40/155945.45 mel=0 ; 22/378114.05 kat=0 |
| multi_rnc >1 / cluster | 0 (expect 0) |

## Counts (merged rules)

| T4+T6 proposals (before last anchor) | 6645 |
| rejected by observed-last anchor | 0 |
| LEE-lookup anomaly (not anchor, DT last=LEE) | 0 rejected; 4 keep with DT LEE+anchor | 
| Pattern A recovered by parse (groups raw>1, norm classes=1) | 0 |
| rejected Pattern A (norm classes>1) clusters | 0 |
| Pattern B no recipient pair overlap clusters | 227 |
| allowed reused-rnc (recipient overlap) groups | 71 |
| T4_THIN_NO_RECIPIENT_EVIDENCE | 3657 |
| final apply_eligible **clusters** | 2761 |
| final apply_eligible **row coverage** | 19217 |
| held **clusters** | 3884 |
| held **rows** | 4758 |

## Spot checks

* **WOLF:** 0 WOLF-surname rows held (PatternA), review CSV
* **ELIZABETH SMITH line:** 0 ELIZ*+SMITH rows held (PatternB)

## Recommendation

**apply_eligible subset looks safe for later authorization** (tune threshold after review)

---
*CSV:* `committee_ingestion_v4_phase_b_merged_proposals_20260426.csv`
