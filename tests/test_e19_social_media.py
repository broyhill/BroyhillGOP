"""
Smoke tests for Section 3: E19 Social Media merged engine.

Verifies the three merged engines coexist correctly and the unified entry
point class structure is intact. These are import + structure smoke tests —
not full integration tests. Real platform API calls require live tokens
(Facebook GraphAPI, tweepy, linkedin_v2) which the harness does not provide.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

# Allow `import ecosystem_19_social_media` from repo-relative location
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "ecosystems"))


class ModuleStructureTest(unittest.TestCase):
    """All three engines + helpers must be importable from the merged module."""

    @classmethod
    def setUpClass(cls):
        # Note: the module imports facebook, tweepy, linkedin libraries from
        # _manager — these may not be installed in the test sandbox. We only
        # require that the module *parses* and that the class names are
        # discoverable by static AST inspection.
        import ast
        cls.src = (ROOT / "ecosystems" / "ecosystem_19_social_media.py").read_text()
        cls.tree = ast.parse(cls.src)
        cls.class_names = {
            n.name for n in ast.walk(cls.tree) if isinstance(n, ast.ClassDef)
        }

    def test_unified_entry_point_present(self):
        self.assertIn("SocialMediaEngine", self.class_names,
                     "Unified entry point SocialMediaEngine missing")

    def test_carousel_post_engine_present(self):
        self.assertIn("CarouselPostEngine", self.class_names,
                     "Renamed CarouselPostEngine (was _enhanced.SocialMediaEngine) missing")

    def test_platform_publisher_present(self):
        self.assertIn("PlatformPublisher", self.class_names,
                     "Renamed PlatformPublisher (was _manager.SocialMediaManager) missing")

    def test_helper_clients_present(self):
        self.assertIn("VoiceEngineClient", self.class_names)
        self.assertIn("VideoSynthesisClient", self.class_names)

    def test_dataclasses_present(self):
        for name in ("SocialVideoRequest", "NightlyPost", "CarouselSlide"):
            self.assertIn(name, self.class_names,
                         f"Dataclass {name} missing from merged file")

    def test_enums_present(self):
        for name in ("Platform", "PostType", "MediaType",
                     "PostPriority", "PostStatus", "VideoStatus"):
            self.assertIn(name, self.class_names,
                         f"Enum {name} missing from merged file")

    def test_no_old_class_names_remain(self):
        # The original class names should NOT survive the rename
        self.assertNotIn("SocialMediaIntegrationEngine", self.class_names,
                         "Old _patch entry-point name should have been renamed")
        self.assertNotIn("SocialMediaManager", self.class_names,
                         "Old _manager class name should have been renamed")
        # Note: SocialMediaEngine is the NEW name, so its presence is expected


class BrainEventHandlersTest(unittest.TestCase):
    """SocialMediaEngine must keep its brain-integration event handlers."""

    @classmethod
    def setUpClass(cls):
        import ast
        src = (ROOT / "ecosystems" / "ecosystem_19_social_media.py").read_text()
        tree = ast.parse(src)
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef) and node.name == "SocialMediaEngine":
                cls.method_names = {
                    m.name for m in node.body
                    if isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef))
                }
                return
        raise AssertionError("SocialMediaEngine class not found")

    def test_event_dispatcher_present(self):
        self.assertIn("handle_event", self.method_names)
        self.assertIn("start_event_listener", self.method_names)

    def test_brain_event_handlers_present(self):
        for handler in ("handle_crisis_response", "handle_positive_news",
                        "handle_opponent_gaffe", "handle_endorsement",
                        "handle_trending_topic"):
            self.assertIn(handler, self.method_names,
                         f"Brain event handler {handler} missing")

    def test_video_orchestration_handlers_present(self):
        for handler in ("request_ai_video", "handle_video_post_request",
                        "handle_video_ready"):
            self.assertIn(handler, self.method_names)

    def test_nightly_workflow_present(self):
        self.assertIn("run_nightly_workflow", self.method_names)
        self.assertIn("generate_nightly_posts", self.method_names)

    def test_sms_approval_flow_present(self):
        for handler in ("send_approval_sms", "handle_sms_reply",
                        "auto_approve_pending"):
            self.assertIn(handler, self.method_names)


class CarouselPostEngineTest(unittest.TestCase):
    """CarouselPostEngine must keep the carousel/post/compliance/analytics methods."""

    @classmethod
    def setUpClass(cls):
        import ast
        src = (ROOT / "ecosystems" / "ecosystem_19_social_media.py").read_text()
        tree = ast.parse(src)
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef) and node.name == "CarouselPostEngine":
                cls.method_names = {
                    m.name for m in node.body
                    if isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef))
                }
                return
        raise AssertionError("CarouselPostEngine class not found")

    def test_create_methods_present(self):
        self.assertIn("create_carousel_post", self.method_names)
        self.assertIn("create_single_post", self.method_names)

    def test_publish_methods_present(self):
        self.assertIn("publish_post", self.method_names)
        self.assertIn("_publish_carousel", self.method_names)
        self.assertIn("_publish_single", self.method_names)

    def test_compliance_present(self):
        self.assertIn("check_compliance", self.method_names)

    def test_analytics_methods_present(self):
        self.assertIn("record_engagement", self.method_names)
        self.assertIn("record_click", self.method_names)
        self.assertIn("get_carousel_analytics", self.method_names)


class PlatformPublisherTest(unittest.TestCase):
    """PlatformPublisher must keep all real-API platform handlers + token getters."""

    @classmethod
    def setUpClass(cls):
        import ast
        src = (ROOT / "ecosystems" / "ecosystem_19_social_media.py").read_text()
        tree = ast.parse(src)
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef) and node.name == "PlatformPublisher":
                cls.method_names = {
                    m.name for m in node.body
                    if isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef))
                }
                return
        raise AssertionError("PlatformPublisher class not found")

    def test_all_four_platform_handlers_present(self):
        for platform in ("facebook", "twitter", "instagram", "linkedin"):
            self.assertIn(f"publish_to_{platform}", self.method_names,
                         f"Platform handler publish_to_{platform} missing")

    def test_compliance_pipeline_present(self):
        for fn in ("run_compliance_checks", "check_duplicate_content",
                   "check_political_authorization", "log_compliance_check"):
            self.assertIn(fn, self.method_names)

    def test_token_getters_present(self):
        for getter in ("get_facebook_page_token", "get_twitter_credentials",
                       "get_instagram_account_id", "get_linkedin_token"):
            self.assertIn(getter, self.method_names)


if __name__ == "__main__":
    unittest.main()
