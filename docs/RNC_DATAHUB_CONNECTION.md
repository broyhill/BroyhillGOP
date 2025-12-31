# RNC DATAHUB CONNECTION GUIDE
## BroyhillGOP Platform Integration

---

## CONNECTION DETAILS

### SQL Server Direct Access (Primary Method)
```
Server: rncazdwsql.cloudapp.net,52954
Authentication: SQL Server Authentication
Username: [from password.gop one-time link]
Password: [from password.gop one-time link]
```

### API Authentication
```
Endpoint: https://rncdatahubapi.gop/api/Authenticate
Method: POST
Headers: Content-Type: application/json
Body: {
    "clientId": "[YOUR_CLIENT_ID]",
    "clientSecret": "[YOUR_CLIENT_SECRET]"
}
Response: { "AccessTokenType": "Bearer", "AccessToken": "eyJ..." }
```

### Future API Endpoint (effective 1/16/26)
```
https://rncdhapi.azurewebsites.net/api/Authenticate
```

---

## CREDENTIALS

Store credentials in environment variables:
```bash
export RNC_CLIENT_ID="your-client-id"
export RNC_CLIENT_SECRET="your-client-secret"
export RNC_SQL_USER="your-sql-username"
export RNC_SQL_PASS="your-sql-password"
```

Credentials are stored in Claude memory and 1Password/password manager.

---

## IP WHITELIST STATUS

**Server IP:** `5.9.99.109` (Hetzner GEX44)
- Status: PENDING WHITELIST
- Contact: RNC Data team
- Once whitelisted: SQL Server connection will work

---

## PYTHON CONNECTION CODE

```python
import pyodbc
import os

# Connection string for RNC DataHub
conn_str = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=rncazdwsql.cloudapp.net,52954;"
    "DATABASE=<database_name>;"
    f"UID={os.environ['RNC_SQL_USER']};"
    f"PWD={os.environ['RNC_SQL_PASS']};"
    "TrustServerCertificate=yes;"
)

conn = pyodbc.connect(conn_str)
cursor = conn.cursor()

# Example: Get NC voters
cursor.execute("SELECT TOP 100 * FROM voters WHERE state = 'NC'")
rows = cursor.fetchall()
```

---

## AVAILABLE DATA (2,500+ fields per voter)

### Categories:
- **Core Voter Data**: Name, DOB, Address, Party, Registration
- **Vote History**: Presidential, Primary, General, Municipal
- **Contact Info**: Phones (with Neustar reliability), Email, DNC status
- **Demographics**: Age, Gender, Race, Education, Income, Occupation
- **Financial**: Home value, Homeowner status, Mortgage data
- **Political Modeling**: Partisanship score, Turnout probability, Issue positions
- **Acxiom Consumer Data**: Media habits, Charitable giving, Lifestyle
- **Geographic**: Districts, Precinct, Census data

### Coverage:
- 300+ million individuals
- 2,500+ data points each
- 85% mobile phone coverage
- 7.8M NC registered voters

---

## SYNC TO SUPABASE

Target tables:
- `datatrust_profiles` (schema exists)
- `datatrust_sync_log`
- `donor_datatrust_match`

---

*Last Updated: December 31, 2024*
