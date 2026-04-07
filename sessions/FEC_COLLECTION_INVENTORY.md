# FEC Manual Download Collection — Complete Inventory
**Built by Ed Broyhill | April 5-6, 2026 | BroyhillGOP-Claude**
**All files: NC donors only, individual only, Republican candidates only**

---

## KNOWN GAPS — NOT IN COLLECTION

| Member | District | Years | Reason |
|--------|---------|-------|--------|
| **Mark Meadows** | NC-11 | 2013-2020 | Committee not findable in FEC system — archived or filed under unknown name |
| **Ted Budd (House)** | NC-13 | 2017-2023 | Committee C00614776 renamed to Senate committee — House/Senate data merged in same ID |

**Note on Ted Budd:** His House committee `C00614776` (TED BUDD FOR CONGRESS) was renamed to TED BUDD FOR SENATE. All his individual donor data — House AND Senate cycles — is captured under this single ID in the Senate batch (11,149 rows, $5.6M). So Budd House data IS included, just merged with Senate data under one committee ID.

**Note on Meadows:** His NC-11 individual donor file from 2013-2020 is genuinely missing. His donors may partially appear in the Trump files (he was a major MAGA organizer) and in NCSBE state-level data.

---

## TRUMP FILES (3 files)

| File | Rows | Total $ | Cycles | Committees |
|------|------|---------|--------|-----------|
| 2015-2018-TRUMP-INDIDUALS.csv | 42,795 | $6.8M | 2016, 2018 | C00580100, C00618371 |
| 2019-2020-Trump-NC-GOP-FEC.csv | 273,618 | $24.9M | 2020 | C00580100, C00618371 |
| 2022-2026-Trump-nc-individ-only.csv | 377,779 | $20.0M | 2022, 2024, 2026 | C00828541, C00867937, C00618371, C00580100 |
| **TRUMP TOTAL** | **694,192** | **$51.8M** | | |

**New committee discovered:** C00867937 — TRUMP 47 COMMITTEE, INC. ($6.2M, 273 NC donors, avg $22,877)

---

## US SENATE (3 files)

| File | Rows | Total $ | Committees |
|------|------|---------|-----------|
| tillis-burr-budd-2015-2026.numbers | 30,890 | $16.3M | Tillis C00545772, Budd C00614776, Burr C00385526 |
| WHATLEY-MCCRORY-2015-2026-US-SENATE-2.numbers | 7,604 | $5.6M | McCrory C00776757, Whatley C00913996, Eastman C00790550, Brown C00857110, Morrow C00931956 |
| GROUP-3-BROWN-MORROM-FEC-SENATE-2015-2026-3.csv | 666 | $573k | Eastman C00790550, Brown C00857110, Morrow C00931956 |
| **SENATE TOTAL** | **39,160** | **$22.5M** | |

---

## PRESIDENTIAL (2 files)

| File | Rows | Total $ | Committees |
|------|------|---------|-----------|
| group-1-pres-2015-2026.numbers | 3,960 | $1.6M | Rubio C00458844, Bush C00579458, Graham C00578757, Fiorina C00577312, Walker C00580480, Cruz Victory C00542423, Jindal C00580159, Christie C00580399, Santorum C00578492 |
| group-2-2015-2026-president.numbers | 1,594 | $427k | Vivek C00833913, Pence C00842039, Burgum C00842302, DeSantis C00841155, Rand Paul Victory C00545848, Weld C00700906, Elder C00839365, Perry C00500587 |
| **PRESIDENTIAL TOTAL** | **5,554** | **$2.0M** | |

**NOT IN COLLECTION (missing from presidential list):**
- Nikki Haley — no principal type=P committee found
- Tim Scott 2024 — no principal committee confirmed
- Mark Sanford 2020 — no committee found
- Huckabee, Pataki, Perry (Rick), Gilmore — not downloaded
- Walsh (Joe) 2020 — not downloaded

---

## US HOUSE (5 batches + Villaverde)

### Batch 1 — 20,476 rows | $20.8M
Hudson C00504522, Murphy C00699660 (Greg), Rouzer C00541979, Foxx C00386748, Tim Moore C00854398, McHenry C00337048, Harris C00693713 (Mark, multiple committees)

### Batch 2 — 12,196 rows | $10.7M
Bishop C00699660 (Dan), Walker C00543231, Edwards C00796433, Knott C00855361, Harrigan C00802298, Pittenger C00514513, Sandy Smith C00697250

### Batch 3 — 5,424 rows | $4.2M
Holding C00499236, McDowell C00860064, Bo Hines C00766162, Kelly Daughtry C00797563+C00864637, Ellmers C00471896, Todd Johnson C00613232

### Batch 4 — 2,443 rows | $2.1M
Buckhout C00853499, Castelli C00794495, Grey Mills C00862169, Scott Dacey C00649608, Michele Woodhouse C00795088, Lynda Bennett C00732099
**Note:** Cawthorn C00921486 — zero NC rows (raised out of state)

### Batch 5 — 412 rows | $198k
Lee Haywood C00732651, Julia Howard C00613968, Ali for Congress C00856948, Contogiannis C00810408, Michele Nix C00733220, Dan Barrett C00614487, Regan4Congress C00802355, Neese C00704064

### Villaverde — 104 rows | $94k
Villaverde C00789792

| **HOUSE TOTAL** | **41,055** | **$38.1M** | |

---

## GRAND TOTAL

| Category | Rows | Total $ |
|----------|------|---------|
| Trump | 694,192 | $51.8M |
| Senate | 39,160 | $22.5M |
| Presidential | 5,554 | $2.0M |
| House | 41,055 | $38.1M |
| **GRAND TOTAL** | **780,961** | **$114.4M** |

---

## Load Status
- [ ] All files need conversion from .numbers to .csv where applicable
- [ ] Load into public.fec_donations via Supabase
- [ ] Dedup on sub_id (unique constraint already added April 6 2026)
- [ ] Filter: contributor_state=NC, entity_type=INDIVIDUAL on load
- [ ] Existing fec_donations: 2,591,933 rows — sub_id unique constraint locks out duplicates

---
*Recorded by BroyhillGOP-Claude | April 6, 2026 2:02 AM EDT*
