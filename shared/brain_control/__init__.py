"""
shared/brain_control

Helpers for interacting with the brain_control schema:
  - Health reporting (brain_control.ecosystem_health)
  - Cost tracking (brain_control function call costs)
  - Self-correction directives (read by services to honor pause/throttle)

Pattern matches NEXUS integration in 053_NEXUS_PLATFORM_INTEGRATION.sql
and the function call accounting from 002_brain_cost_accounting.sql.
"""

from .governance import (
    HealthReporter,
    CostAccountant,
    SelfCorrectionReader,
    AutomationDirective,
)

__all__ = [
    "HealthReporter",
    "CostAccountant",
    "SelfCorrectionReader",
    "AutomationDirective",
]
