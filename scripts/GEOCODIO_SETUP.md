# Geocodio Setup for BroyhillGOP

## 1. Register (FREE - No Credit Card)

Go to: https://dash.geocod.io/register

Create account with:
- Email: eddie@broyhillgop.com (or your preference)
- Password: (your choice)

## 2. Get API Key

After login, your API key is shown on the dashboard.
Copy it - looks like: abc123def456...

## 3. Set Environment Variable

SSH to server and run:
```bash
ssh root@5.9.99.109
export GEOCODIO_API_KEY='your_api_key_here'
```

Or add to .bashrc for persistence:
```bash
echo "export GEOCODIO_API_KEY='your_api_key_here'" >> ~/.bashrc
source ~/.bashrc
```

## 4. Test the API

```bash
cd /opt/broyhillgop/scripts
python3 geocodio_enrichment.py test
```

Expected output:
- ZIP+4 suffix
- Congressional district
- State Senate/House districts
- Lat/Long coordinates

## 5. Run Daily Enrichment (FREE)

Process 2,500 addresses per day for FREE:
```bash
python3 geocodio_enrichment.py full 2500
```

This will:
1. Export 2,500 donors needing enrichment
2. Send to Geocodio API
3. Update database with ZIP+4, districts, etc.

## 6. Pricing Summary

| Records | Cost | Time |
|---------|------|------|
| 2,500/day | FREE | ~45 days for 111K |
| 111,000 all at once | ~$55 | 1 day |

## 7. Data Returned

For each address, Geocodio returns:
- **zip_plus4**: 4-digit ZIP suffix (e.g., 2628)
- **zip9**: Full 9-digit ZIP (e.g., 27104-2628)
- **county_fips**: County FIPS code
- **latitude/longitude**: Coordinates
- **congressional_district**: US House district number
- **state_senate_district**: NC Senate district
- **state_house_district**: NC House district
- **census_tract**: Census tract code

## Need Help?

Geocodio support: support@geocod.io
Documentation: https://www.geocod.io/docs/
