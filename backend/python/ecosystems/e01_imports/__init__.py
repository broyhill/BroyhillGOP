"""
E01 Imports — supporting modules for ecosystem_01_donor_intelligence.

These are the import/ingest engines that previously lived as siblings under
ecosystems/ecosystem_01_*.py with the E01 prefix. They are NOT independent
ecosystems — they support E01's data ingestion needs:

  data_import_master      — master import controller, toggles, gating
  contact_file_ingest     — vCard / Outlook / Google contact file parsing
  social_oauth_capture    — social network OAuth + maximum-capture handlers
  social_graph_builder    — social graph builder + platform import engine

The canonical E01 entry point is ecosystems/ecosystem_01_donor_intelligence.py
which defines `grade_donor(rnc_regid) -> GradedDonor`.
"""
