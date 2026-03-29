-- fix_08 Pre-Step C chunk 1/14
-- rncid range: 24234807230 to 24235447230
-- Expected rows: ~500,000

SET statement_timeout = 0;
UPDATE nc_datatrust SET
  norm_first = UPPER(TRIM(firstname)),
  norm_last  = UPPER(TRIM(lastname)),
  norm_zip5  = LEFT(regzip5, 5),
  addr_type  = CASE
    WHEN registrationaddr1 ~* '^\s*P\.?O\.?\s*BOX' THEN 'po_box'
    WHEN registrationaddr1 ~* '^\s*R\.?R\.?\s*\d'  THEN 'rural_route'
    WHEN registrationaddr1 ~* '^\s*HC\s*\d'         THEN 'highway_contract'
    WHEN registrationaddr1 ~* '^\d'                  THEN 'street'
    ELSE 'unknown' END,
  norm_street_num = CASE
    WHEN registrationaddr1 ~* '^\s*P\.?O\.?\s*BOX'
      THEN REGEXP_REPLACE(registrationaddr1, '.*BOX\s*(\d+).*', '\1', 'i')
    WHEN registrationaddr1 ~* '^\d'
      THEN REGEXP_REPLACE(registrationaddr1, '^(\d+).*', '\1')
    ELSE NULL END
WHERE rncid::bigint >= 24234807230 AND rncid::bigint < 24235447230
  AND norm_first IS NULL;