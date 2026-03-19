-- 055_DONATION_SEARCH_VIEW.sql
-- Creates view and lookup for donation search page
-- Run: psql $SUPABASE_DB_URL -f database/migrations/055_DONATION_SEARCH_VIEW.sql

-- NC Zip-to-County lookup (populate from public data; sample rows for common NC zips)
CREATE TABLE IF NOT EXISTS public.nc_zip_county (
    zip5 VARCHAR(5) PRIMARY KEY,
    county VARCHAR(100) NOT NULL
);

-- Sample rows for major NC counties (user can bulk-load full list from NCSBE or USPS)
INSERT INTO public.nc_zip_county (zip5, county) VALUES
('27101','Forsyth'),('27103','Forsyth'),('27104','Forsyth'),('27105','Forsyth'),('27106','Forsyth'),
('27601','Wake'),('27603','Wake'),('27604','Wake'),('27605','Wake'),('27606','Wake'),('27607','Wake'),('27608','Wake'),('27609','Wake'),('27610','Wake'),('27612','Wake'),('27613','Wake'),('27614','Wake'),('27615','Wake'),('27616','Wake'),('27617','Wake'),
('28202','Mecklenburg'),('28203','Mecklenburg'),('28204','Mecklenburg'),('28205','Mecklenburg'),('28206','Mecklenburg'),('28207','Mecklenburg'),('28208','Mecklenburg'),('28209','Mecklenburg'),('28210','Mecklenburg'),('28211','Mecklenburg'),('28212','Mecklenburg'),('28213','Mecklenburg'),('28214','Mecklenburg'),('28215','Mecklenburg'),('28216','Mecklenburg'),('28217','Mecklenburg'),('28226','Mecklenburg'),('28227','Mecklenburg'),('28262','Mecklenburg'),('28269','Mecklenburg'),('28270','Mecklenburg'),('28273','Mecklenburg'),('28277','Mecklenburg'),('28278','Mecklenburg'),
('27401','Guilford'),('27402','Guilford'),('27403','Guilford'),('27405','Guilford'),('27406','Guilford'),('27407','Guilford'),('27408','Guilford'),('27409','Guilford'),('27410','Guilford'),('27455','Guilford'),
('28801','Buncombe'),('28803','Buncombe'),('28804','Buncombe'),('28805','Buncombe'),('28806','Buncombe'),
('28401','New Hanover'),('28403','New Hanover'),('28405','New Hanover'),('28409','New Hanover'),('28411','New Hanover'),('28412','New Hanover'),
('27012','Davie'),('27014','Davie'),('27016','Davie'),('27017','Davie'),('27018','Davie'),('27019','Davie'),('27020','Davie'),('27021','Davie'),('27022','Davie'),('27023','Davie'),('27024','Davie'),('27025','Davie'),('27027','Davie'),('27028','Davie'),('27030','Davie'),('27031','Davie'),('27040','Davie'),('27041','Davie'),('27043','Davie'),('27045','Davie'),('27046','Davie'),('27047','Davie'),('27048','Davie'),('27049','Davie'),('27050','Davie'),('27051','Davie'),('27052','Davie'),('27053','Davie'),('27054','Davie'),('27055','Davie')
ON CONFLICT (zip5) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_nc_zip_county_county ON public.nc_zip_county(county);

-- Donation search view: NCBOE state donations with county
CREATE OR REPLACE VIEW public.donation_search_ncboe AS
SELECT
    d.id,
    d.donor_name,
    d.amount_numeric AS amount,
    d.date_occurred,
    EXTRACT(YEAR FROM d.date_occurred)::INT AS donation_year,
    d.committee_name,
    d.committee_sboe_id,
    d.candidate_referendum_name AS candidate_name,
    d.transaction_type,
    d.city,
    d.state,
    d.zip_code,
    d.norm_city,
    d.norm_zip5,
    COALESCE(z.county, d.norm_city) AS county,
    'state' AS office_level
FROM public.nc_boe_donations_raw d
LEFT JOIN public.nc_zip_county z ON d.norm_zip5 = z.zip5
WHERE d.transaction_type = 'Individual'
  AND d.amount_numeric IS NOT NULL
  AND d.amount_numeric > 0
  AND d.date_occurred IS NOT NULL;

COMMENT ON VIEW public.donation_search_ncboe IS 'NC state donations for search UI; join nc_zip_county for county filter';
