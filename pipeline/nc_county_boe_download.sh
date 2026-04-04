#!/bin/bash
# NC County BOE Campaign Finance — Full Download
# All 100 NC Counties — Individual Receipts 2010-2026
# Run on Hetzner: ssh -i /Users/Broyhill/.ssh/id_ed25519_hetzner root@5.9.99.109

mkdir -p /opt/broyhillgop/data/county_boe
cd /opt/broyhillgop/data/county_boe

# All 100 NC Counties
COUNTIES=(
  "ALAMANCE" "ALEXANDER" "ALLEGHANY" "ANSON" "ASHE" "AVERY" "BEAUFORT"
  "BERTIE" "BLADEN" "BRUNSWICK" "BUNCOMBE" "BURKE" "CABARRUS" "CALDWELL"
  "CAMDEN" "CARTERET" "CASWELL" "CATAWBA" "CHATHAM" "CHEROKEE" "CHOWAN"
  "CLAY" "CLEVELAND" "COLUMBUS" "CRAVEN" "CUMBERLAND" "CURRITUCK" "DARE"
  "DAVIDSON" "DAVIE" "DUPLIN" "DURHAM" "EDGECOMBE" "FORSYTH" "FRANKLIN"
  "GASTON" "GATES" "GRAHAM" "GRANVILLE" "GREENE" "GUILFORD" "HALIFAX"
  "HARNETT" "HAYWOOD" "HENDERSON" "HERTFORD" "HOKE" "HYDE" "IREDELL"
  "JACKSON" "JOHNSTON" "JONES" "LEE" "LENOIR" "LINCOLN" "MACON"
  "MADISON" "MARTIN" "MCDOWELL" "MECKLENBURG" "MITCHELL" "MONTGOMERY"
  "MOORE" "NASH" "NEWHANOVER" "NORTHAMPTON" "ONSLOW" "ORANGE" "PAMLICO"
  "PASQUOTANK" "PENDER" "PERQUIMANS" "PERSON" "PITT" "POLK" "RANDOLPH"
  "RICHMOND" "ROBESON" "ROCKINGHAM" "ROWAN" "RUTHERFORD" "SAMPSON"
  "SCOTLAND" "STANLY" "STOKES" "SURRY" "SWAIN" "TRANSYLVANIA" "TYRRELL"
  "UNION" "VANCE" "WAKE" "WARREN" "WASHINGTON" "WATAUGA" "WAYNE"
  "WILKES" "WILSON" "YADKIN" "YANCEY"
)

echo "Starting NC County BOE download — $(date)"
echo "Total counties: ${#COUNTIES[@]}"

for COUNTY in "${COUNTIES[@]}"; do
  OUTFILE="/opt/broyhillgop/data/county_boe/NC_BOE_${COUNTY}_2010_2026.csv"
  
  if [ -f "$OUTFILE" ] && [ -s "$OUTFILE" ]; then
    echo "SKIP $COUNTY — already exists ($(wc -l < $OUTFILE) rows)"
    continue
  fi
  
  echo "Downloading $COUNTY..."
  
  # NCSBE transaction search export — individual receipts
  curl -s \
    -X POST \
    "https://cf.ncsbe.gov/CFTxnLkup/ExportData/" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "Referer: https://cf.ncsbe.gov/CFTxnLkup/" \
    -H "User-Agent: Mozilla/5.0" \
    --data-urlencode "County=$COUNTY" \
    --data-urlencode "TransactionType=REC" \
    --data-urlencode "DateFrom=01/01/2010" \
    --data-urlencode "DateTo=04/03/2026" \
    --data-urlencode "IsOrganization=false" \
    -o "$OUTFILE" \
    --max-time 120
  
  ROWS=$(wc -l < "$OUTFILE" 2>/dev/null || echo "0")
  SIZE=$(ls -lah "$OUTFILE" 2>/dev/null | awk '{print $5}')
  echo "  $COUNTY: $ROWS rows, $SIZE"
  
  # Be polite — don't hammer the server
  sleep 3
done

echo ""
echo "Download complete — $(date)"
echo "Files:"
ls -lah /opt/broyhillgop/data/county_boe/ | grep -v total

echo ""
echo "Total rows across all counties:"
wc -l /opt/broyhillgop/data/county_boe/*.csv | tail -1
