# NCBOE Pipeline — Code Verification Snippets

Per your request: exact lines for name parsing, dedup_key, and nc_voters column usage. **Verify these before running against production.**

---

## 1. Name Parsing — "LAST, FIRST" (import_ncboe_raw.py)

**Location:** `scripts/import_ncboe_raw.py` lines 53–61

```python
def _parse_name_last_first(val: str) -> tuple[str, str]:
    """Split 'LAST, FIRST' on first comma. Returns (last, first)."""
    if not val or not str(val).strip():
        return ("", "")
    s = str(val).strip()
    idx = s.find(",")
    if idx >= 0:
        return (s[:idx].strip(), s[idx + 1 :].strip())
    return (s, "")
```

**Usage (line 176):**
```python
last, first = _parse_name_last_first(donor_name_raw)
```

**Verification:** Uses `find(",")` — equivalent to `split(',', 1)`. For `"O'BRIEN, JAMES WILLIAM III"` → `last="O'BRIEN"`, `first="JAMES WILLIAM III"`. ✅ Correct.

---

## 2. Name Parsing — normalize_ncboe.py

**Location:** `scripts/normalize_ncboe.py` lines 47–55

```python
def _parse_last_first(donor_name: str) -> tuple[str, str]:
    """Split 'LAST, FIRST' on first comma."""
    if not donor_name or not str(donor_name).strip():
        return ("", "")
    s = str(donor_name).strip()
    idx = s.find(",")
    if idx >= 0:
        return (_norm_name(s[:idx]), _norm_name(s[idx + 1 :]))
    return (_norm_name(s), "")
```

**Note:** `_norm_name` lowercases and collapses spaces: `re.sub(r"\s+", " ", str(s).lower().strip())`. No punctuation stripping.

---

## 3. dedup_key Generation

**import_ncboe_raw.py:** Does **not** generate dedup_key. It writes to `nc_boe_donations_raw` with raw `donor_name` only.

**normalize_ncboe.py** (lines 161–164):

```python
last, first = _parse_last_first(r.get("donor_name") or "")
zip5 = _norm_zip(r.get("zip_code") or "")
dedup_key = f"{last}|{first}|{zip5}" if (last or first) else ""
```

Where:
- `_norm_name(s)`: `re.sub(r"\s+", " ", str(s).lower().strip())` — lowercase, strip, collapse spaces. **Does NOT strip punctuation** (e.g. `O'Brien` → `o'brien`).
- `_norm_zip(val)`: `re.sub(r"\D", "", str(val))[:5]` — digits only, first 5.

**Resulting dedup_key format:** `last|first|zip5` (e.g. `smith|john|27601`).

---

## 4. nc_voters Column Names Used

**match_ncgop_to_voters.py** and **normalize_ncboe.py**:

| Purpose   | nc_voters column | Usage |
|----------|------------------|--------|
| Voter ID | `statevoterid`   | `SET statevoterid = v.statevoterid` |
| Last name| `last_name`      | `LOWER(TRIM(v.last_name))` |
| First name | `first_name`  | `LOWER(TRIM(v.first_name))` |
| Zip      | `zip_code`       | `SUBSTRING(REGEXP_REPLACE(TRIM(COALESCE(v.zip_code, '')), '\D', '', 'g') FROM 1 FOR 5)` |
| City     | `res_city_desc`  | `LOWER(TRIM(v.res_city_desc))` (fallback match) |

**Verify:** Run schema query to confirm your nc_voters has `res_zip_code` (not `zip_code`).

**Verify against your schema:**
```sql
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'nc_voters' 
  AND column_name ILIKE ANY(ARRAY['%first%','%last%','%zip%','%city%','%voter%'])
ORDER BY column_name;
```

---

## 5. dedup_key Consistency

Only **normalize_ncboe.py** produces dedup_key. `import_ncboe_raw.py` does not. The raw table has no dedup_key; it is computed during ETL to norm.

For **build_donor_golden_records.py** and **build_contributions.py**, dedup_key is read from `norm.nc_boe_donations` — no separate computation. Consistency is guaranteed.
