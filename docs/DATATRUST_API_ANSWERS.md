# DataTrust API — Official Answers from Danny Gustafson & Zach Imel
## Received: April 3, 2026
## Contacts: Danny Gustafson dgustafson@gop.com | Zach Imel ZImel@gop.com 270-799-0923

---

## CONFIRMED ANSWERS

### IP Whitelist
- Server 2 (144.76.219.24) whitelist NOT NEEDED for API
- Whitelist is only required for SQL server access
- API works from any IP — no whitelist required

### RNCID in API (CRITICAL — CONFIRMED)
- RNCID IS returned in VoterFile API responses ✅
- StateVoterID IS returned in VoterFile API responses ✅
- Both are columns in the CSV flat file AND API (same columns)
- StateVoterID has NOW BEEN ADDED as a live API query parameter
- Other API query parameters: Cell, Landline, JurisdictionVoterID,
  StateLegUpperDistrict, StateLegLowerDistrict, CountyName

### Email Field
- CONFIRMED: DataTrust does NOT have emails for NC voters
- Not in raw voter file, not in ABEV
- Do not wait for email_dt — it will never come
- Remove email_dt from all future matching strategies

### Coalition IDs
- CONFIRMED: Only 7 coalition IDs exist for NC
- No additional coalition IDs will be added
- The 7 we have are the complete set

### Pre-built Matching
- No pre-built identity resolution or fuzzy matching endpoints in DataTrust API
- RNC has internal fuzzy matching but deferred to Zach Imel

### FactInitiativeContacts
- Carries RNC_RegID identifier — NOT RNCID
- Different identifier space — bridge via nc_datatrust if needed

### AcxiomConsumerData API
- Is a SUBSET of columns from the full flat file
- Not a separate/updated national feed
- Use the flat file for complete Acxiom data

### NC Build Alerts
- Danny will add Ed to the alert email for new NC builds
- Process: alert email → pull via API, SQL server, or download link
- No SFTP or webhook — alert email is the delivery mechanism

---

## ARCHITECTURE CHANGES REQUIRED

### Remove from strategy
- email_dt matching — confirmed does not exist
- Server 2 IP whitelist request — not needed for API
- Waiting for additional coalition IDs — confirmed 7 is final

### Add to strategy
- StateVoterID as live API query parameter (NEW — use immediately)
- RNCID as live API query parameter (confirmed)
- Subscribe to NC build alerts via Danny
- FactInitiativeContacts via RNC_RegID (not RNCID) bridge

### FEC matching strategy update
Without email_dt, the 6-anchor FEC matching strategy becomes 5 anchors:
1. RNCID direct ✅
2. StateVoterID bridge (nc_datatrust → nc_voters_fresh) ✅
3. Mailing zip vs reg zip ✅
4. Address number match ✅
5. ~~Email match~~ REMOVED — no email data in DataTrust NC
6. Name+zip against nc_voters_fresh (9,799 already matched) ✅

Residual unmatched (~75K) = genuinely hard to match.
Options: Zach's internal fuzzy matching (ask), or flag as historical_unmatched.

---

## CONTACTS AT RNC DATA TEAM
- Zach Imel: ZImel@gop.com | 270-799-0923
- Daniel Peletski: DPeletski@gop.com
- Danny Gustafson: dgustafson@gop.com | 517-281-8018
