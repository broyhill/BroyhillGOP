"""
BroyhillGOP E59 Agent Mesh - Complete Python Agent Framework

A distributed agent framework for monitoring 58 ecosystems (E00-E58) of the
BroyhillGOP political CRM platform. Runs on Hetzner AX162-R server (96 cores,
252GB RAM) at 37.27.169.232.

Components:
- base_agent.py: Base EcosystemAgent class with async monitoring loops
- rule_engine.py: Rule evaluation engine with hot-reload support
- supervisor.py: Master process managing all agents
- control_api.py: FastAPI REST API for control panel
- brain_integration.py: Integration with E20 Brain and E21 ML
- notifier.py: Multi-channel notification system
- cost_tracker.py: Cost tracking and budget optimization

Usage:
    from base_agent import EcosystemAgent
    from supervisor import AgentSupervisor

    # Create supervisor
    supervisor = AgentSupervisor(
        supabase_url=os.getenv("SUPABASE_URL"),
        supabase_key=os.getenv("SUPABASE_KEY")
    )

    # Run
    asyncio.run(supervisor.run())
"""

from base_agent import EcosystemAgent
from brain_integration import BrainConnector
from control_api import ControlAPI
from cost_tracker import CostTracker
from notifier import Notifier
from rule_engine import RuleEngine
from supervisor import AgentSupervisor

__version__ = "1.0.0"
__all__ = [
    "EcosystemAgent",
    "RuleEngine",
    "AgentSupervisor",
    "ControlAPI",
    "BrainConnector",
    "Notifier",
    "CostTracker",
]
