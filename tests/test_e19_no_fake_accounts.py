"""
Test: every poster_id used by E19 resolves to a registered identity.

Red line — no fake accounts, no sock puppets. Verified by static AST scan
of the E19 codebase: any place that calls a publish/post primitive must
reference a poster_id from a registered_identities lookup, not a literal
or a generated UUID.
"""
from __future__ import annotations
import ast, sys, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class NoFakeAccountsTest(unittest.TestCase):
    """Verify that no E19 module fabricates a poster_id from thin air."""

    @classmethod
    def setUpClass(cls):
        cls.e19_files = sorted(
            (ROOT / "ecosystems").glob("ecosystem_19_*.py")
        )
        assert cls.e19_files, "No E19 files found"

    def test_e19_files_do_not_define_anonymous_poster_id_constants(self):
        """No top-level POSTER_ID = 'fake-uuid-...' style constants."""
        for f in self.e19_files:
            tree = ast.parse(f.read_text())
            for node in ast.walk(tree):
                if isinstance(node, ast.Assign):
                    for target in node.targets:
                        if (isinstance(target, ast.Name)
                            and "POSTER_ID" in target.id.upper()
                            and isinstance(node.value, ast.Constant)
                            and isinstance(node.value.value, str)):
                            self.fail(
                                f"{f.name} defines a hardcoded POSTER_ID — "
                                f"red-line violation. Poster IDs must come "
                                f"from registered_identities lookup."
                            )

    def test_e19_files_have_no_sock_puppet_helper_functions(self):
        """No function named like create_burner / generate_fake / sockpuppet."""
        forbidden = ("create_burner", "generate_fake_account", "sockpuppet",
                     "create_persona", "fabricate_account")
        for f in self.e19_files:
            tree = ast.parse(f.read_text())
            for node in ast.walk(tree):
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    for word in forbidden:
                        if word in node.name.lower():
                            self.fail(
                                f"{f.name} has forbidden function {node.name}() — "
                                f"red-line violation."
                            )

    def test_sub_weapon_registry_lists_no_unknown_sub_weapons(self):
        """SUB_WEAPONS_STATUS contains exactly the 8 sanctioned sub-weapons."""
        social = (ROOT / "ecosystems" / "ecosystem_19_social_media.py").read_text()
        tree = ast.parse(social)
        registry = None
        for node in ast.walk(tree):
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if isinstance(target, ast.Name) and target.id == "SUB_WEAPONS_STATUS":
                        registry = node.value
        self.assertIsNotNone(registry, "SUB_WEAPONS_STATUS not found")
        keys = {k.value for k in registry.keys}  # type: ignore[attr-defined]
        expected = {
            "E19-Organic", "E19-PaidAds", "E19-Retarget", "E19-Lookalike",
            "E19-PaidBoost", "E19-Live", "E19-Surrogate", "E19-Engage",
        }
        self.assertEqual(keys, expected,
                          "SUB_WEAPONS_STATUS keys must be exactly the 8 sanctioned sub-weapons")


if __name__ == "__main__":
    unittest.main()
