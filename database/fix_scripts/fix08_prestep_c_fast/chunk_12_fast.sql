-- fix_08 Pre-Step C chunk 12/14 (FAST version)
-- Uses ILIKE + regex ^ anchor instead of full ~* regex
-- rncid range: 24241847230 to 24242487230

SET statement_timeout = 0;
UPDATE nc_datatrust SET
  norm_first = UPPER(TRIM(firstname)),
  norm_last  = UPPER(TRIM(lastname)),
  norm_zip5  = LEFT(regzip5, 5),
  addr_type  = CASE
    WHEN registrationaddr1 ILIKE 'PO BOX%'
      OR registrationaddr1 ILIKE 'P.O. BOX%'
      OR registrationaddr1 ILIKE 'P O BOX%'
      OR registrationaddr1 ILIKE 'POB %'    THEN 'po_box'
    WHEN registrationaddr1 ILIKE 'RR %'
      OR registrationaddr1 ILIKE 'R.R.%'    THEN 'rural_route'
    WHEN registrationaddr1 ILIKE 'HC %'     THEN 'highway_contract'
    WHEN registrationaddr1 ~ '^[0-9]'       THEN 'street'
    ELSE 'unknown' END,
  norm_street_num = CASE
    WHEN registrationaddr1 ILIKE 'PO BOX%'
      OR registrationaddr1 ILIKE 'P.O. BOX%'
      OR registrationaddr1 ILIKE 'P O BOX%'
      THEN SUBSTRING(registrationaddr1 FROM '[0-9]+')
    WHEN registrationaddr1 ~ '^[0-9]'
      THEN SUBSTRING(registrationaddr1 FROM '^([0-9]+)')
    ELSE NULL END
WHERE rncid::bigint >= 24241847230 AND rncid::bigint < 24242487230
  AND norm_first IS NULL;