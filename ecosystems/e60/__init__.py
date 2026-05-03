"""
E60 — Nervous Net.

Fifth Brain Pentad module. Peer to E01, E19, E30, E11. Three sub-modules:

  cost_ledger.py   — universal CostEvent persistence (idempotent on event_id)
  iftt_engine.py   — rules engine; evaluates rules on every CostEvent and
                     on a periodic tick; emits RuleFired payloads.
  ml_optimizer.py  — LP problem statement + predictive model interfaces;
                     emits OptimizerDecision payloads to E11.

Public re-exports:
"""

from .cost_ledger import CostLedger, log_cost
from .iftt_engine import IFTTEngine, IFTTRule, SEED_RULES
from .ml_optimizer import MLOptimizer, OptimizerInputs, build_lp_problem_statement

__all__ = [
    "CostLedger", "log_cost",
    "IFTTEngine", "IFTTRule", "SEED_RULES",
    "MLOptimizer", "OptimizerInputs", "build_lp_problem_statement",
]
