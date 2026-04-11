"""
Base Agent class for BroyhillGOP E59 Agent Mesh system.
All ecosystem agents (E00-E58) inherit from this class.

Runs on Hetzner AX162-R server (96 cores, 252GB RAM) at 37.27.169.232
Monitors 58 ecosystems of the political CRM platform.
"""

import asyncio
import json
import logging
import os
import signal
from datetime import datetime, timedelta
from typing import Any, Callable, Dict, List, Optional
from abc import ABC, abstractmethod

import httpx

# Configure structured JSON logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)


class EcosystemAgent(ABC):
    """
    Base class for all ecosystem agents in the E59 Agent Mesh.
    Provides async architecture, Supabase connectivity, monitoring loops,
    heartbeat management, event emission, rule evaluation, and cost tracking.
    """

    def __init__(
        self,
        ecosystem_id: str,
        supabase_url: str,
        supabase_key: str,
        health_check_interval: int = 60,
        audit_interval: int = 300,
        performance_check_interval: int = 120,
        domain_rules_interval: int = 180,
        heartbeat_interval: int = 30,
        max_retries: int = 3,
        retry_delay: float = 1.0,
    ):
        """
        Initialize ecosystem agent.

        Args:
            ecosystem_id: Ecosystem identifier (e.g., 'E00', 'E59')
            supabase_url: Supabase API URL
            supabase_key: Supabase API key
            health_check_interval: Seconds between health checks
            audit_interval: Seconds between data quality audits
            performance_check_interval: Seconds between performance checks
            domain_rules_interval: Seconds between domain rule checks
            heartbeat_interval: Seconds between heartbeat writes
            max_retries: Maximum HTTP retries
            retry_delay: Initial retry delay in seconds
        """
        self.ecosystem_id = ecosystem_id
        self.supabase_url = supabase_url
        self.supabase_key = supabase_key
        self.logger = logging.getLogger(f"Agent-{ecosystem_id}")

        self.health_check_interval = health_check_interval
        self.audit_interval = audit_interval
        self.performance_check_interval = performance_check_interval
        self.domain_rules_interval = domain_rules_interval
        self.heartbeat_interval = heartbeat_interval
        self.max_retries = max_retries
        self.retry_delay = retry_delay

        self.running = False
        self.tasks: List[asyncio.Task] = []
        self.rule_engine = None
        self.rules_last_loaded: Optional[datetime] = None
        self.rules_cache: Dict[str, Any] = {}

        # Cost tracking
        self.api_call_count = 0
        self.total_api_cost = 0.0
        self.start_time = datetime.utcnow()

        # HTTP client
        self.client: Optional[httpx.AsyncClient] = None

        # Signal handlers
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)

    def _signal_handler(self, signum: int, frame: Any) -> None:
        """Handle shutdown signals."""
        self.logger.info(f"Received signal {signum}, initiating graceful shutdown")
        asyncio.create_task(self.shutdown())

    async def initialize(self) -> None:
        """Initialize HTTP client and load configuration."""
        self.client = httpx.AsyncClient(
            timeout=30.0,
            limits=httpx.Limits(max_connections=10, max_keepalive_connections=5)
        )
        await self._load_agent_registry()
        self.logger.info(f"Agent {self.ecosystem_id} initialized successfully")

    async def shutdown(self) -> None:
        """Graceful shutdown of the agent."""
        self.logger.info(f"Shutting down agent {self.ecosystem_id}")
        self.running = False

        # Cancel all tasks
        for task in self.tasks:
            if not task.done():
                task.cancel()
                try:
                    await task
                except asyncio.CancelledError:
                    pass

        # Close HTTP client
        if self.client:
            await self.client.aclose()

        # Write final heartbeat
        await self._write_heartbeat(status="stopped")
        self.logger.info(f"Agent {self.ecosystem_id} shutdown complete")

    async def run(self) -> None:
        """Start all monitoring loops."""
        self.running = True
        await self.initialize()

        # Create monitoring tasks
        self.tasks = [
            asyncio.create_task(self._heartbeat_loop()),
            asyncio.create_task(self.health_check()),
            asyncio.create_task(self.audit_data_quality()),
            asyncio.create_task(self.check_performance()),
            asyncio.create_task(self.check_domain_rules()),
            asyncio.create_task(self._brain_directive_loop()),
        ]

        self.logger.info(f"Agent {self.ecosystem_id} started with {len(self.tasks)} monitoring loops")

        try:
            await asyncio.gather(*self.tasks)
        except asyncio.CancelledError:
            self.logger.info(f"Agent {self.ecosystem_id} cancelled")
        finally:
            await self.shutdown()

    # ========================
    # Core Monitoring Loops
    # ========================

    async def health_check(self) -> None:
        """Monitor ecosystem health status."""
        self.logger.info(f"Health check loop started for {self.ecosystem_id}")
        while self.running:
            try:
                result = await self._perform_health_check()

                if result.get("status") != "healthy":
                    await self._emit_event(
                        event_type="health_check_failed",
                        severity="critical" if result.get("status") == "down" else "warning",
                        details=result,
                    )

                await asyncio.sleep(self.health_check_interval)
            except Exception as e:
                self.logger.error(f"Health check error: {e}", exc_info=True)
                await asyncio.sleep(self.health_check_interval)

    async def audit_data_quality(self) -> None:
        """Audit data quality in the ecosystem."""
        self.logger.info(f"Data quality audit loop started for {self.ecosystem_id}")
        while self.running:
            try:
                result = await self._perform_data_quality_audit()

                if result.get("issues_found", False):
                    await self._emit_event(
                        event_type="data_quality_issue",
                        severity=result.get("severity", "warning"),
                        details=result,
                    )

                await asyncio.sleep(self.audit_interval)
            except Exception as e:
                self.logger.error(f"Data quality audit error: {e}", exc_info=True)
                await asyncio.sleep(self.audit_interval)

    async def check_performance(self) -> None:
        """Monitor performance metrics."""
        self.logger.info(f"Performance check loop started for {self.ecosystem_id}")
        while self.running:
            try:
                result = await self._perform_performance_check()

                await self._evaluate_rules(result)

                await asyncio.sleep(self.performance_check_interval)
            except Exception as e:
                self.logger.error(f"Performance check error: {e}", exc_info=True)
                await asyncio.sleep(self.performance_check_interval)

    async def check_domain_rules(self) -> None:
        """Check domain-specific rules."""
        self.logger.info(f"Domain rules check loop started for {self.ecosystem_id}")
        while self.running:
            try:
                await self._check_domain_specific_rules()
                await asyncio.sleep(self.domain_rules_interval)
            except Exception as e:
                self.logger.error(f"Domain rules check error: {e}", exc_info=True)
                await asyncio.sleep(self.domain_rules_interval)

    # ========================
    # Heartbeat Management
    # ========================

    async def _heartbeat_loop(self) -> None:
        """Write heartbeats at regular intervals."""
        while self.running:
            try:
                await self._write_heartbeat(status="running")
                await asyncio.sleep(self.heartbeat_interval)
            except Exception as e:
                self.logger.error(f"Heartbeat write error: {e}", exc_info=True)

    async def _write_heartbeat(self, status: str = "running") -> None:
        """Write heartbeat to agent_heartbeats table."""
        try:
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
                "Content-Type": "application/json",
            }

            heartbeat_data = {
                "ecosystem_id": self.ecosystem_id,
                "status": status,
                "timestamp": datetime.utcnow().isoformat(),
                "uptime_seconds": int((datetime.utcnow() - self.start_time).total_seconds()),
                "api_call_count": self.api_call_count,
                "total_api_cost": float(self.total_api_cost),
            }

            url = f"{self.supabase_url}/rest/v1/agent_heartbeats"
            response = await self._http_request(
                method="POST",
                url=url,
                json=heartbeat_data,
                headers=headers,
            )

            if response.status_code in (200, 201):
                self.logger.debug(f"Heartbeat written for {self.ecosystem_id}")
            else:
                self.logger.warning(
                    f"Heartbeat write failed: {response.status_code} - {response.text}"
                )
        except Exception as e:
            self.logger.error(f"Failed to write heartbeat: {e}", exc_info=True)

    # ========================
    # Event Emission
    # ========================

    async def _emit_event(
        self,
        event_type: str,
        severity: str = "info",
        details: Optional[Dict[str, Any]] = None,
    ) -> None:
        """
        Emit event to agent_events table.

        Args:
            event_type: Type of event
            severity: Severity level (info, warning, critical, emergency)
            details: Event details dictionary
        """
        try:
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
                "Content-Type": "application/json",
            }

            event_data = {
                "ecosystem_id": self.ecosystem_id,
                "event_type": event_type,
                "severity": severity,
                "details": json.dumps(details or {}),
                "timestamp": datetime.utcnow().isoformat(),
                "acknowledged": False,
            }

            url = f"{self.supabase_url}/rest/v1/agent_events"
            response = await self._http_request(
                method="POST",
                url=url,
                json=event_data,
                headers=headers,
            )

            if response.status_code in (200, 201):
                self.logger.info(f"Event emitted: {event_type} ({severity})")
            else:
                self.logger.warning(f"Event emission failed: {response.status_code}")
        except Exception as e:
            self.logger.error(f"Failed to emit event: {e}", exc_info=True)

    # ========================
    # Rule Evaluation Engine
    # ========================

    async def _evaluate_rules(self, metrics: Dict[str, Any]) -> None:
        """
        Evaluate all active rules against metrics.

        Args:
            metrics: Current metrics dictionary
        """
        try:
            await self._refresh_rules_cache()

            for rule_id, rule in self.rules_cache.items():
                if not rule.get("enabled", True):
                    continue

                result = self._evaluate_single_rule(rule, metrics)

                if result.get("triggered", False):
                    await self._emit_event(
                        event_type="rule_triggered",
                        severity=rule.get("severity", "warning"),
                        details={
                            "rule_id": rule_id,
                            "rule_name": rule.get("name"),
                            "metric_value": result.get("value"),
                            "threshold": rule.get("threshold"),
                        },
                    )
        except Exception as e:
            self.logger.error(f"Rule evaluation error: {e}", exc_info=True)

    async def _refresh_rules_cache(self, force: bool = False) -> None:
        """Refresh rules cache if stale (hot-reload support)."""
        now = datetime.utcnow()
        if (
            force or
            self.rules_last_loaded is None or
            (now - self.rules_last_loaded).total_seconds() > 300  # Refresh every 5 min
        ):
            await self._load_rules_from_database()
            self.rules_last_loaded = now

    async def _load_rules_from_database(self) -> None:
        """Load rules from agent_rules table."""
        try:
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
            }

            url = (
                f"{self.supabase_url}/rest/v1/agent_rules"
                f"?ecosystem_id=eq.{self.ecosystem_id}&select=*"
            )
            response = await self._http_request(
                method="GET",
                url=url,
                headers=headers,
            )

            if response.status_code == 200:
                rules = response.json()
                self.rules_cache = {rule["id"]: rule for rule in rules}
                self.logger.info(f"Loaded {len(self.rules_cache)} rules from database")
            else:
                self.logger.warning(f"Failed to load rules: {response.status_code}")
        except Exception as e:
            self.logger.error(f"Error loading rules: {e}", exc_info=True)

    def _evaluate_single_rule(self, rule: Dict[str, Any], metrics: Dict[str, Any]) -> Dict[str, Any]:
        """
        Evaluate a single rule against metrics.

        Args:
            rule: Rule configuration
            metrics: Current metrics

        Returns:
            Result with triggered status
        """
        try:
            metric_key = rule.get("metric_key")
            threshold = rule.get("threshold")
            operator = rule.get("comparison_operator")

            if metric_key not in metrics:
                return {"triggered": False, "reason": "metric_not_found"}

            value = metrics[metric_key]

            if self._is_on_cooldown(rule.get("id"), rule.get("cooldown_seconds", 300)):
                return {"triggered": False, "reason": "on_cooldown"}

            triggered = self._compare_values(value, threshold, operator)

            return {
                "triggered": triggered,
                "value": value,
                "threshold": threshold,
                "operator": operator,
            }
        except Exception as e:
            self.logger.error(f"Error evaluating rule: {e}", exc_info=True)
            return {"triggered": False, "error": str(e)}

    def _compare_values(self, value: Any, threshold: Any, operator: str) -> bool:
        """Compare value against threshold using operator."""
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
        return False

    def _is_on_cooldown(self, rule_id: str, cooldown_seconds: int) -> bool:
        """Check if rule is on cooldown."""
        return False

    # ========================
    # Metric Recording
    # ========================

    async def _record_metric(
        self,
        metric_name: str,
        metric_value: float,
        metric_type: str = "gauge",
        tags: Optional[Dict[str, str]] = None,
    ) -> None:
        """
        Record metric to agent_metrics table.

        Args:
            metric_name: Name of the metric
            metric_value: Metric value
            metric_type: Type (gauge, counter, histogram)
            tags: Optional tags dictionary
        """
        try:
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
                "Content-Type": "application/json",
            }

            metric_data = {
                "ecosystem_id": self.ecosystem_id,
                "metric_name": metric_name,
                "metric_value": metric_value,
                "metric_type": metric_type,
                "tags": json.dumps(tags or {}),
                "timestamp": datetime.utcnow().isoformat(),
            }

            url = f"{self.supabase_url}/rest/v1/agent_metrics"
            await self._http_request(
                method="POST",
                url=url,
                json=metric_data,
                headers=headers,
            )
        except Exception as e:
            self.logger.error(f"Failed to record metric: {e}", exc_info=True)

    # ========================
    # Cost Tracking
    # ========================

    async def _track_api_call(self, cost: float = 0.01) -> None:
        """Track API call and associated cost."""
        self.api_call_count += 1
        self.total_api_cost += cost

    # ========================
    # Brain Integration
    # ========================

    async def _brain_directive_loop(self) -> None:
        """Check for brain directives and execute approved ones."""
        while self.running:
            try:
                await self._check_brain_directives()
                await asyncio.sleep(60)  # Check every minute
            except Exception as e:
                self.logger.error(f"Brain directive loop error: {e}", exc_info=True)

    async def _check_brain_directives(self) -> None:
        """Check and execute brain directives."""
        try:
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
            }

            url = (
                f"{self.supabase_url}/rest/v1/agent_brain_directives"
                f"?ecosystem_id=eq.{self.ecosystem_id}&status=eq.approved&select=*"
            )
            response = await self._http_request(
                method="GET",
                url=url,
                headers=headers,
            )

            if response.status_code == 200:
                directives = response.json()
                for directive in directives:
                    await self._execute_brain_directive(directive)
        except Exception as e:
            self.logger.error(f"Error checking brain directives: {e}", exc_info=True)

    async def _execute_brain_directive(self, directive: Dict[str, Any]) -> None:
        """Execute an approved brain directive."""
        try:
            directive_type = directive.get("directive_type")
            payload = directive.get("payload", {})

            self.logger.info(f"Executing brain directive: {directive_type}")

            if directive_type == "adjust_threshold":
                await self._adjust_rule_threshold(payload)
            elif directive_type == "toggle_control":
                await self._toggle_control(payload)
            elif directive_type == "enable_rule":
                await self._enable_rule(payload)
            elif directive_type == "disable_rule":
                await self._disable_rule(payload)

            await self._update_directive_status(directive["id"], "executed")
        except Exception as e:
            self.logger.error(f"Failed to execute brain directive: {e}", exc_info=True)
            await self._update_directive_status(directive["id"], "failed")

    async def _adjust_rule_threshold(self, payload: Dict[str, Any]) -> None:
        """Adjust a rule's threshold."""
        rule_id = payload.get("rule_id")
        new_threshold = payload.get("new_threshold")
        self.logger.info(f"Adjusted threshold for rule {rule_id} to {new_threshold}")

    async def _toggle_control(self, payload: Dict[str, Any]) -> None:
        """Toggle a control switch."""
        control_id = payload.get("control_id")
        enabled = payload.get("enabled")
        self.logger.info(f"Toggled control {control_id} to {enabled}")

    async def _enable_rule(self, payload: Dict[str, Any]) -> None:
        """Enable a rule."""
        rule_id = payload.get("rule_id")
        self.logger.info(f"Enabled rule {rule_id}")

    async def _disable_rule(self, payload: Dict[str, Any]) -> None:
        """Disable a rule."""
        rule_id = payload.get("rule_id")
        self.logger.info(f"Disabled rule {rule_id}")

    async def _update_directive_status(self, directive_id: str, status: str) -> None:
        """Update directive status in database."""
        try:
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
                "Content-Type": "application/json",
            }

            url = f"{self.supabase_url}/rest/v1/agent_brain_directives?id=eq.{directive_id}"
            await self._http_request(
                method="PATCH",
                url=url,
                json={"status": status},
                headers=headers,
            )
        except Exception as e:
            self.logger.error(f"Failed to update directive status: {e}", exc_info=True)

    # ========================
    # HTTP Request Handling
    # ========================

    async def _http_request(
        self,
        method: str,
        url: str,
        json: Optional[Dict[str, Any]] = None,
        headers: Optional[Dict[str, str]] = None,
        params: Optional[Dict[str, Any]] = None,
    ) -> httpx.Response:
        """
        Make HTTP request with retry logic.

        Args:
            method: HTTP method
            url: Request URL
            json: JSON body
            headers: Request headers
            params: Query parameters

        Returns:
            HTTP response
        """
        if not self.client:
            raise RuntimeError("HTTP client not initialized")

        for attempt in range(self.max_retries):
            try:
                response = await self.client.request(
                    method=method,
                    url=url,
                    json=json,
                    headers=headers,
                    params=params,
                )
                await self._track_api_call()
                return response
            except (httpx.TimeoutException, httpx.ConnectError) as e:
                if attempt < self.max_retries - 1:
                    delay = self.retry_delay * (2 ** attempt)
                    self.logger.warning(f"Request failed, retrying in {delay}s: {e}")
                    await asyncio.sleep(delay)
                else:
                    raise

    async def _load_agent_registry(self) -> None:
        """Load agent configuration from agent_registry table."""
        try:
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
            }

            url = (
                f"{self.supabase_url}/rest/v1/agent_registry"
                f"?ecosystem_id=eq.{self.ecosystem_id}&select=*"
            )
            response = await self._http_request(
                method="GET",
                url=url,
                headers=headers,
            )

            if response.status_code == 200:
                configs = response.json()
                if configs:
                    config = configs[0]
                    self.health_check_interval = config.get(
                        "health_check_interval", self.health_check_interval
                    )
                    self.audit_interval = config.get("audit_interval", self.audit_interval)
                    self.logger.info(f"Loaded registry config for {self.ecosystem_id}")
        except Exception as e:
            self.logger.error(f"Error loading registry: {e}", exc_info=True)

    # ========================
    # Abstract Methods (override in subclasses)
    # ========================

    @abstractmethod
    async def _perform_health_check(self) -> Dict[str, Any]:
        """Perform ecosystem-specific health check."""
        pass

    @abstractmethod
    async def _perform_data_quality_audit(self) -> Dict[str, Any]:
        """Perform ecosystem-specific data quality audit."""
        pass

    @abstractmethod
    async def _perform_performance_check(self) -> Dict[str, Any]:
        """Perform ecosystem-specific performance check."""
        pass

    @abstractmethod
    async def _check_domain_specific_rules(self) -> None:
        """Check ecosystem-specific domain rules."""
        pass
