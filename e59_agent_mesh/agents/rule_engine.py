"""
Rule Engine for BroyhillGOP E59 Agent Mesh system.
Evaluates rules loaded from Supabase agent_rules table.
"""

import asyncio
import json
import logging
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

import httpx

logger = logging.getLogger(__name__)


class RuleEngine:
    """
    Rule evaluation engine that loads, manages, and evaluates rules.
    Supports dynamic rule modification and hot-reloading.
    """

    def __init__(
        self,
        ecosystem_id: str,
        supabase_url: str,
        supabase_key: str,
        http_client: httpx.AsyncClient,
    ):
        """
        Initialize rule engine.

        Args:
            ecosystem_id: Ecosystem identifier
            supabase_url: Supabase URL
            supabase_key: Supabase API key
            http_client: Async HTTP client for API calls
        """
        self.ecosystem_id = ecosystem_id
        self.supabase_url = supabase_url
        self.supabase_key = supabase_key
        self.client = http_client

        self.rules: Dict[str, Dict[str, Any]] = {}
        self.rule_last_triggered: Dict[str, datetime] = {}
        self.last_reload: Optional[datetime] = None
        self.reload_interval = 300  # 5 minutes

    async def load_rules(self, force: bool = False) -> int:
        """
        Load all active rules from database.

        Args:
            force: Force reload even if not stale

        Returns:
            Number of rules loaded
        """
        now = datetime.utcnow()

        if (
            not force and
            self.last_reload and
            (now - self.last_reload).total_seconds() < self.reload_interval
        ):
            return len(self.rules)

        try:
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
            }

            url = (
                f"{self.supabase_url}/rest/v1/agent_rules"
                f"?ecosystem_id=eq.{self.ecosystem_id}&enabled=eq.true&select=*"
            )
            response = await self.client.get(url, headers=headers)

            if response.status_code == 200:
                rules = response.json()
                self.rules = {rule["id"]: rule for rule in rules}
                self.last_reload = now
                logger.info(f"Loaded {len(self.rules)} rules for {self.ecosystem_id}")
                return len(self.rules)
            else:
                logger.warning(f"Failed to load rules: {response.status_code}")
                return 0
        except Exception as e:
            logger.error(f"Error loading rules: {e}", exc_info=True)
            return 0

    async def evaluate_all(self, metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Evaluate all rules against metrics.

        Args:
            metrics: Dictionary of metric values

        Returns:
            List of triggered rules
        """
        triggered_rules = []

        await self.load_rules()

        for rule_id, rule in self.rules.items():
            result = await self.evaluate(rule_id, rule, metrics)
            if result.get("triggered"):
                triggered_rules.append(result)

        return triggered_rules

    async def evaluate(
        self,
        rule_id: str,
        rule: Dict[str, Any],
        metrics: Dict[str, Any],
    ) -> Dict[str, Any]:
        """
        Evaluate a single rule.

        Args:
            rule_id: Rule ID
            rule: Rule configuration
            metrics: Current metrics

        Returns:
            Evaluation result
        """
        result = {
            "rule_id": rule_id,
            "triggered": False,
            "reason": None,
        }

        # Check cooldown
        cooldown_seconds = rule.get("cooldown_seconds", 300)
        if self._is_on_cooldown(rule_id, cooldown_seconds):
            result["reason"] = "cooldown_active"
            return result

        # Get metric value
        metric_key = rule.get("metric_key")
        if metric_key not in metrics:
            result["reason"] = "metric_not_found"
            return result

        value = metrics[metric_key]
        threshold = rule.get("threshold")
        operator = rule.get("comparison_operator")

        # Evaluate
        try:
            triggered = self._compare_values(value, threshold, operator)

            if triggered:
                result["triggered"] = True
                result["value"] = value
                result["threshold"] = threshold
                result["operator"] = operator
                result["severity"] = rule.get("severity", "warning")
                result["name"] = rule.get("name", metric_key)
                self.rule_last_triggered[rule_id] = datetime.utcnow()
            else:
                result["reason"] = "threshold_not_met"

            return result
        except Exception as e:
            logger.error(f"Error evaluating rule {rule_id}: {e}", exc_info=True)
            result["reason"] = f"evaluation_error: {str(e)}"
            return result

    def _compare_values(self, value: Any, threshold: Any, operator: str) -> bool:
        """Compare values with various operators."""
        if operator == "gt":
            return value > threshold
        elif operator == "lt":
            return value < threshold
        elif operator == "gte":
            return value >= threshold
        elif operator == "lte":
            return value <= threshold
        elif operator == "eq":
            return value == threshold
        elif operator == "neq":
            return value != threshold
        elif operator == "contains":
            return str(threshold) in str(value)
        elif operator == "between":
            if isinstance(threshold, (list, tuple)) and len(threshold) == 2:
                return threshold[0] <= value <= threshold[1]
            return False
        elif operator == "regex":
            import re
            return bool(re.search(str(threshold), str(value)))
        else:
            logger.warning(f"Unknown operator: {operator}")
            return False

    def _is_on_cooldown(self, rule_id: str, cooldown_seconds: int) -> bool:
        """Check if rule is on cooldown."""
        if rule_id not in self.rule_last_triggered:
            return False

        elapsed = (datetime.utcnow() - self.rule_last_triggered[rule_id]).total_seconds()
        return elapsed < cooldown_seconds

    async def add_rule(self, rule_config: Dict[str, Any]) -> Optional[str]:
        """
        Add a new rule.

        Args:
            rule_config: Rule configuration

        Returns:
            Rule ID or None if failed
        """
        try:
            # Validate rule
            self._validate_rule(rule_config)

            rule_config["ecosystem_id"] = self.ecosystem_id
            rule_config["created_at"] = datetime.utcnow().isoformat()
            rule_config["enabled"] = True

            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
                "Content-Type": "application/json",
            }

            url = f"{self.supabase_url}/rest/v1/agent_rules"
            response = await self.client.post(url, json=rule_config, headers=headers)

            if response.status_code in (200, 201):
                result = response.json()
                rule_id = result[0]["id"] if isinstance(result, list) else result.get("id")
                logger.info(f"Added rule {rule_id}")
                await self.load_rules(force=True)
                return rule_id
            else:
                logger.error(f"Failed to add rule: {response.status_code}")
                return None
        except Exception as e:
            logger.error(f"Error adding rule: {e}", exc_info=True)
            return None

    async def update_rule(self, rule_id: str, updates: Dict[str, Any]) -> bool:
        """
        Update an existing rule.

        Args:
            rule_id: Rule ID
            updates: Fields to update

        Returns:
            Success status
        """
        try:
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
                "Content-Type": "application/json",
            }

            updates["updated_at"] = datetime.utcnow().isoformat()

            url = f"{self.supabase_url}/rest/v1/agent_rules?id=eq.{rule_id}"
            response = await self.client.patch(url, json=updates, headers=headers)

            if response.status_code in (200, 204):
                logger.info(f"Updated rule {rule_id}")
                await self.load_rules(force=True)
                return True
            else:
                logger.error(f"Failed to update rule: {response.status_code}")
                return False
        except Exception as e:
            logger.error(f"Error updating rule: {e}", exc_info=True)
            return False

    async def delete_rule(self, rule_id: str) -> bool:
        """
        Delete a rule.

        Args:
            rule_id: Rule ID

        Returns:
            Success status
        """
        try:
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
            }

            url = f"{self.supabase_url}/rest/v1/agent_rules?id=eq.{rule_id}"
            response = await self.client.delete(url, headers=headers)

            if response.status_code in (200, 204):
                logger.info(f"Deleted rule {rule_id}")
                await self.load_rules(force=True)
                return True
            else:
                logger.error(f"Failed to delete rule: {response.status_code}")
                return False
        except Exception as e:
            logger.error(f"Error deleting rule: {e}", exc_info=True)
            return False

    async def toggle_rule(self, rule_id: str, enabled: bool) -> bool:
        """
        Enable or disable a rule.

        Args:
            rule_id: Rule ID
            enabled: Enable status

        Returns:
            Success status
        """
        return await self.update_rule(rule_id, {"enabled": enabled})

    def _validate_rule(self, rule: Dict[str, Any]) -> None:
        """
        Validate rule configuration.

        Args:
            rule: Rule to validate

        Raises:
            ValueError: If rule is invalid
        """
        required_fields = ["name", "metric_key", "threshold", "comparison_operator"]
        for field in required_fields:
            if field not in rule:
                raise ValueError(f"Missing required field: {field}")

        if rule["comparison_operator"] not in [
            "gt", "lt", "gte", "lte", "eq", "neq", "contains", "between", "regex"
        ]:
            raise ValueError(f"Invalid comparison_operator: {rule['comparison_operator']}")

        if rule.get("severity") not in ["info", "warning", "critical", "emergency", None]:
            raise ValueError(f"Invalid severity: {rule['severity']}")

    async def get_stats(self) -> Dict[str, Any]:
        """
        Get rule engine statistics.

        Returns:
            Statistics dictionary
        """
        total_rules = len(self.rules)
        triggered_count = len(self.rule_last_triggered)

        return {
            "ecosystem_id": self.ecosystem_id,
            "total_rules": total_rules,
            "recently_triggered": triggered_count,
            "last_reload": self.last_reload.isoformat() if self.last_reload else None,
        }
