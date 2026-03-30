# Session: March 28, 2026 — Repo Audit & Ecosystem Consolidation

**Time:** 2:35 PM EDT
**Agent:** Perplexity AI

---

## Finding: BroyhillGOP is the One Canonical Repo

Performed a full cross-repo diff between `broyhill/BroyhillGOP` (public) and
`broyhill/BroyhillGOP-ARCHIVE-DO-NOT-USE` (private) on March 28, 2026.

### Result: Zero migration needed.

`BroyhillGOP` already contains every file from the ARCHIVE — and 14 additional
files the ARCHIVE does not have.

### BroyhillGOP has 58 ecosystem Python files (ARCHIVE has 44):

Files present in BroyhillGOP but NOT in ARCHIVE (unique to canonical repo):
- `ecosystem_01_contact_import.py`
- `ecosystem_01_data_import_engine.py`
- `ecosystem_01_platform_social_import.py`
- `ecosystem_01_social_oauth_maximum_capture.py`
- `ecosystem_16b_voice_synthesis_ULTRA_complete.py`
- `ecosystem_19_social_media_integration_patch.py`
- `ecosystem_47_unified_voice_engine.py`
- `ecosystem_52_contact_intelligence_engine.py`
- `ecosystem_52_messaging_center_complete.py`
- `ecosystem_53_document_generation_complete.py`
- `ecosystem_54_calendar_scheduling_complete.py`
- `ecosystem_55_api_gateway_complete.py`
- `ecosystem_56_visitor_deanonymization_complete.py`
- `ecosystem_57_messaging_center_complete.py`

### Ecosystem Coverage (BroyhillGOP)

All ecosystems E00–E57 are present as Python files across two paths:
- `ecosystems/` (root-level)
- `backend/python/ecosystems/`

ECOSYSTEM_REPORTS docs exist for: E01–E12, E15–E17, E19–E22, E24–E26,
E28, E30–E48, E51–E55, E57.

### Repo Status Summary

| Repo | Status | Last Commit | Use? |
|------|--------|-------------|------|
| `broyhill/BroyhillGOP` | Public, active | Mar 25, 2026 | ✅ YES — canonical |
| `broyhill/BroyhillGOP-ARCHIVE-DO-NOT-USE` | Private, frozen | Feb 3, 2026 | ❌ NO — ignore |
| `broyhill/broyhillgop-index` | Public | Mar 13, 2026 | Reference only |
| `broyhill/donor-deduplication-supabase` | Public, frozen | Feb 3, 2026 | ❌ NOT active pipeline |

### Directive Going Forward

**Use only `broyhill/BroyhillGOP`.** The ARCHIVE is a frozen Feb 3 snapshot
and has been fully superseded. Do not reference, copy from, or sync with the
ARCHIVE repo.

---

*Recorded by Perplexity AI — March 28, 2026*
