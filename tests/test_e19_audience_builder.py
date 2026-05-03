"""Test: donor-list audience hashes correctly for Meta upload."""
from __future__ import annotations
import hashlib, sys, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "ecosystems"))

from ecosystem_19_audience_builder import (
    Audience, CustomAudienceBuilder, _normalize_phone_e164,
)


_DONORS = [
    {"rnc_regid": "R1", "email": "Ed@Broyhill.NET", "phone": "9195551212",
     "match_tier": "A_EXACT"},
    {"rnc_regid": "R2", "email": "jane.doe@example.com", "phone": "(704) 555-3434",
     "match_tier": "B_ALIAS"},
    {"rnc_regid": "R3", "email": "spouse@example.com", "phone": "1-800-5550100",
     "match_tier": "C_FIRST3"},  # should be filtered out — below threshold
]


class AudienceBuilderTest(unittest.TestCase):
    def test_filters_to_a_exact_b_alias(self):
        b = CustomAudienceBuilder(candidate_id="cand-1")
        aud = b.from_donor_list(["R1", "R2", "R3"], members=_DONORS)
        ids = {m["rnc_regid"] for m in aud.members}
        self.assertEqual(ids, {"R1", "R2"})  # R3 filtered (C_FIRST3)
        self.assertEqual(aud.rnc_regid_count, 2)

    def test_meta_format_hashes_lowercased_email(self):
        b = CustomAudienceBuilder(candidate_id="cand-1")
        aud = b.from_donor_list(["R1"], members=_DONORS)
        hashed = aud.to_meta_format()
        expected = hashlib.sha256(b"ed@broyhill.net").hexdigest()
        self.assertIn(expected, hashed)

    def test_meta_format_email_is_trimmed(self):
        b = CustomAudienceBuilder(candidate_id="cand-1")
        aud = b.from_donor_list(["RX"],
                                members=[{"rnc_regid": "RX",
                                          "email": "  test@example.com  ",
                                          "match_tier": "A_EXACT"}])
        hashed = aud.to_meta_format()
        expected = hashlib.sha256(b"test@example.com").hexdigest()
        self.assertEqual(hashed, [expected])

    def test_google_customer_match_format(self):
        b = CustomAudienceBuilder(candidate_id="cand-1")
        aud = b.from_donor_list(["R1"], members=_DONORS)
        # Google Customer Match uses the same SHA-256 of lowercased email.
        self.assertEqual(aud.to_google_customer_match(), aud.to_meta_format())

    def test_tiktok_format_includes_phone_hash(self):
        b = CustomAudienceBuilder(candidate_id="cand-1")
        aud = b.from_donor_list(["R1"], members=_DONORS)
        rec = aud.to_tiktok_custom_audience()[0]
        self.assertIn("email_sha256", rec)
        self.assertIn("phone_sha256", rec)

    def test_phone_e164_normalization(self):
        self.assertEqual(_normalize_phone_e164("9195551212"), "+19195551212")
        self.assertEqual(_normalize_phone_e164("(919) 555-1212"), "+19195551212")
        self.assertEqual(_normalize_phone_e164("1-919-555-1212"), "+19195551212")
        self.assertEqual(_normalize_phone_e164("+1 919-555-1212"), "+19195551212")
        self.assertIsNone(_normalize_phone_e164("123"))  # too short

    def test_lookalike_requires_valid_similarity(self):
        b = CustomAudienceBuilder(candidate_id="cand-1")
        seed = b.from_donor_list(["R1"], members=_DONORS)
        with self.assertRaises(ValueError):
            b.lookalike(seed, similarity=1.5)
        with self.assertRaises(ValueError):
            b.lookalike(seed, similarity=-0.1)

    def test_lookalike_returns_audience_with_seed_metadata(self):
        b = CustomAudienceBuilder(candidate_id="cand-1")
        seed = b.from_donor_list(["R1"], members=_DONORS)
        la = b.lookalike(seed, similarity=0.5)
        self.assertEqual(la.audience_type, "lookalike")
        self.assertEqual(la.source_filter["seed_audience_id"], seed.audience_id)
        self.assertEqual(la.source_filter["similarity"], 0.5)


if __name__ == "__main__":
    unittest.main()
