"""
Cost Tracking for BroyhillGOP E59 Agent Mesh system.
Tracks API costs, calculates variance, and optimizes budget allocation.
"""

import json
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

import httpx
import numpy as np

logger = logging.getLogger(__name__)


class CostTracker:
    """
    Tracks costs, budgets, and variance across ecosystems.
    Provides optimization recommendations using linear programming.
    """

    def __init__(
        self,
        supabase_url: str,
        supabase_key: str,
        http_client: httpx.AsyncClient,
    ):
        """
        Initialize cost tracker.

        Args:
            supabase_url: Supabase URL
            supabase_key: Supabase API key
            http_client: Async HTTP client
        """
        self.supabase_url = supabase_url
        self.supabase_key = supabase_key
        self.client = http_client

        # In-memory tracking
        self.ecosystem_costs: Dict[str, Dict[str, Any]] = {}

    async def track_api_call(
        self,
        ecosystem_id: str,
        api_type: str,
        cost: float,
        record_count: int = 1,
    ) -> None:
        """
        Track an API call cost.

        Args:
            ecosystem_id: Ecosystem ID
            api_type: Type of API (read, write, compute, storage)
            cost: Cost in dollars
            record_count: Number of records affected
        """
        try:
            headers = self._get_headers()

            cost_record = {
                "ecosystem_id": ecosystem_id,
                "api_type": api_type,
                "cost": cost,
                "record_count": record_count,
                "cost_per_record": cost / record_count if record_count > 0 else 0,
                "timestamp": datetime.utcnow().isoformat(),
            }

            url = f"{self.supabase_url}/rest/v1/agent_cost_tracking"
            response = await self.client.post(url, json=cost_record, headers=headers)

            if response.status_code in (200, 201):
                logger.debug(f"Tracked cost for {ecosystem_id}: ${cost}")
            else:
                logger.warning(f"Failed to track cost: {response.status_code}")
        except Exception as e:
            logger.error(f"Error tracking API call: {e}", exc_info=True)

    async def get_cost_summary(self, ecosystem_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Get cost summary for ecosystem(s).

        Args:
            ecosystem_id: Optional ecosystem ID for specific summary

        Returns:
            Cost summary dictionary
        """
        try:
            headers = self._get_headers()

            if ecosystem_id:
                url = (
                    f"{self.supabase_url}/rest/v1/agent_cost_tracking"
                    f"?ecosystem_id=eq.{ecosystem_id}&select=*"
                )
            else:
                url = f"{self.supabase_url}/rest/v1/agent_cost_tracking?select=*"

            response = await self.client.get(url, headers=headers)

            if response.status_code == 200:
                costs = response.json()

                total_cost = sum(float(c.get("cost", 0)) for c in costs)
                total_records = sum(int(c.get("record_count", 0)) for c in costs)

                summary = {
                    "total_cost": total_cost,
                    "total_records": total_records,
                    "average_cost_per_record": total_cost / total_records if total_records > 0 else 0,
                    "cost_breakdown": self._group_costs_by_type(costs),
                }

                return summary
            else:
                logger.warning(f"Failed to get cost summary: {response.status_code}")
                return {}
        except Exception as e:
            logger.error(f"Error getting cost summary: {e}", exc_info=True)
            return {}

    async def calculate_variance(self) -> Dict[str, Any]:
        """
        Calculate budget vs actual variance.

        Returns:
            Variance report
        """
        try:
            headers = self._get_headers()

            # Get all cost records
            url = f"{self.supabase_url}/rest/v1/agent_cost_tracking?select=*"
            cost_response = await self.client.get(url, headers=headers)

            # Get all budget records
            url = f"{self.supabase_url}/rest/v1/agent_budgets?select=*"
            budget_response = await self.client.get(url, headers=headers)

            if cost_response.status_code != 200 or budget_response.status_code != 200:
                return {}

            costs = cost_response.json()
            budgets = budget_response.json()

            variances = {}
            total_variance = 0
            over_budget_count = 0

            # Map budgets by ecosystem
            budget_map = {b["ecosystem_id"]: float(b.get("monthly_limit", 0)) for b in budgets}

            # Calculate variance per ecosystem
            for ecosystem_id, budget in budget_map.items():
                actual = sum(
                    float(c.get("cost", 0)) for c in costs
                    if c.get("ecosystem_id") == ecosystem_id
                )

                variance = budget - actual
                variance_percent = (variance / budget * 100) if budget > 0 else 0

                variances[ecosystem_id] = {
                    "budget": budget,
                    "actual": actual,
                    "variance": variance,
                    "variance_percent": variance_percent,
                    "status": "over_budget" if variance < 0 else "under_budget",
                }

                if variance < 0:
                    over_budget_count += 1

                total_variance += variance

            report = {
                "timestamp": datetime.utcnow().isoformat(),
                "total_budget": sum(budget_map.values()),
                "total_actual": sum(
                    float(c.get("cost", 0)) for c in costs
                ),
                "total_variance": total_variance,
                "variance_percent": (
                    (total_variance / sum(budget_map.values()) * 100)
                    if sum(budget_map.values()) > 0 else 0
                ),
                "ecosystems_over_budget": over_budget_count,
                "variances_by_ecosystem": variances,
            }

            logger.info(f"Variance report generated: ${total_variance} variance")
            return report
        except Exception as e:
            logger.error(f"Error calculating variance: {e}", exc_info=True)
            return {}

    async def optimize_budget_allocation(self, total_budget: float) -> Dict[str, float]:
        """
        Optimize budget allocation using linear programming.
        Allocates budget based on ROI and historical costs.

        Args:
            total_budget: Total budget to allocate

        Returns:
            Optimal allocation by ecosystem
        """
        try:
            # Get historical cost and ROI data
            headers = self._get_headers()

            url = f"{self.supabase_url}/rest/v1/agent_cost_tracking?select=*"
            cost_response = await self.client.get(url, headers=headers)

            url = f"{self.supabase_url}/rest/v1/agent_roi?select=*"
            roi_response = await self.client.get(url, headers=headers)

            if cost_response.status_code != 200 or roi_response.status_code != 200:
                logger.warning("Could not optimize: missing data")
                return {}

            costs = cost_response.json()
            roi_data = roi_response.json()

            # Group costs by ecosystem
            ecosystem_costs = {}
            for cost in costs:
                eco_id = cost["ecosystem_id"]
                if eco_id not in ecosystem_costs:
                    ecosystem_costs[eco_id] = 0
                ecosystem_costs[eco_id] += float(cost.get("cost", 0))

            # Map ROI
            roi_map = {r["ecosystem_id"]: float(r.get("roi_score", 0.5)) for r in roi_data}

            # Simple allocation: weighted by ROI
            allocations = {}
            total_roi = sum(roi_map.values())

            if total_roi == 0:
                # Equal allocation if no ROI data
                per_eco = total_budget / len(ecosystem_costs)
                allocations = {eco: per_eco for eco in ecosystem_costs.keys()}
            else:
                # Allocate proportionally to ROI
                for eco_id, roi_score in roi_map.items():
                    allocation = (roi_score / total_roi) * total_budget
                    allocations[eco_id] = allocation

            logger.info(f"Optimized budget allocation: {allocations}")
            return allocations
        except Exception as e:
            logger.error(f"Error optimizing budget allocation: {e}", exc_info=True)
            return {}

    def _group_costs_by_type(self, costs: List[Dict[str, Any]]) -> Dict[str, float]:
        """Group costs by API type."""
        grouped = {}

        for cost in costs:
            api_type = cost.get("api_type", "unknown")
            if api_type not in grouped:
                grouped[api_type] = 0
            grouped[api_type] += float(cost.get("cost", 0))

        return grouped

    async def generate_variance_report(self) -> str:
        """
        Generate human-readable variance report.

        Returns:
            Report as formatted string
        """
        try:
            variance_data = await self.calculate_variance()

            report_lines = [
                "=== BUDGET VARIANCE REPORT ===",
                f"Timestamp: {variance_data.get('timestamp')}",
                "",
                f"Total Budget: ${variance_data.get('total_budget', 0):.2f}",
                f"Total Actual: ${variance_data.get('total_actual', 0):.2f}",
                f"Total Variance: ${variance_data.get('total_variance', 0):.2f}",
                f"Variance %: {variance_data.get('variance_percent', 0):.1f}%",
                f"Ecosystems Over Budget: {variance_data.get('ecosystems_over_budget', 0)}",
                "",
                "=== BY ECOSYSTEM ===",
            ]

            for eco_id, variance in variance_data.get("variances_by_ecosystem", {}).items():
                report_lines.append(f"\n{eco_id}:")
                report_lines.append(f"  Budget: ${variance['budget']:.2f}")
                report_lines.append(f"  Actual: ${variance['actual']:.2f}")
                report_lines.append(f"  Variance: ${variance['variance']:.2f} ({variance['variance_percent']:.1f}%)")
                report_lines.append(f"  Status: {variance['status']}")

            return "\n".join(report_lines)
        except Exception as e:
            logger.error(f"Error generating variance report: {e}", exc_info=True)
            return "Error generating report"

    def _get_headers(self) -> Dict[str, str]:
        """Get headers for Supabase."""
        return {
            "apikey": self.supabase_key,
            "Authorization": f"Bearer {self.supabase_key}",
            "Content-Type": "application/json",
        }

    async def close(self) -> None:
        """Close HTTP client."""
        if self.client:
            await self.client.aclose()
