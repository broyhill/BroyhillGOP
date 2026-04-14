"""
NCBOE GOLD CSV — exact header strings (including NCBOE typos).

Do not 'fix' Transction / Occured when reading files. Use these keys for DictReader.
"""

from __future__ import annotations

# Order matches NCBOE column positions 1–24 per sessions/SESSION_APRIL12_2026.md
NCBOE_GOLD_HEADERS: tuple[str, ...] = (
    "Name",
    "Street Line 1",
    "Street Line 2",
    "City",
    "State",
    "Zip Code",
    "Profession/Job Title",
    "Employer's Name/Specific Field",
    "Transction Type",  # typo: missing 'a'
    "Committee Name",
    "Committee SBoE ID",
    "Committee Street 1",
    "Committee Street 2",
    "Committee City",
    "Committee State",
    "Committee Zip Code",
    "Report Name",
    "Date Occured",  # typo: missing 'r'
    "Account Code",
    "Amount",
    "Form of Payment",
    "Purpose",
    "Candidate/Referendum Name",
    "Declaration",
)

# Map exact CSV header → raw.ncboe_donations column name in PostgreSQL
HEADER_TO_DB_COLUMN: dict[str, str] = {
    "Name": "name",
    "Street Line 1": "street_line_1",
    "Street Line 2": "street_line_2",
    "City": "city",
    "State": "state",
    "Zip Code": "zip_code",
    "Profession/Job Title": "profession_job_title",
    "Employer's Name/Specific Field": "employer_name",
    "Transction Type": "transction_type",
    "Committee Name": "committee_name",
    "Committee SBoE ID": "committee_sboe_id",
    "Committee Street 1": "committee_street_1",
    "Committee Street 2": "committee_street_2",
    "Committee City": "committee_city",
    "Committee State": "committee_state",
    "Committee Zip Code": "committee_zip_code",
    "Report Name": "report_name",
    "Date Occured": "date_occured",
    "Account Code": "account_code",
    "Amount": "amount",
    "Form of Payment": "form_of_payment",
    "Purpose": "purpose",
    "Candidate/Referendum Name": "candidate_referendum_name",
    "Declaration": "declaration",
}


def normalize_header_key(h: str) -> str:
    """Strip BOM/whitespace for fuzzy match; prefer exact NCBOE_GOLD_HEADERS."""
    return (h or "").replace("\ufeff", "").strip()
